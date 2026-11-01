# Puesta a punto del multijugador (2 días, antes del hackathon)

Objetivo: **dos personas juegan una partida completa online, de principio a fin, sin errores ni desincronizaciones,
aunque una de ellas se desconecte a mitad de partida.** Todavía no se toca la cámara ni nada nuevo; solo dejar fiable lo que ya existe.

Los identificadores S\*/C\* remiten a las tablas de [HACKATHON.md](HACKATHON.md).

**Principio rector: el servidor es la única fuente de verdad.** El cliente puede animar y validar para dar una respuesta inmediata,
pero el tablero que vale es siempre el que manda el servidor en `status.board`.

---

## Día 0 (≈1 h, la víspera): entorno y ramas

1. **Instalar las herramientas.**
   - Go ≥ 1.22 (`pacman -S go`).
   - Editor **Godot 3.5.3** (binario oficial, debe coincidir con las plantillas 3.5.x).
2. **Unir `newlight` y `master`** en la rama de trabajo (`fix/multiplayer`).
   - Conflictos esperados en `Game.gd`, `Global.gd` y `project.godot`. Quedarse con la validación de `master`
     (`Validation.gd`, `Tile.gd`) y con el drag & drop de `newlight`.
   - `wood.material`: elegir uno a mano (`git checkout --theirs/--ours`) y abrir la escena para comprobar que se ve bien.
     Plantearse reexportarlo más ligero o pasar a Git LFS (ahora ocupa 37 MB).
   - Decidir qué hacer con los cambios sin commitear: el paso a tabuladores de `MainMenu` sobra; el host se cambia en el día 2 (C5).
3. **Servidor:** `go 1.22` en `go.mod`, `go get -u ./... && go mod tidy`, y ejecutar `go test ./...` como punto de partida.
4. **Comprobar** que el proyecto abre en Godot y que el modo sandbox sigue funcionando después del merge.

**Hecho cuando:** compilan el servidor y el cliente desde una rama que combina las dos líneas de trabajo.

---

## Día 1: servidor robusto

### 1.1 Cada sala en una sola goroutine (arregla S1, S2, S3 y S4)

Reestructurar `internal/app` siguiendo el patrón del ejemplo de chat de gorilla/websocket (hub/client):

- `Room` tiene su propio `Game` (ya no hace falta guardarlo aparte en el store) y una sola goroutine `run()`.
  Esa goroutine lee de `register`, `unregister` e `inbox chan envelope{client, Message}` y ejecuta los handlers
  **de forma síncrona**, uno detrás de otro. Así desaparecen los accesos concurrentes sin necesidad de mutex.
- `client` representa **una conexión** (no un usuario): tiene `userID`, `send chan []byte` con buffer de 32 y su propia goroutine de escritura.
  - Esta goroutine escribe con `SetWriteDeadline` y envía un ping periódico (por ejemplo, `pongWait = 60s` y `pingPeriod = 54s`).
  - Si se llena el buffer de `send`, la sala da de baja a ese cliente y cierra la conexión: nunca bloquea `Broadcast`.
  - Al salir, la goroutine de lectura envía `unregister` y la de escritura termina en cuanto se cierra `send`.
- `Store`: un `sync.Mutex` y un método `GetOrCreateRoom(code)` atómico, para que dos conexiones simultáneas no creen salas distintas (S4).
- `defer recover()` en el bucle de la sala: un panic se registra en el log y como mucho afecta a esa sala, no al proceso.
- Limpiar las salas vacías tras unos 30 minutos sin conexiones.

### 1.2 Identidad y asientos (arregla S5 y S7)

- IDs con `crypto/rand`:
  - Usuario: 16 caracteres.
  - Sala: 6 caracteres de un alfabeto sin ambiguos (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`), comprobando colisiones en el store.
- Arreglar `SetUser`: ahora genera un ID para la respuesta y otro distinto para la cookie (`WriteUserCookie` llama de nuevo a `GenerateCode`).
  Debe devolver el mismo ID que guarda en la cookie.
- `PlayerStatus` guarda `UserID` (no se envía en el JSON).
  - `JoinGame`: se rechaza si el asiento ya es de otro usuario. Si es del mismo usuario, cuenta como reconexión y no hace nada.
  - `SetReady`, `LeaveGame` y `SubmitTurn`: se rechazan si el usuario no es el dueño del asiento indicado en `player`.
  - No se puede abandonar la partida (`LeaveGame`) una vez empezada.
- Nueva notificación `Error { code, message }`, solo para quien hizo la petición. Códigos: `SEAT_TAKEN`, `NOT_YOUR_SEAT`,
  `NOT_YOUR_TURN`, `STALE_TURN`, `GAME_NOT_STARTED`, `GAME_FINISHED`, `BAD_MESSAGE`.

### 1.3 Protocolo (arregla S9 y S10)

- Al conectar, enviar inmediatamente `StatusResponse` al cliente que se conecta. `GetStatus` se mantiene.
- Un turno o jugador incorrecto devuelve `Error` en lugar de ignorarse sin avisar.
- Que `StartGame` no pueda dispararse dos veces: solo pasa de `NOT_STARTED` a `TURN_1`.
- Añadir `StartGame`, `InvalidTurn` y `Error` a `MessageTypes`.
- Actualizar `doc/Protocol.md`: tablero `rank→file`, mensaje `Error`, `Status` al conectar, asientos.

### 1.4 Reglas (arregla S6 y S8)

- **Validación de movimientos** en `MoveStones`:
  - `1 ≤ count ≤ size`; `count` no puede superar las piedras de la casilla.
  - Cada valor de `drops` ≥ 1 y `sum(drops) == count`.
  - Comprobar el error de `next()` **antes** de leer la casilla.
  - No modificar el tablero si algo falla (eso ya se hace: primero se valida y luego se aplica).
- **Flota:** contar las piezas de cada jugador. Valores oficiales:
  - 5×5: 21 Cirya y 1 Hallacirya.
  - 6×6: 30 y 2.
  - 7×7: 40 y 2.
  - Las Tampa salen del mismo montón que las Cirya.
  - Colocar una pieza cuando no quedan se rechaza con `InvalidTurn`.
- **Londë:** pasar `utils/londe.py` a Go.
  - Un BFS sobre las casillas cuya pieza de arriba es `C` o `H` del jugador (la `T` no cuenta), con adyacencia ortogonal.
  - Hay Londë si se unen la fila 1 y la última, o la columna a y la última.
  - Se comprueba después de cada movimiento. Si los dos jugadores completan una a la vez, gana quien mueve.
- **Fin por tablero lleno o flota agotada** (`FLAT`): gana quien controla más casillas con `C` arriba (las `T`, las `H` y las casillas vacías no cuentan); si empatan, `DRAW`.
- **Apertura como en Tak:** en los turnos 1 y 2 cada jugador coloca una Cirya plana del rival, sacada de la flota del rival.
- Quitar el atajo `move == "fin"`. Si da tiempo, añadir `Resign`.
- Al terminar: estado `WIN_1`, `WIN_2` o `DRAW`, mensaje `GameFinished` con el `status`, y no se aceptan más turnos.

### 1.5 Tests (los que dan por terminado el día 1)

- `internal/cirya`: tests de Londë (horizontal, vertical, con giros, que una `T` corta el camino, que una `H` sí cuenta),
  de flota agotada, de `drops` inválidos (que no deben provocar panic), y que un movimiento con error no modifica el tablero.
- `internal/app` + `api`: test de integración con `httptest.Server` y dos clientes `websocket.Dialer`:
  1. Ambos se conectan y reciben `Status`. Cada uno se sienta y se pone "ready", y llega `StartGame` **una sola vez**.
  2. Juegan una partida guionizada hasta una Londë y llega `GameFinished` con el ganador correcto.
  3. El jugador 2 intenta mover en el turno del 1 (`NOT_YOUR_TURN`) y en el asiento del 1 (`NOT_YOUR_SEAT`).
  4. Un cliente cierra la conexión a mitad de partida, vuelve a conectar con la misma cookie, recibe un `Status` con el tablero completo y la partida sigue.
  5. Un cliente deja de leer: los demás siguen recibiendo mensajes.
  6. 50 conexiones simultáneas al mismo código acaban en una sola sala.
- Todo con `go test -race ./...` en verde.
- ~~Actualizar `cmd/cirya-client` como bot manual~~: se borró en el refactor; los tests de api y el sandbox por turnos lo cubren.

**Hecho cuando:** `go test -race ./...` pasa en verde y el servidor ya no se cae ni se bloquea con mensajes malformados o desconexiones.

---

## Día 2: cliente fiable + pruebas de punta a punta

### 2.1 Modos y jugador (arregla C1)

- `Global.sandbox` deja de estar fijado en el código: el menú lo pone a `true` solo con un botón "Sandbox" explícito y a `false` al entrar online.
- Quitar `global.player = 1` de `Game.gd`. El jugador sale de `Server.context.player`, que se asigna al sentarse o desde el `Status` al reconectar.
- La cámara inicial y las partículas dependen del jugador real (provisional hasta que exista el raíl del hackathon).

### 2.1b Reglas nuevas en el cliente

**Hecho** salvo la comprobación con `status.fleets`, que va con 2.2. La puesta a punto se centra en 5×5:
6×6 y 7×7 no se pueden probar porque solo existe el tablero de 5×5 (ver "Fuera de alcance").

- **Apertura:** en los turnos 1 y 2 el jugador arrastra una Cirya de la flota **del rival** (hoy `is_valid_drag` solo deja coger las propias),
  y `notation_movement` coloca la pieza del rival al reproducir esas jugadas (`unassigned_piece(opponent, "")`).
  Solo se permite colocar en esos turnos: nada de Tampa, Hallacirya ni movimientos.
- **Flota:** [Fleet.gd](client/Fleet.gd) monta 1 Hallacirya en 6×6 y 7×7, pero son 2. Para 5×5 está bien.
- La flota que queda viene en `status.fleets` y sirve para comprobar que la bandeja del cliente coincide.
- El campo del código de sala tiene que pasar el texto a mayúsculas.

### 2.2 El servidor manda (arregla C2)

- Nuevo `Global.apply_status(status)`:
  1. Devuelve todas las piezas a su flota.
  2. Recorre `status.board[rank][file]` de abajo a arriba y coloca cada pieza con `unassigned_piece(player, type)` y `move_piece`,
     poniendo la pieza de pie (`toggle_block`) cuando es una `T`.
  3. Actualiza `global.turn = status.turn`, el turno activo y la lista de movimientos de la UI.
- Se llama al recibir `StatusResponse` y `StartGame`, y **después de cada `Turn`** como conciliación:
  si el `board_state` local no coincide con `status.board`, se reconstruye (en el log se ve la diferencia).
- El movimiento del rival se sigue animando con `notation_movement` para que se vea mover. La conciliación corrige cualquier diferencia que quede.
- `global.turn` y el jugador activo salen siempre de `params.nextTurn` y `params.nextPlayer`, nunca de contadores locales.

### 2.3 Flujo del turno propio (arregla C3 y C4)

- Antes de enviar:
  - Si no hay movimientos, se desactiva "Confirmar" (C4).
  - Validación local con `Validation.gd` (de `master`): misma dirección, casillas contiguas y que las piedras cuadren.
- Al confirmar: input bloqueado y botones ocultos hasta recibir respuesta, mostrando "Esperando al servidor…".
- `InvalidTurn` o `Error`: `restore_initial_position()`, aviso en pantalla con el texto del error y se vuelve a activar el input.
- `GameFinished`: capa encima del tablero con el ganador y el motivo (Londë o flota), input bloqueado y botón "Volver al menú".
- `UserLeft` del rival: aviso de "rival desconectado" (la partida sigue cuando vuelva).

### 2.3b Rotura del nossë con turnos (clave, el sandbox no lo puede validar)

El sandbox es "mundo libre": `can_move` devuelve `true` siempre y cada pieza cogida puede empezar un movimiento nuevo.
Solo con turnos alternos se ejercita la regla de verdad. Hay que comprobar que, al coger una carga de un nossë que controla el jugador:

- Solo se puede coger del nossë propio (pieza de arriba del jugador) y como mucho tantas piezas como el tamaño del tablero.
  El cliente lo comprueba al coger y al soltar.
- Una vez empezado, el turno es ese movimiento: no se puede coger otro nossë ni sacar piezas de la flota,
  solo las del nossë de origen y las que se han ido soltando por el camino.
- Una sola dirección y un solo sentido, casillas seguidas y al menos una pieza en cada casilla al confirmar.
- **Romper y "desromper":** mientras dura el turno se puede soltar, recoger y volver a soltar al ritmo que se quiera,
  también en la misma casilla o devolviendo piezas atrás. Cada suelta deja el tablero en un movimiento legal, aunque sea a medias:
  `Validation.move_state` compara el tablero con el de antes del turno y deduce de ahí qué se ha movido.
  La notación se calcula al confirmar (`Global.move_notation`), no suelta a suelta.
- Tampa y Hallacirya: no se suelta encima de una Hallacirya, y encima de una Tampa solo la Hallacirya **sola**, que la aplana.
  Si la Hallacirya vuelve atrás, la Tampa se levanta otra vez (`Global.sync_tampar`).
- La notación que genera el cliente (`3a2>12`) coincide con lo que se ha hecho en pantalla y el servidor la acepta;
  el rival la reproduce con `notation_movement` y los dos tableros quedan iguales.
- Al recibir un `Turn` o `StartGame`, o al confirmar o deshacer, el movimiento se da por terminado (`Global.end_move`).

El servidor tiene estos casos en `server/internal/cirya/move_test.go` y el cliente en `client/tests/test_rules.gd`,
que prueba las reglas de `client/core/` sin escena. Los tests del cliente se lanzan desde `client/` con
`godot --no-window --path . -s tests/run.gd` y hay que pasarlos antes de cada commit que toque el arrastre.

El sandbox es una partida local por turnos con las mismas reglas: "Confirmar" pasa el turno al otro jugador en el mismo ordenador.
Así la rotura del nossë se prueba en el sandbox igual que online. E11 compara cliente y servidor.

### 2.4 Conexión (arregla C5 y C6)

- Elegir el host:
  - En web, `JavaScript.eval("location.host")` y el esquema según `location.protocol` (`wss`/`https` si la página va por https).
  - En nativo, una variable exportada o el argumento `--server=host:port`; por defecto, `play.cirya.me`.
  - Así se acaba el cambio continuo entre `localhost` y `play.cirya.me` en `Server.gd`.
- Persistir el ID de usuario en nativo (`user://cirya.cfg`) para que al reiniciar el cliente se recupere el asiento.
  En web, se usa la cookie del mismo origen (el juego se sirve desde `/game` en el propio servidor).
- `ws_closed` o `ws_error` durante la partida: capa "Reconectando…" con reintentos espaciados (1, 2, 4… hasta 10 s), volver a unirse a la sala y `apply_status`.
- Corregir `is_ws_connected()`, que falla si `connected` no existe todavía. Poner `connected = false` al cerrarse la conexión.

### 2.5 Pruebas de punta a punta (por la tarde)

Con el servidor lanzado con `go run -race ./cmd/cirya-server`:

| # | Escenario | Resultado esperado |
|---|---|---|
| E1 | Dos clientes nativos en local, partida completa hasta Londë | `GameFinished` correcto en ambos y tableros idénticos durante toda la partida |
| E2 | Nativo contra navegador (exportación web servida desde `/game`) | Igual que E1 |
| E3 | Movimiento ilegal (por ejemplo, encima de una Tampa con una Cirya) | Aviso, la pieza vuelve a su sitio y el turno sigue siendo del mismo jugador |
| E4 | Cerrar un cliente a mitad de partida, abrirlo y volver a entrar con el código | Recupera su asiento y el tablero completo, y la partida sigue |
| E5 | Cortar la red de un cliente unos 20 s (desactivar la wifi; reiniciar el servidor no vale porque se pierde la memoria) | "Reconectando…" y vuelve sin perder estado |
| E6 | Los dos jugadores pulsan "ready" casi a la vez | `StartGame` llega una sola vez |
| E7 | Un tercer usuario entra con el código | Ve la partida como espectador y no puede sentarse ni mover |
| E8 | Agotar la flota en una partida de 5×5 | Fin por `FLAT` con el resultado correcto |
| E9 | Confirmar sin mover, o mover fuera de turno | El botón está desactivado o el servidor responde `Error`, y no se rompe nada |
| E10 | Desplegar en play.cirya.me por https | Funciona con `wss://` y E1 se repite en remoto |
| E11 | Rotura del nossë con turnos (2.3b): carga de 3–5 en un nossë mixto, repartida en varios pasos; intentar cambiar de sentido, saltar casillas, superar la carga, coger otro nossë a mitad y aplanar Tampa con Hallacirya sola y acompañada | Lo legal se acepta y se ve igual en los dos clientes; lo ilegal lo frena el cliente antes de enviar, y si se escapa, el servidor responde `InvalidTurn` |

**Hecho cuando:** pasan E1 a E9 y E11 en local y E10 en remoto, sin errores en la consola de Godot ni en el log del servidor.

---

## Fuera de alcance (para el hackathon o más adelante)

Cámara en raíl, revancha, chat, persistencia en base de datos (si se reinicia el servidor se pierden las partidas),
emparejamiento, Godot 4.

**Tableros de 6×6 y 7×7.** Hoy solo está hecho el tablero de 5×5 (`tablero-5x5-simple-color.png`), que copia el tablero físico.
Hay bandejas para 6×6 y 7×7 en `client/assets/tray/`, pero falta:
- Modelar en Blender los tableros de 6×6 y 7×7 y exportarlos a Godot (`.glb`), con sus casillas.
- Comprobar que las bandejas de 6×6 y 7×7 tienen sitio para 2 Hallaciryar ([Fleet.gd](client/Fleet.gd) ya monta 30+2 y 40+2).
- Elegir el tamaño al crear la sala. Las reglas del servidor ya conocen las flotas de 5, 6 y 7, pero la partida siempre se crea con 5:
  `DoChangeConfig` está vacío. El cliente tiene que montar el tablero y la bandeja de ese tamaño.

## Decisiones de reglas (respondidas por Pablo)

1. ¿Las cantidades de flota de `Fleet.gd` (21/30/40 Cirya + 1 Hallacirya) son las oficiales de Cirya?

Respuesta: No. Son 21 ciryar + 1 hallacirya, 30 ciryar y 2 hallaciryar y 40 ciryar y 2 hallaciryar

3. Victoria por Londë simultánea (un movimiento completa la del rival y la propia): ¿gana quien mueve?

Respuesta: sí, gana quien mueve.

5. Fin por flota o tablero lleno: ¿se cuentan solo las Cirya planas de arriba? ¿Qué pasa si hay empate?

Respuesta: sí, se cuentan solo los nossi (bloques) que coronan en cirya (no tampar ni hallaciryar ni sati vacíos). Si hay empate, la partida termina en empate.

6. ¿Hay alguna regla para el primer turno (como en Tak, donde se coloca una pieza del rival)?

Respuesta: sí, igual que Tak, se coloca primero una pieza del rival.

7. ¿La Hallacirya cuenta para la Londë? (`londe.py` dice que sí.)

Respuesta: por supuesto que sí.

8. ¿Cómo se despliega hoy play.cirya.me (máquina, proxy, TLS)? Hace falta para E10.

Respuesta: lo montaré en un servidor linux privado que tengo, de momento iremos a base de localhost.
