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

**Hecho.**
- `core/Status.gd` reconstruye el tablero del estado con las piezas del cliente. Deja en su sitio las que ya coinciden y dice qué piezas hay que levantar o tumbar.
- `Game` concilia con cada `StartGame`, `Turn`, `GameFinished` y `StatusResponse`: si el tablero no coincide, lo reconstruye y coloca las piezas, y avisa en la consola.
- `Match` retoma turno, jugador y fase de un `StatusResponse`, y la UI rehace la lista de jugadas.
- Las diferencias con `status.fleets` salen como aviso.
- Falta que el menú abra la partida al reconectarse, que va con 2.4.

- Nuevo `Match.apply_status(status)`, con la parte visual en `Game.gd`:
  1. Devuelve todas las piezas a su flota.
  2. Recorre `status.board[rank][file]` de abajo a arriba y coloca cada pieza con `unassigned_piece(player, type)` y `move_piece`,
     poniendo la pieza de pie (`toggle_block`) cuando es una `T`.
  3. Actualiza `global.turn = status.turn`, el turno activo y la lista de movimientos de la UI.
- Se llama al recibir `StatusResponse` y `StartGame`, y **después de cada `Turn`** como conciliación:
  si el `board_state` local no coincide con `status.board`, se reconstruye (en el log se ve la diferencia).
- El movimiento del rival se sigue animando con `notation_movement` para que se vea mover. La conciliación corrige cualquier diferencia que quede.
- `global.turn` y el jugador activo salen siempre de `params.nextTurn` y `params.nextPlayer`, nunca de contadores locales.

### 2.3 Flujo del turno propio (arregla C3 y C4)

**Hecho.**
- "Confirmar" solo se activa con un movimiento completo.
- Al confirmar, el tablero se bloquea y la línea de ayuda dice "Esperando al servidor…".
- Un `InvalidTurn` o `Error` devuelve las piezas y muestra el motivo unos segundos.
- `GameFinished` abre un diálogo con el resultado y "Volver al menú", que sale de la sala.
- La línea de ayuda da la pista de la apertura y dice de quién es el turno.
- El aviso de entradas y salidas es genérico ("Alguien ha salido de la sala"): el estado no dice qué usuario ocupa cada asiento, así que el cliente no sabe si quien sale es el rival.

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
  `Rules.move_state` (en `client/core/`) compara el tablero con el de antes del turno y deduce de ahí qué se ha movido.
  La notación se calcula al confirmar (`Match.move_notation`), no suelta a suelta.
- Tampa y Hallacirya: no se suelta encima de una Hallacirya, y encima de una Tampa solo la Hallacirya **sola**, que la aplana.
  Si la Hallacirya vuelve atrás, la Tampa se levanta otra vez (`Move.sync_tampar`).
- La notación que genera el cliente (`3a2>12`) coincide con lo que se ha hecho en pantalla y el servidor la acepta;
  el rival la reproduce con `notation_movement` y los dos tableros quedan iguales.
- Al recibir un `Turn` o `StartGame`, o al confirmar o deshacer, el movimiento se da por terminado (`Match` lo pone a `null`).

El servidor tiene estos casos en `server/internal/cirya/move_test.go` y el cliente en `client/tests/test_rules.gd`,
que prueba las reglas de `client/core/` sin escena. `client/tests/run.sh` lanza esos tests y una prueba de humo
que carga la escena del juego, y hay que pasarlo antes de cada commit que toque el arrastre (`GODOT=ruta/al/binario`).

El sandbox es una partida local por turnos con las mismas reglas: "Confirmar" pasa el turno al otro jugador en el mismo ordenador.
Así la rotura del nossë se prueba en el sandbox igual que online. E11 compara cliente y servidor.

### 2.4 Conexión (arregla C5 y C6)

**Hecho.**
- **Elegir el servidor:** `--server=host:puerto`. Si no se indica, el host de la página en web, `127.0.0.1:3333` desde el editor y `play.cirya.me:3333` en una exportación.
- **Usuario guardado:** en `user://cirya-<perfil>.cfg`, y `--profile=nombre` permite tener dos clientes en el mismo ordenador. También se recuerda el asiento de cada sala, para volver a él.
- **Reconexión:** reintentos a los 1, 2, 4, 8 y 10 s, con el aviso "Reconectando…"; al reconectar, el estado del servidor pone el tablero al día.
- **Observadores y reconexión desde el menú:** quien entra en una partida empezada abre el tablero directamente.
- **`server/cmd/cirya-bot`:** juega el otro asiento colocando en la primera casilla libre.
- **`client/tests/e2e.sh`:** arranca servidor y bot, juega una partida entera con la escena real cortando la conexión a mitad, y entra un observador por el menú.

Jugar en un solo ordenador, desde la raíz del repositorio:

```
cd server && go run ./cmd/cirya-server            # el servidor, en 127.0.0.1:3333
cd server && go run ./cmd/cirya-bot -room CODIGO   # el rival, con el código que da "Nueva partida"
godot --path client -- --profile=negras            # otro cliente (sin exportar), además del F5 del editor
```

- Elegir el host:
  - En web, `JavaScript.eval("location.host")` y el esquema según `location.protocol` (`wss`/`https` si la página va por https).
  - En nativo, una variable exportada o el argumento `--server=host:port`; por defecto, `play.cirya.me`.
  - Así se acaba el cambio continuo entre `localhost` y `play.cirya.me` en `Server.gd`.
- Persistir el ID de usuario en nativo (`user://cirya.cfg`) para que al reiniciar el cliente se recupere el asiento.
  En web, se usa la cookie del mismo origen (el juego se sirve desde `/game` en el propio servidor).
- `ws_closed` o `ws_error` durante la partida: capa "Reconectando…" con reintentos espaciados (1, 2, 4… hasta 10 s), volver a unirse a la sala y `apply_status`.
- Corregir `is_ws_connected()`, que falla si `connected` no existe todavía. Poner `connected = false` al cerrarse la conexión.

### 2.5 Pruebas de punta a punta (por la tarde)

Con el servidor lanzado con `go run -race ./cmd/cirya-server`. Los casos automáticos se lanzan con `GODOT=… client/tests/e2e.sh`, que arranca el servidor y el bot:

| # | Escenario | Resultado esperado | Cobertura |
|---|---|---|---|
| E1 | Dos clientes nativos en local, partida completa hasta Londë | `GameFinished` correcto en ambos y tableros idénticos durante toda la partida | Auto: `e2e.sh` juega una partida guionizada hasta Londë (`e2e_nosse.gd`) y otra completa hasta `FLAT` (`e2e_player.gd`), y compara el tablero con el del servidor en cada turno. Dos clientes con interfaz: a mano |
| E2 | Nativo contra navegador (exportación web servida desde `/game`) | Igual que E1 | A mano: falta la exportación web |
| E3 | Movimiento ilegal (por ejemplo, encima de una Tampa con una Cirya) | Aviso, la pieza vuelve a su sitio y el turno sigue siendo del mismo jugador | Auto: `test_rules.gd`, `smoke_game.gd` (la pieza vuelve) y `e2e_nosse.gd` |
| E4 | Cerrar un cliente a mitad de partida, abrirlo y volver a entrar con el código | Recupera su asiento y el tablero completo, y la partida sigue | Auto: `TestReconnectRestoresBoard`, `TestSeatOwnerCanRejoin`, `smoke_game.gd` (reabrir) y `e2e_player.gd` (corte a mitad) |
| E5 | Cortar la red de un cliente unos 20 s (desactivar la wifi; reiniciar el servidor no vale porque se pierde la memoria) | "Reconectando…" y vuelve sin perder estado | A mano: está probado el corte del socket, pero no el de la red real |
| E6 | Los dos jugadores pulsan "ready" casi a la vez | `StartGame` llega una sola vez | Auto: `TestSimultaneousReadyStartsGameOnce` |
| E7 | Un tercer usuario entra con el código | Ve la partida como espectador y no puede sentarse ni mover | Auto: `TestSpectatorCannotPlay`, `test_spectators_never_move` y `e2e_spectator.gd` desde el menú |
| E8 | Agotar la flota en una partida de 5×5 | Fin por `FLAT` con el resultado correcto | Auto: `TestEmptyFleetEndsGame`, `TestFullBoardCountsFlats`, `TestEqualFlatsAreADraw` y `e2e_player.gd` |
| E9 | Confirmar sin mover, o mover fuera de turno | El botón está desactivado o el servidor responde `Error`, y no se rompe nada | Auto: `TestOutOfTurnIsAnswered`, `TestCannotSubmitTurnForOtherPlayer` y el botón desactivado en `smoke_game.gd` |
| E10 | Desplegar en play.cirya.me por https | Funciona con `wss://` y E1 se repite en remoto | Pendiente: se desplegará en un servidor Linux propio |
| E11 | Rotura del nossë con turnos (2.3b): carga de 3–5 en un nossë mixto, repartida en varios pasos; intentar cambiar de sentido, saltar casillas, superar la carga, coger otro nossë a mitad y aplanar Tampa con Hallacirya sola y acompañada | Lo legal se acepta y se ve igual en los dos clientes; lo ilegal lo frena el cliente antes de enviar, y si se escapa, el servidor responde `InvalidTurn` | Auto: `e2e_nosse.gd` rompe un nossë mixto de 4 en `4a1+211`, con pasos de ida y vuelta, y la Hallacirya aplana la Tampa. Lo ilegal lo frena el cliente y el servidor lo rechaza. `test_rules.gd` cubre el límite de carga y casos sueltos. A mano: dos clientes con interfaz |

**Hecho cuando:** pasan E1 a E9 y E11 en local y E10 en remoto, sin errores en la consola de Godot ni en el log del servidor.

---

## Para el hackathon (o antes): reloj, jugada escrita, Henneth Annûn y modo Esquemático

Cuatro piezas independientes; el reloj y la regla Henneth Annûn comparten la configuración de sala, que hoy no existe
(`ChangeConfig` está reservado y `GameConfig` solo tiene ambiente, piezas y tamaño). Orden propuesto: configuración de sala →
reloj → jugada escrita → Henneth Annûn → Esquemático.

### 3.0 Configuración de sala (base del reloj y de Henneth Annûn, ≈ medio día)

**Hecho.** `ChangeConfig` cambia `clock` (0, 180, 300, 600 o 900 s; 300 por defecto) y `hennethAnnun` (solo en 5×5), y todos
reciben `ConfigChanged`. La elige cualquiera mientras nadie se sienta, luego solo el que está sentado, y nadie cuando se
sientan los dos (`CONFIG_LOCKED`). En crear juego, bajo las tarjetas (el panel crece hacia abajo), "Tiempo por jugador ‹ 5 min ›"
y el interruptor "Regla Henneth Annûn" con su tooltip; se apagan cuando ya no se pueden cambiar. Probado en Go y en
`tests/e2e_config.gd`. Todavía no se aplican: el reloj no corre (3.1) y la regla no se comprueba (3.3).
Lo que sigue es el plan tal como se escribió; el "quitar el listo" no hizo falta, porque solo puede cambiarla el que está sentado.

- `GameConfig` gana `clock` (segundos por jugador, 0 = sin reloj, por defecto 300) y `hennethAnnun` (bool, por defecto false).
  Viaja ya en `status.config`, así que el cliente que entra lo ve sin mensajes nuevos.
- `ChangeConfig` se implementa: solo antes de empezar, valida los valores (lista cerrada de tiempos) y difunde
  `ConfigChanged` con la configuración entera.
- **Ojo con el arranque:** hoy la partida empieza en cuanto los dos se sientan, porque el menú manda `SetReady` solo al
  sentarse. La configuración tiene que estar fijada antes de que se siente el segundo. Propuesta: la elige quien crea la sala
  (o el primero que se sienta) y queda bloqueada en cuanto hay dos sentados; el segundo la ve, sin poder tocarla, antes de
  elegir color. Un cambio de configuración con alguien ya listo le quita el listo, para que nadie empiece con reglas que no vio.
- En la pantalla de crear juego hay poco sitio: la tarjeta de color se alarga al escribir el nombre (de 200 a 300 px) y
  bajo ella quedan unos 90 px hasta el borde del panel. Cabe una fila; para el selector de tiempo y el interruptor de
  Henneth Annûn hace falta alargar el panel hacia abajo (hay margen hasta ~1000 px de los 1080) o ponerlos en una sola fila.
- Tests: Go (cambiar antes y después de empezar, valores fuera de lista, quién puede) y e2e de que el segundo ve lo elegido.

### 3.1 Reloj de partida (≈ un día)

**Hecho.** El servidor lleva el tiempo de cada uno (`clocks` en ms y `clockRunning` en cada status), lo arranca al aceptar
la jugada 2 y termina la partida por su cuenta con un temporizador en la goroutine de la sala (`GameFinished` con `TIME`);
una jugada que llega tarde pierde sin jugarse. El cliente cuenta hacia atrás junto a cada pastilla (ámbar el que corre,
rojo por debajo de 30 s, décimas por debajo de 10 s), ENTER confirma la jugada, y el fin por tiempo no repite la última
jugada. Probado en Go con un reloj falso y con la sala en milisegundos, en el smoke y contra el servidor real en
`e2e_player`. No hay e2e que llegue a perder por tiempo: con los tiempos de la lista tardaría 3 minutos.

**Reglas (de Pablo):** tiempo por jugador elegible, 5 minutos por defecto. El reloj empieza cuando las negras confirman
su apertura (la jugada 2, con la pieza del rival); desde la jugada 3 corre el del jugador al que le toca hasta que el servidor
acepta su jugada. Sin incremento. Si un reloj llega a 0, ese jugador pierde, vaya como vaya el tablero.

- **El servidor manda.** La sala guarda el tiempo restante de cada uno y cuándo empezó el turno; al aceptar una jugada resta
  lo gastado y arranca el del otro. Una jugada rechazada no para el reloj. Un `time.Timer` en el `select` de la goroutine
  de la sala dispara la derrota: `GameFinished` con `winCondition: "TIME"` (nueva, junto a LONDI y FLAT).
  Si el reloj ya está a 0 cuando llega la jugada, gana el tiempo.
- Desconectarse no para el reloj (si no, cortar la conexión sería una forma de pensar gratis). Así lo cubre E5 sin cambios.
- Cada `Turn`, `StartGame` y `StatusResponse` lleva `clocks: {"1": ms, "2": ms}` y `running: 1|2|0`. El cliente cuenta
  hacia atrás por su cuenta y se corrige con cada mensaje; quien entra a mitad (o vuelve) recibe el estado en el status.
- **Interfaz:** el reloj muy visible al lado de cada pastilla de jugador, arriba a la izquierda (donde hoy asoma la cinta
  de turno), con cifras grandes `4:59`; en ámbar el que corre, apagado el que espera, en rojo por debajo de 30 s y con
  décimas por debajo de 10 s. Sin reloj (`clock: 0`), en el sandbox y en la demo no se muestra.
- **ENTER confirma la jugada** igual que el botón (atajo del botón Confirmar), salvo cuando el foco está en el campo de jugada
  escrita (3.2), que usa su propio ENTER.
- El aviso de fin de partida dice "por tiempo" (`CONDITIONS` de `UI.gd`).
- Tests: Go con un reloj inyectable (sin `sleep`): empieza tras la jugada 2, se descuenta, rechazo no para, derrota por tiempo,
  jugada que llega con el tiempo agotado. Cliente: el formato y los colores en el smoke; e2e con 3 s por jugador y un bot que
  no juega, que acaba en `TIME`.

### 3.2 Jugada escrita (≈ medio día)

**Hecho.** Un cajón plegado en el borde de abajo, bajo los botones de turno, se abre con su tirador ("Escribir jugada")
y deja ver el campo y la flecha. ENTER o la flecha ponen la jugada en el tablero por el mismo camino que el ratón (coger y
soltar con las mismas comprobaciones), así que lo que no se puede arrastrar tampoco se puede escribir; ENTER con el campo
vacío confirma, así que un turno entero se juega con el teclado. Si no cabe, el campo tiembla, se queda con el texto, la
ayuda dice por qué y vuelve la jugada que había. Escape cierra el cajón sin preguntar por salir. Se aceptan minúsculas y
espacios. Sirve en partida y en el sandbox, no en la demo ni para quien mira. Probado en `tests/smoke_written.gd` y en
`e2e_nosse.gd`, que escribe sus dos últimas jugadas contra el servidor. De momento no hay opción de enviar sin confirmar.

- Un campo centrado abajo, algo por debajo de donde sale la ayuda de la demo, plegado por defecto. Se despliega con un tirador
  en el estilo de la interfaz (la cinta `ribbon-btn.svg` y los rombos de los botones, como "Movimientos"), y deja ver un
  `LineEdit` y a la derecha un botón con una flecha hacia arriba ("al tablero"), con el mismo estilo. ENTER o la flecha envían.
- Lo escrito se lee con `Notation.parse` (se aceptan minúsculas en `t`/`h` y espacios sobrantes) y se pasa a pasos con
  `Rules.replay`, lo mismo que muestra las jugadas del rival. Si cabe, la jugada **se coloca en el tablero** como si se hubiera
  hecho con el ratón y se confirma como siempre (botón o ENTER); si no, el campo tiembla, se queda con el texto y la ayuda dice
  por qué ("e6 no existe", "esa pieza no es tuya", "no puedes romper así el nossë").
  Pendiente de decidir: si conviene una opción para enviar directamente sin el paso de confirmar.
- Sirve en partida online y en el sandbox; en la demo será la puerta de "Insertar movimientos" (Replay).
  Junto con el modo Esquemático da una forma de jugar sin arrastrar piezas, más accesible.
- Tests: smoke escribiendo una colocación, una tampa y una rotura de nossë, y textos malos; e2e reutiliza el guion del nossë
  escrito en vez de arrastrado.

**Coordenadas sobre el tablero: hecho.** Con el cajón de la jugada escrita abierto, el tablero muestra un overlay
"técnico": las letras a…e a lo largo del borde cercano y los números 1…5 a lo largo del derecho, fuera de la cuadrícula,
en la franja del marco, para que ninguna pila las tape por llena que esté la partida. Cada una va en un círculo con el
azul del escudo de Cirya, aro y letra en blanco (WorkSans, con cifras alineadas), sin sombreado para que contraste, y en
el centro del primer tercio de su casilla (desde la izquierda las letras, desde el borde cercano los números), lejos de los
rombos con tengwar del centro de cada lado. Son una sola imagen dibujada en un `Viewport` y tendida justo sobre el tablero,
así que se deforman con la perspectiva. Las negras las ven desde el otro lado (e…a en su borde cercano, 1…5 desde cerca por
su derecha, la columna a), cada nombre junto a su columna o fila. Siguen la cuadrícula dibujada, que es un 2,5 % mayor que
la de las casillas desde la esquina de a1. Se ocultan al cerrar el cajón y cuando no es tu turno. La esquina cercana derecha
queda bajo la franja de la ayuda. Probado en `tests/smoke_written.gd`.

Las casillas (resaltado y piezas) siguen su propia cuadrícula, algo menor que la dibujada, y se dejan así a propósito
(decisión de Pablo): a ojo se ven mejor que ajustadas al dibujo, donde el resaltado quedaría pegado a un borde o lo
rebasaría. No cambiar `TILE_STEP`.

### 3.3 Regla Henneth Annûn (interruptor ≈ 2 h, la regla ≈ medio día)

**Hecho.** El servidor rechaza con un InvalidTurn la hallacirya puesta fuera de las jugadas 32 (negras) y 33 (blancas)
de la partida (`cirya.HennethAnnun`), y el cliente no deja cogerla ni escribirla, y lo explica. Mientras no se puede
jugar se ve translúcida en la bandeja, y para siempre cuando su turno pasa. En su turno la ayuda dice "Henneth Annûn: es
tu turno de poner la Hallacirya" y, si se confirma otra jugada, se pregunta "¿Renuncias para siempre a tu Hallacirya?"
("Volver al tablero" o "Renuncio"). Bajo el código de sala, el sello "◆ Henneth Annûn ◆" con el tooltip de la regla.
Probado en Go (`henneth_test.go`, `TestHennethAnnun`), en `tests/smoke_henneth.gd` (una partida escrita en el sandbox
hasta la jugada 35) y en `tests/e2e_henneth.gd`, contra el servidor real con un bot guionizado hasta la jugada 34.

**La regla (de Pablo).** Con ella activa, cada jugador solo puede poner en juego su hallacirya en una jugada concreta:
Morqua (negras) en su jugada 16 y Ninquë (blancas) en su jugada 17, que es la siguiente. Van en orden inverso a la salida
(empiezan las blancas) para equilibrar la iniciativa. Antes de esa jugada está prohibida; en ella toca jugarla, salvo que
jugarla dé la victoria al rival, y eso lo juzga el propio jugador; después ya no puede jugarse nunca, aunque fuera obvio
que jugarla en su momento le daba la victoria al otro. La gracia está ahí: relaja un poco el modelo cortesano de Aracirya
y crea un momento previsible de tensión a medida que se acerca Henneth Annûn. El 9+7 es una referencia oculta a la Caída
de Númenor; lo que cuenta es el 16. Si en esa jugada no queda ningún sat libre, la partida ya habrá acabado por recuento de
ciryar (FLAT). Sin la regla, la hallacirya se juega cuando se quiera, como hoy.

- Cada jugador cuenta sus propias jugadas, no las de la partida: la 16.ª de Morqua es la 32 de la lista de movimientos
  (que numera las de los dos desde la apertura de las blancas) y la 17.ª de Ninquë es la 33, justo después. Contando las
  de la partida sería demasiado pronto (8 jugadas de las blancas y 7 de las negras).
- Solo en 5×5: viene de los Montaraces de Ithilien, con Faramir a la cabeza, que solo tenían ocasión de jugar en 5×5.
  En 6×6 y 7×7 el interruptor no aparece y la regla no se aplica.
- Como el servidor no puede juzgar si jugarla daría la victoria al rival, la obligación se programa como permiso con aviso:
  la hallacirya solo se puede coger (cliente) y solo se acepta (servidor) en la jugada 32 de la partida para las negras y en
  la 33 para las blancas. En esa jugada la ayuda lo anuncia ("Henneth Annûn: es tu turno de poner la Hallacirya") y, si se confirma otra
  jugada, se pregunta antes "¿Renuncias para siempre a tu Hallacirya?".
- En crear juego, bajo las tarjetas de color, un interruptor "Regla Henneth Annûn" con el estilo de la interfaz
  (`CheckButton` con iconos propios) y el tooltip:
  "La Hallacirya solo puede ponerse en juego en el turno 9+7 (16) de Morqua y en el siguiente (17) de Ninquë, salvo que
  jugarla provoque la derrota instantánea de quien la juega". Va en `GameConfig.hennethAnnun` (3.0).
- En la partida se ve que la regla está activa (un pequeño sello junto al código de sala, con el mismo tooltip), y la
  hallacirya de la bandeja se ve apagada mientras no se pueda jugar.
- La regla va en las reglas del servidor (`internal/cirya/rules.go`, un rechazo claro: "con Henneth Annûn la Hallacirya
  solo se juega en la jugada 16 de Morqua o en la 17 de Ninquë") y en las del cliente (`core/Rules.gd`, que ya decide qué se puede coger).
- Tests en los dos: prohibida hasta la jugada 31 de la partida, aceptada en la 32 para las negras y en la 33 para las
  blancas, rechazada a las dos desde la 34; sin la regla, como hoy; y la configuración no la admite fuera de 5×5. Un e2e
  que llegue a la jugada 32 (con un bot guionizado que no cierre antes la partida).

### 3.4 Modos Historia y Esquemático (≈ un día)

**Hecho.** Bajo las pastillas de los jugadores, dos botones con iconos propios (un libro, `view-story.svg`, y una
cuadrícula, `view-schematic.svg`) con tooltip; el elegido se ve en ámbar. El cambio es en caliente y no toca el tablero.
Va en `Settings.view` y no viaja al servidor. El juego abre siempre en Historia (decisión de Pablo): Esquemático dura
mientras se sigue en la partida y al volver al menú se vuelve a Historia. Esquemático: fuera la mesa de la
taberna, las velas, las jarras, el polvo, sus luces y el lightmap; un entorno sin efectos (ni glow, DOF, SSAO ni niebla), luz
ambiente blanca y una luz direccional desde arriba con sombras suaves, sobre una mesa gris lisa y con las bandejas grises.
El tablero de madera se oculta (su colisión sigue sosteniendo las piezas) y en su lugar va uno claro y liso, con líneas
negras gruesas alineadas con las casillas y las coordenadas impresas fuera de la cuadrícula (letras abajo, números a la
derecha, como las ve cada jugador); por eso las del cajón de la jugada escrita no salen en este modo. Piezas en blanco puro
con contorno negro y en negro puro con contorno blanco (el shader `outline.tres` que ya estaba); la pieza cogida lleva un
contorno naranja grueso y las casillas se iluminan en naranja liso. La hallacirya apagada de Henneth Annûn también se ve
translúcida aquí. Probado en `tests/smoke_view.gd`.

La ayuda de abajo, que en Historia va sobre negro translúcido con letra de contorno oscuro, en Esquemático pasa a blanco
sobre negro casi opaco con un filo ámbar, como el botón de confirmar, y sin contorno: sobre el tablero blanco se empastaba.


- **Historia** es la partida tal como está: la taberna, la luz de las velas, la profundidad de campo, las partículas.
  **Esquemático** es la misma partida en alto contraste, pensada para ser muy accesible. Cada jugador elige el suyo;
  se guarda en su configuración local (`Settings`, en `user://`) y no viaja al servidor.
- El cambio se hace con un interruptor junto a la pastilla del jugador: dos iconos pequeños (un libro para Historia,
  una cuadrícula para Esquemático) en el estilo de la interfaz, con tooltip. Se cambia en caliente, sin recargar la escena.
- Esquemático, de momento sin cambiar la cámara:
  - Tablero liso y claro con líneas de sat negras y gruesas, y las coordenadas a1…e5 en los bordes (una textura nueva para el
    tablero de 5×5).
  - Piezas blancas en blanco puro con contorno negro, negras en negro puro con contorno blanco; la tampa de pie y la
    hallacirya se reconocen por su silueta, no por el color.
  - Mesa en gris oscuro liso, bandejas sencillas; fuera la decoración (jarras, velas), las partículas y los efectos
    (DOF, glow, SSAO, niebla). Luz uniforme y sombras suaves.
  - El resaltado de la pieza cogida y del sat donde caería, con un color fuerte y grueso (no el morado tenue de Historia):
    ya se perdió una vez el resaltado de la casilla en una refactorización, y aquí importa todavía más.
  - Se puede apoyar en lo que ya hace `Settings` por calidad (efectos de `Environment`, MSAA) y en `material_override`
    sobre las mallas de las piezas (`Unit.gd` tiene `$Mesh`).
- Más adelante: cámara cenital ortográfica opcional, y paletas para daltonismo.
- Tests: el smoke cambia de modo y comprueba que siguen el resaltado de la pieza y del sat, que el cambio no toca el tablero
  ni la jugada a medias, y que el modo elegido se recuerda al volver a abrir.

### 3.5 Altura máxima del nossë y variante T4K

**La regla (de Pablo).** En Cirya, al contrario que en Tak, un nossë tiene como mucho tantas piezas como el tablero es de
ancho (5 en 5×5, 6 en 6×6…), y encima de ellas puede ir la hallacirya: en 5×5, 5 ciryar (o 4 y una tampa) y la hallacirya.
No estaba decidido en 2020, pero tras varios Omentië Ciryandilion se ve mucho mejor como regla obligatoria. Un nossë lleno
actúa de hecho como una tampa: salvo la hallacirya no se le puede poner nada encima, y un nossë que se rompe no puede soltar
parte de su carga en él y seguir. Cambia mucho la táctica respecto a Tak.

**Hecho.** La regla va por defecto en el servidor (`Board.fits` en `cirya/move.go`: un sat no puede quedar con más de `Size`
piezas sin contar la hallacirya, que siempre es la de arriba) y en el cliente (`Rules.fits`, que aplican `Match.can_drop`
para el ratón y la jugada escrita, que dice "En d5 ya no cabe más…", y `Rules.apply_turn` para la reproducción de la demo).
El límite de carga sigue siendo el tamaño del tablero (confirmado por Pablo): una pila de 5 y la hallacirya no se mueve
entera, al menos la de abajo se queda en su sat.

La variante T4K quita el límite, casi como en Tak: es `GameConfig.tak` (por defecto `false`), con las mismas reglas de
bloqueo que el resto de la configuración. Se activa como un código Konami: en crear juego, tecleando T4K con el foco fuera
de cualquier campo; aparece "◆ Variante T4K: sin límite del nossë ◆" bajo Henneth Annûn, y tecleándolo otra vez se quita. En
la partida, un sello "◆ T4K ◆" bajo el código de sala, debajo del de Henneth Annûn si también está. Probado en Go
(`TestHeightOfANosse`, `TestHeightWithT4K`, `TestTheVariantT4K`), en `tests/test_apply.gd`, `smoke_written.gd` y
`e2e_config.gd`, que teclea T4K en el menú contra el servidor real.

### 3.5b Máximo de tampar en el tablero

**La regla (de Pablo).** Un jugador no puede tener en el tablero más tampar de pie que el ancho del tablero (5 en 5×5). Una
tampa aplanada por una hallacirya ya no cuenta. Se aplica también con T4K, que solo quita el límite de altura del nossë.

**Hecho.** En el servidor (`Board.Tampar`, en `cirya/move.go`: colocar una tampa más es un InvalidTurn), en el cliente (no
deja levantar la pieza con R, ni soltarla de pie, ni escribirla: "Ya tienes 5 tampar en el tablero: no caben más"), en la
reproducción de la demo (`Rules.apply_turn`) y en el bot (`BotBoard.moves`). Probado en Go (`TestTamparOnTheBoard`), en
`tests/test_botboard.gd`, `test_apply.gd` y `smoke_written.gd`; las partidas aleatorias del bot que el servidor rejuega
se han vuelto a generar con la regla.

### 3.6 Revancha

**Hecho.** Al terminar una partida, por Londë, por recuento o por tiempo, el diálogo de fin de partida ofrece a cada jugador
otra, con los colores cambiados: "Adelante" y "Ahora no", con la cuenta atrás de 30 s. Con que uno diga "Ahora no", diga lo
que diga el otro (o aunque ya hubiera dicho "Adelante"), los dos ven "No habrá una nueva partida"; igual si pasan los 30 s
("…: se acabó el tiempo"). Nadie sale de la sala: la partida queda ahí para copiar los movimientos o volver al menú. Si los
dos dicen "Adelante", el servidor intercambia los asientos y los colores y empieza una partida nueva con la misma
configuración; cada cliente toma el otro asiento (y lo recuerda para volver a la sala) y rehace la escena, ya desde el lado
de su nuevo color. La oferta se repite al final de cada partida.

Servidor: `internal/app/rematch.go` (la acción `Rematch`, la notificación `RematchChanged`, `StartGame` con `"rematch": true`
y `status.rematch`), con el temporizador de la sala para lo primero que venza, el reloj o la oferta. El bot acepta una
revancha con `-rematch`. Probado en `rematch_test.go` y en `tests/e2e_rematch.gd`, contra el servidor real, aceptándola
(nueva partida como negras) y rechazándola (la partida terminada se queda).

### 3.7 Bot local (plan)

Jugar contra un bot en vez de esperar a otro jugador. El bot vive en el cliente: el servidor no cambia y no sabe que el
rival es un bot. La partida es una partida online normal, con su sala, su reloj, sus reglas y su revancha.

**Interfaz (crear juego).**
- Tras elegir su color y poner su nombre, la tarjeta del otro color pasa a ser un interruptor: un clic la marca como
  **Bot local** (una etiqueta bajo la pastilla, en el estilo de la interfaz, por ejemplo "◆ Bot local ◆"), otro clic la deja
  como estaba, esperando a un jugador (que podría ser también un bot externo, pero eso es otra dinámica).
- Con el Bot local marcado aparece encima de las opciones de partida un botón **Comenzar**: hasta ahora la partida empieza
  sola cuando el segundo jugador se sienta y está listo, y aquí no hay segundo jugador que llegue. Al pulsarlo, el bot se
  sienta y la partida empieza. Hasta entonces se pueden cambiar el reloj, Henneth Annûn y T4K, como ahora.
- Si entra otro jugador en la sala y se sienta antes de pulsar Comenzar, el interruptor se quita (el asiento ya no está libre).
- En la partida, el panel del rival dice el nombre del bot (por ejemplo "Bot de Morqua" o un nombre élfico fijo).

**Conexión: un segundo cliente sin cabeza dentro del mismo proceso.**
- Un nodo nuevo, `BotPlayer` (creado por el menú al pulsar Comenzar, que sobrevive al cambio de escena como hijo de `Server`
  o como autoload propio), abre **su propio `WebSocketClient`** a la misma sala, con el **mismo usuario** que el jugador: el
  servidor ya deja que un usuario tenga varias conexiones y que ocupe los dos asientos (`Game.Sit` solo rechaza el asiento de
  otro usuario). Así funciona igual en la web, donde el navegador manda la misma cookie a las dos conexiones y no se podría
  dar al bot un usuario propio sin tocar el servidor.
- Hace `JoinGame` con el otro asiento y `SetReady`; luego escucha `StartGame`/`Turn`/`StatusResponse` y, cuando le toca,
  calcula su jugada y manda `SubmitTurn` con su `player`. No toca `Match`, `Server.context` ni los asientos guardados del
  jugador (`seat_in`): lleva su propio estado, sacado del `status` de cada mensaje (tablero en el formato del servidor).
- Revancha: acepta siempre ("Adelante") y cambia de asiento como el jugador. Si el jugador vuelve al menú o deja la sala,
  el bot cierra su conexión. Si la conexión cae, se reconecta como la del jugador.
- El cliente del jugador no cambia: ve las jugadas del bot como las de cualquier rival.

**Motor del bot: GDScript puro en `core/`, sin escena, probado con tests unitarios.**
- `core/BotBoard.gd`: un tablero ligero en el formato del servidor (pilas de cadenas "C1", "T2", "H1" por sat, y las
  bandejas), con la misma lógica que `internal/cirya`: generar todas las jugadas legales (colocaciones de cirya, tampa y
  hallacirya; roturas de nossë con todas sus sueltas, carga hasta el tamaño del tablero), aplicar una jugada y deshacerla, y
  ver si la partida acaba (Londë de quien mueve primero, tablero lleno o bandeja vacía con recuento de ciryar). Con las reglas
  de Cirya: la apertura pone una cirya del rival; nada sobre la hallacirya; sobre la tampa solo la hallacirya sola, que la
  aplana; **altura máxima del nossë: el tamaño del tablero y la hallacirya encima** (salvo con T4K); Henneth Annûn (la
  hallacirya solo en la jugada 32 de las negras y la 33 de las blancas). Se contrasta con el servidor: las mismas posiciones,
  las mismas jugadas legales.
- `core/Bot.gd`: elige la jugada. Lo que hacen los bots de Tak, en pequeño:
  - **Búsqueda minimax con poda alfa-beta** (como Taktician; los fuertes, como Tiltak, usan MCTS con redes, que queda lejos),
    a 2 capas para empezar (su jugada y la respuesta del rival), con profundidad iterativa mientras quede tiempo, ordenando
    primero las jugadas que ganan, las que bloquean y las colocaciones cerca de su camino.
  - Atajos antes de buscar: si tiene una jugada que hace Londë, la juega; si el rival amenaza Londë en la siguiente, la
    bloquea (con una tampa si puede, o cubriendo/rompiendo el camino).
  - **Evaluación** de una posición, de lo más importante a lo menos: lo que le falta a cada uno para completar un Londë (la
    distancia más corta entre lados opuestos con un BFS 0-1: sus sats coronados por cirya o hallacirya cuestan 0, los vacíos 1,
    los del rival y las tampas no se pueden cruzar), el recuento de ciryar planas arriba (para el final por recuento), las
    pilas que controla y sus piezas atrapadas, el centro, y que los nossi llenos de 5 son muros: un nossë propio lleno al
    lado del camino del rival le corta el paso como una tampa, y uno del rival en su camino obliga a rodearlo.
  - Apertura: la cirya del rival en una esquina, como en Tak.
  - Henneth Annûn: en su turno juega la hallacirya donde más le sirva, salvo que eso pierda la partida.
- Un solo nivel al principio ("aprendiz"); más adelante, niveles por profundidad y tiempo de búsqueda.

**Rendimiento.** GDScript es lento y la exportación web de Godot 3.5 no tiene hilos, así que la búsqueda no puede bloquear el
juego: se reparte entre fotogramas (una corrutina que hace N nodos por fotograma) con un tope de tiempo, por ejemplo 1–2 s,
menos si el reloj aprieta, y se juega lo mejor encontrado. Una espera mínima de medio segundo para que no parezca
instantáneo. En 5×5 con 2 capas y buen orden de jugadas debería bastar; se mide en la web antes de subir la profundidad.

**Pruebas.**
- Unitarias: número de jugadas legales en posiciones conocidas (como el *perft* del ajedrez), las sueltas de un nossë, la
  altura máxima, el aplanado de la tampa, Henneth Annûn, detección de Londë y de recuento; la evaluación prefiere el camino
  más corto; el bot gana en una jugada cuando puede y bloquea un Londë del rival a una jugada.
- Que todas sus jugadas las acepte el servidor: un test que hace jugar al bot contra sí mismo partidas enteras con el Go del
  servidor como árbitro (o contra el `cirya-bot`), sin un solo `InvalidTurn`, también con T4K y con Henneth Annûn.
- Humo: el menú con el interruptor y Comenzar. E2E: una partida contra el bot local de principio a fin contra el servidor
  real, con revancha.

**Orden propuesto y estimación.**
1. `BotBoard` con generación de jugadas y tests contra los casos del servidor (≈ un día).
   ✅ Hecho: `core/BotBoard.gd` lista todas las jugadas legales en notación (colocaciones, aperturas y roturas del nossë
   con todas sus sueltas), las juega y las deshace, y dice cuándo y cómo acaba la partida; con la altura máxima, T4K y
   Henneth Annûn. Probado en `tests/test_botboard.gd` (con 20 partidas aleatorias que vigilan que no se pierde ni se crea
   ninguna pieza y que ningún sat pasa del límite) y contrastado con el servidor: `tests/dump_bot_games.gd` escribe 40
   partidas aleatorias (la mitad con T4K) en `server/internal/cirya/testdata/bot_games.json`, y `TestTheGamesOfTheBot` las
   rejuega con las reglas del servidor, que acepta todas las jugadas y llega al mismo tablero y al mismo resultado.
2. `Bot` con los atajos y la evaluación a 1 capa, y luego alfa-beta a 2 (≈ un día).
   ✅ Hecho: `core/Bot.gd`, negamax con poda alfa-beta y profundidad iterativa hasta 2 capas con tope de tiempo (1,5 s),
   que puede esperar un fotograma cada tantas posiciones para no congelar el juego. Si puede ganar, gana; abre en una
   esquina. La evaluación es simétrica para quien mueve: si a quien mueve le falta un sat para el Londë y le quedan piezas,
   gana; si al otro le falta uno y tiene dos sats para cerrarlo, está perdido; si no, la distancia al Londë de cada uno
   (BFS 0-1: sus sats 0, vacíos 1, pilas del rival que se pueden cubrir 2; tampas, hallacirya y nossi llenos son muros),
   el recuento de ciryar (que pesa más con las bandejas vacías), el control de pilas, los prisioneros y el centro. Con
   Henneth Annûn, una hallacirya que no se pone en su turno cuenta como perdida. Probado en `tests/test_bot.gd`.
   En nativo piensa unos 170 ms de mediana y 500 ms como mucho a 2 capas. A 2 capas gana 7 de 10 a sí mismo a 1 capa;
   las que pierde son por recuento jugando con negras, a ajustar en el paso 5. Para llegar ahí hubo que corregir dos
   cosas: una evaluación que no era simétrica (a 1 capa salía muy agresivo y a 2 muy pasivo) y la elección en la raíz,
   que tomaba por buenas jugadas recortadas por la poda, cuyo valor es solo una cota.
3. `BotPlayer` (la segunda conexión sin cabeza) y el autojuego contra el servidor (≈ medio día).
   ✅ Hecho: `BotPlayer.gd` abre su propio websocket a la sala con el usuario del jugador, se sienta en el asiento que le
   dan, dice que está listo y, cuando el `status` dice que le toca, piensa sobre `BotBoard.from_status` (repartiendo la
   búsqueda entre fotogramas) y manda su jugada tras una espera mínima de 0,6 s; descarta lo pensado si la partida siguió.
   Acepta todas las revanchas y cambia de asiento. Si el servidor le rechazara una jugada, juega otra legal al azar. Se
   reconecta si se cae. `Server.start_bot(asiento, nombre)` lo crea como hijo suyo (sobrevive a los cambios de escena) y
   `leave_room()` lo para. Probado en `tests/e2e_bots.gd`: dos bots juegan entre sí a través del servidor real, con las
   reglas normales y con T4K y Henneth Annûn, dos partidas seguidas (la segunda tras la revancha, con los asientos
   cambiados), sin una sola jugada rechazada.
4. La interfaz del menú: el interruptor, la etiqueta y Comenzar; el nombre del bot en la partida (≈ medio día).
   ✅ Hecho: sentado el jugador y con el otro asiento libre, la tarjeta del otro color enciende y apaga el bot; encendido
   se ve "◆ Bot local ◆" bajo ella y "Comenzar" encima de las opciones de partida, que llama a `Server.start_bot`. El bot
   se sienta como "Bot local" y la partida empieza como siempre. Si se sienta otra persona antes, el interruptor se va.
   Al volver al menú, el bot se para. Probado en `tests/e2e_local_bot.gd`, por el menú real y contra el servidor real.
   Para el paso 5: el bot pone su hallacirya muy pronto (jugada 4 en la prueba); los bots de Tak guardan la suya.
   ✅ Corregido tras la primera partida de Pablo contra él (ganó el bot por Londë, pero sacó la hallacirya en su segunda
   jugada): juega como pide la Cirya cortesana, Aracirya, donde sacar la hallacirya el primero es signo de debilidad. Ser
   el primero en sacarla le cuesta 500 en la evaluación (más que cualquier mejora de posición, mucho menos que perder),
   así que solo la saca el primero para ganar o para no perder; en cuanto el rival saca la suya, queda libre. Con Henneth
   Annûn no se aplica: la regla dice cuándo sale cada una. (`Bot.brought_out_first`, probado en `tests/test_bot.gd`.)
5. Medir en la web, ajustar el tiempo de búsqueda y los pesos de la evaluación jugando contra él (≈ medio día).

**Por decidir.**
- El nombre que muestra el bot y si tiene niveles desde el principio.
- Si el bot acepta siempre la revancha o lo decide el jugador al empezar.
- Si el Bot local también se ofrece en el sandbox (sin servidor), que con este diseño necesitaría otro camino.

## Fuera de alcance (para el hackathon o más adelante)

Cámara en raíl, revancha, chat, persistencia en base de datos (si se reinicia el servidor se pierden las partidas),
emparejamiento, Godot 4.

**Tableros de 6×6 y 7×7.** Hoy solo está hecho el tablero de 5×5 (`tablero-5x5-simple-color.png`), que copia el tablero físico.
Hay bandejas para 6×6 y 7×7 en `client/assets/tray/`, pero falta:
- Modelar en Blender los tableros de 6×6 y 7×7 y exportarlos a Godot (`.glb`), con sus casillas.
- Comprobar que las bandejas de 6×6 y 7×7 tienen sitio para 2 Hallaciryar ([Fleet.gd](client/Fleet.gd) ya monta 30+2 y 40+2).
- Elegir el tamaño al crear la sala. Las reglas del servidor ya conocen las flotas de 5, 6 y 7, pero la partida siempre se crea con 5:
  `DoChangeConfig` está vacío. El cliente tiene que montar el tablero y la bandeja de ese tamaño.

**Modo Demo (para enseñar a jugar).** ✅ Como el sandbox, pero sin reglas ni turnos: se coge cualquier pieza o parte de un nossë,
se suelta en cualquier sat o se devuelve a su bandeja, y se pueden levantar Tampar fuera de la apertura.
Sirve para montar deprisa una posición ("imagina este tablero") y mover piezas a placer mientras se explica.
Se juega siempre desde el lado de las blancas, sin botón de confirmar ni texto de turno, para que no se confunda con una partida.
- Hecho: botón Demo en el menú; `Match.demo` acepta cualquier toma y suelta, soltar fuera del tablero devuelve las piezas a
  su sitio de la bandeja (`Game.send_home`), R levanta una tampa en cualquier momento y lo que cae encima la tumba; nada se suelta sobre una
  hallacirya (vuelve a donde se cogió). Sin turnos,
  lista de movimientos ni código de sala; la ayuda se ve 10 s. Probado en `tests/smoke_demo.gd`.
- Vestida para enseñarse en streaming: quedan el logo de Cirya Palantir y "Juega en play.cirya.me" arriba a la derecha, los
  paneles de Ninquë y Morqua estrechos (sin nombres ni turno) y el cuadro de Movimientos bajo con "Modo Demo" dentro, el
  sitio donde irá la lista cuando se reproduzca una partida.

**Replay de partidas.**
1. Exportar los movimientos en cualquier momento: copiar al portapapeles y guardar en `.txt`, el mismo formato que la lista (`1. c4`…).
   En escritorio, `OS.set_clipboard` y un diálogo de guardar; en web, `JavaScript.download_buffer` (el portapapeles del navegador
   tiene restricciones y hay que probarlo).
   ✅ Hecho en parte: la lista se selecciona con el ratón y se copia con Ctrl+A y Ctrl+C. Falta guardarla en `.txt`.
2. Variante del modo Demo, para el profesor que comenta en retrospectiva una partida espectacular: "Insertar movimientos"
   en el cuadro de Movimientos de la demo, pegar la lista exportada (el mismo formato `1. c4`…), validarla con `Notation.parse`,
   y preguntar antes de reproducirla:
   - **Limpiar el tablero**: todas las piezas vuelven a su bandeja y la lista se juega desde la jugada 1, con la apertura.
   - **Respetar el tablero**: la lista se juega sobre la posición montada a mano. Las jugadas se comprueban con `Rules` sobre
     esa posición y la primera que no cabe se marca y para la reproducción; con quién empieza hay que decidirlo (preguntar,
     o deducirlo del color de la primera jugada si es una colocación).
   Después se recorre con las flechas (→ o ↓ avanza, ← o ↑ retrocede).
   Cada jugada se anima: la pieza sale de su bandeja o del sat de origen, iluminada en morado como al cogerla, y en la rotura
   del nossë se ve cada suelta casilla a casilla.
   ✅ Hecho: "Insertar movimientos" al pie del cuadro de la demo abre un cuadro para pegar la lista (`Notation.parse_list`
   acepta la lista copiada, `1. c3` por línea, o las jugadas seguidas por espacios o comas) y dice la primera que no entiende.
   Luego pregunta: "Limpiar el tablero" o "Respetar el tablero"; al respetarlo, una primera jugada que mueve un nossë dice de
   quién es, y si es una colocación se pregunta quién la hace. Toda la lista se comprueba antes con `Rules.apply_turn`, que la
   juega sobre una copia del tablero, y se para en la primera que no cabe, que queda marcada en la lista ("← no cabe") y
   explicada en la ayuda. Se recorre con → o ↓ (avanza, animada: cada pieza vuela iluminada a su sat, y en un nossë suelta a
   suelta) y ← o ↑ (retrocede: las piezas de la jugada se deslizan a donde estaban). Durante la reproducción las piezas están
   fuera de la física, cada una en su altura de reposo medida, y solo se mueven las de la jugada: nada cae. Mientras, la lista
   se ve en el cuadro de Movimientos, a su anchura normal, con la jugada actual marcada; las piezas no se cogen a mano y "Terminar la reproducción" deja el tablero como esté para seguir
   moviendo a mano. `Replay.gd`; probado en `tests/test_apply.gd`, `test_notation.gd` y `smoke_demo.gd`.
- Base que ya existe: `Notation.parse`, y `Rules.replay`, que ya traduce una jugada (también la apertura y la rotura del nossë)
  en pasos pieza → sat para mostrar las jugadas del rival. Retroceder es volver a una copia de `BoardState` y recolocar las piezas
  como `_lay_out` al reconstruir desde el servidor.
- Falta: animar con `Tween` en vez de soltar la pieza y dejarla caer (con las piezas en `MODE_STATIC` mientras se mueven, para que
  la física no las tumbe), y el cuadro para pegar y validar la lista.
- Orden propuesto: exportar (horas), modo Demo (medio día o un día), replay animado sobre el Demo (uno o dos días).

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
