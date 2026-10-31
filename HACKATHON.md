# Cirya Online — retomando el proyecto (hackathon diciembre 2026)

Diagnóstico del estado del repo (noviembre 2026) y plan para la semana de hackathon.
La puesta a punto previa del multijugador está detallada en [PLAN_MULTIPLAYER.md](PLAN_MULTIPLAYER.md).

## Estado actual

- **Cliente:** Godot **3.5** (`config_version=4`, plantillas 3.5.2 instaladas), GDScript.
- **Servidor:** Go 1.15 + gorilla/mux + gorilla/websocket, almacenamiento en memoria.
- **Ramas:** el último trabajo está repartido entre dos ramas que no se han juntado nunca:
  - `newlight` (Pablo, dic 2020): lightmaps horneados, materiales, drag & drop estable, **modo sandbox**.
    Deja fijados `sandbox = true` ([Global.gd](client/Global.gd)) y `global.player = 1` ([Game.gd](client/Game.gd)),
    así que el juego online queda desactivado.
  - `master` (Juanfran, ene 2021): online activado y **validación de movimientos en el cliente**
    (`client/Validation.gd`, que no existe en `newlight`).
  - Al mergearlas hay conflictos en `Game.gd`, `Global.gd`, `project.godot` y `assets/environment/wood.material`
    (binario: 37 MB en `newlight` frente a 19 MB en `master`).
- **Cambios sin commitear en `newlight`:** en `MainMenu.gd`/`.tscn` solo se pasan espacios a tabuladores, y en `Server.gd` el host cambia de `play.cirya.me` a `localhost`.
- **Herramientas:** en este equipo no hay ni `go` ni editor de Godot.

## Bugs del servidor

| # | Gravedad | Dónde | Problema |
|---|---|---|---|
| S1 | Crítico | `internal/app/handlers.go` | Cada mensaje se procesa en su propia goroutine (`go DoX`). Varias escriben a la vez en `room.channels`, `game.players`, el store y el tablero sin mutex, y Go aborta el proceso con `fatal error: concurrent map writes`. |
| S2 | Crítico | `api/socket.go` `SendMessages` | Si `SendMessages` arranca antes que `DoConnect`, `UserMessage(user)` devuelve `nil` y el `select` sobre un canal `nil` espera para siempre. Si falla una escritura, `finish <- true` va a un canal sin buffer que nadie lee y la goroutine queda bloqueada para siempre (además el `break` no sale del `for`). |
| S3 | Crítico | `internal/app/room.go` | Canales sin buffer: un cliente lento o muerto bloquea `Broadcast` y congela la sala entera. |
| S4 | Alto | `api/socket.go` `getRoom` | Dos conexiones simultáneas al mismo código pueden crear dos salas distintas (comprobar y luego guardar no es atómico). |
| S5 | Alto | `internal/app/app.go` | `GenerateCode()` usa `time.Now().Unix()`: dos usuarios en el mismo segundo comparten ID y canal. El código de sala se recorta a 5 caracteres y también puede repetirse. |
| S6 | Alto | `internal/cirya/board.go` | No se comprueba que `sum(drops) == count` ni el límite de carga. Si suman más, el slice se sale de rango y el panic dentro de la goroutine mata el servidor. Si suman menos, se pierden piedras. |
| S7 | Alto | `handlers.go` | No hay autorización: el servidor se fía del `player` que manda el cliente, así que cualquiera puede mover, ponerse "ready" o echar a otro. |
| S8 | Alto | `game.go` | No detecta victorias. Solo existe el atajo `move == "fin"`. La Londë está prototipada en Python (`server/utils/londe.py`). No hay victoria por flota agotada ni recuento de piezas. |
| S9 | Medio | `handlers.go` | Al conectar no se envía `StatusResponse`. Un turno fuera de orden se ignora sin avisar. |
| S10 | Bajo | `doc/Protocol.md` | El documento describe el tablero como `file→rank`, pero el código lo guarda como `rank→file`. |

## Bugs del cliente

| # | Gravedad | Dónde | Problema |
|---|---|---|---|
| C1 | Crítico | `Global.gd`, `Game.gd` | `sandbox = true` y `player = 1` fijos en el código (rama `newlight`). |
| C2 | Crítico | `Global.gd` | El tablero del servidor (`status.board`) nunca se usa: no hay reconexión posible y cualquier desincronización es permanente. |
| C3 | Alto | `Global.gd` / `UI.gd` | No se gestionan `InvalidTurn` ni `GameFinished`. |
| C4 | Alto | `Global.gd` `notation()` | Confirmar sin movimientos rompe el cliente (`turn[0]`, hay un FIXME). |
| C5 | Alto | `Server.gd` | `ws://` y `http://` fijos: si play.cirya.me va por https, el navegador bloquea la conexión (mixed content). En web, la cabecera `Cookie` del WebSocket se ignora. |
| C6 | Medio | `Server.gd` | Si se cierra la conexión, no hay reconexión ni aviso al usuario. |

## Cámara en raíl invisible (objetivo del hackathon)

Ahora hay dos cámaras fijas, `CameraPlayer1`/`CameraPlayer2`, en (±43, 56, ±58) con un FOV de 22°,
y [Game.gd](client/Game.gd) borra la del otro jugador. [camera.gd](client/camera.gd) es una cámara libre que no se usa en ninguna escena.

Diseño propuesto:

- **Escena `CameraRig.tscn`:** un `Path` con una `Curve3D` cerrada alrededor de la mesa, un `PathFollow`
  (con `rotation_mode = NONE`, `loop = true`) y la `Camera` como hija, que cada frame hace `look_at(centro_tablero)`.
  Con una curva hecha en el editor se pueden esquivar la vela, la jarra y las paredes de cada ambiente (taberna o palacio).
- **Dos curvas:** una baja (vista lateral) y otra alta (casi cenital). Al arrastrar en vertical se interpola entre ambas,
  así que la cámara se mueve sobre una "superficie raíl" y nunca atraviesa nada.
- **Controles:**
  - Botón derecho + arrastrar mueve la cámara por el raíl (el izquierdo ya es el drag de piezas).
  - Rueda: zoom acotado, acercando la cámara hacia el objetivo y/o reduciendo el FOV.
  - Teclas `1` / `2` / `3`: salto suave (tween) a "mi lado", "lado rival" y "cenital".
  - Amortiguación con `lerp`. En web/móvil, gestos con dos dedos.
- **Cambios en el código actual:**
  - Quitar el borrado de cámaras y partículas en `Game.gd` y usar el jugador solo para elegir el punto de inicio del raíl.
  - Mantener la distancia de cámara por debajo de `ray_length = 200`.
  - Decidir si se permite girar la cámara mientras se arrastra una pieza (`global.dragging_nosse`).
  - Los raycasts ya usan `get_viewport().get_camera()`, así que no hace falta cambiarlos.

Recomendación: **quedarse en Godot 3.5.x**. Pasar a Godot 4 (GDScript 2, lightmaps, nueva API de WebSocket) se comería la semana.

## Semana de hackathon

Suponiendo que el multijugador ya está estable (ver [PLAN_MULTIPLAYER.md](PLAN_MULTIPLAYER.md)):

| Día | Trabajo |
|---|---|
| 1 | `CameraRig`: un raíl, `look_at`, botón derecho + arrastrar, amortiguación. Integrarlo en `Game.tscn` para ambos jugadores. |
| 2 | Raíl doble (bajo/alto), zoom acotado, presets 1/2/3 con tween. Curvas para taberna y palacio. |
| 3 | Interacción cámara ↔ drag de piezas, controles táctiles y web, ajustes en `Settings`. |
| 4 | Lo que quede pendiente del plan multijugador y pulido de UI (fin de partida, revancha). |
| 5 | Exportación web, despliegue en play.cirya.me, partidas de prueba con más gente. |
| 6 | Arreglar lo que salga en las pruebas y mejorar el rendimiento en web (lightmaps, partículas). |
| 7 | Vídeo de demo y presentación. |
