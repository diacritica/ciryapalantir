# Refactor de servidor y cliente (checkpoint antes del 2.2)

Objetivo: que alguien con mucha experiencia en Go y en GDScript lea el código y pueda seguirlo a mano.
Responsabilidades claras por fichero, máquinas de estado explícitas, tests legibles, comentarios para personas, nada de código muerto.

Decisiones de Pablo: se borra `cmd/cirya-client`, no se borra ningún fichero del cliente, la reestructuración del cliente es completa (C1 a C12)
y cada paso va en su commit, con parada para revisar al acabar el servidor y al acabar el cliente.

Reglas del refactor:
- **Sin cambios de comportamiento.** El protocolo de `server/doc/Protocol.md` es el contrato entre los dos lados.
- Un commit por paso, con todo en verde:
  - `go vet`, `gofmt` y `go test -race ./...` en el servidor.
  - `tests/run.gd` y la carga de `Game.tscn` sin errores de script en el cliente.
- Los arreglos de bugs que aparezcan van **después**, en commits propios, porque cambian el comportamiento.

## Lo que ya está bien y se conserva

- **Servidor:**
  - El actor de sala (una goroutine por sala, sin locks), con el `recover` comentado.
  - Las reglas en `cirya/rules.go` y `fleet.go`.
  - `nosse_test.go`, el modelo de test a seguir.
- **Cliente:**
  - `Validation.move_state`: una función pura de (movimiento, tablero) a resultado, bien cubierta por tests.
  - El modelo del movimiento como foto del tablero al empezar el turno.

## Servidor

**Hecho** (commits `687b859` a `f462586`). Además de los pasos de la tabla:
- Una segunda revisión independiente encontró un bug que ya existía: una sala que expulsaba a un cliente lento no avisaba con `UserLeft` cuando su conexión acababa. Arreglado con su test.
- `SetReady` sin `ready` responde `BAD_MESSAGE`.
- Los mensajes salen en JSON compacto.
- Hay un test que fija la forma del estado que lee Godot.

Unas 1.570 líneas de código y 1.260 de tests. La suite tarda unos 2 s con `-race`.

| # | Paso | Riesgo |
|---|---|---|
| S1 | `gofmt -w`: hay 12 ficheros sin formatear | Mecánico |
| S2 | Quitar trazas: el tablero impreso en cada jugada, `Received:` con el JSON de cada mensaje, los `Println` de los tests | Mecánico |
| S3 | Quitar código muerto: `ConfigChangedMessage`, `message.Get`/`User`, `game.id`, `RESIGN`, ramas imposibles, `utils/` (Python sustituido por `rules.go`) y `cmd/cirya-client` (decisión de Pablo). `ChangeConfig` se queda con un comentario de "reservado" | Mecánico |
| S4 | Constantes con su tipo explícito y en MixedCaps (`NotStarted`, `Londi`, `CodeSeatTaken`…), manteniendo los mismos valores en el protocolo. Un solo `WinCondition`, el de `cirya` | Mecánico, lo vigilan los tests de api |
| S5 | Nombres al estilo Go: `ID`, `NewBoard`, `Controller` (hoy `ControlingPlayer`), sin el prefijo `Get`, `app.go` pasa a `id.go` | Mecánico |
| S6 | Tests de `cirya`: un único helper de tablero (`helpers_test.go`), `moves_test.go` como tabla, argumentos de `assert` en su orden | Solo tests |
| S7 | `game_test.go`: tests de la máquina de estados sin websocket (inicio, turnos, apertura, victoria, empate, `STALE_TURN`, `GAME_NOT_STARTED`). Es la red para S8 y S9 | Solo tests |
| S8 | Tipos concretos en vez de interfaces con una sola implementación (`Game`, `Room`, `Store`, `User`, `Message`, `api.Server`). Los handlers pasan a ser métodos no exportados de `room` | Cuidado medio |
| S9 | Máquina de estados de la partida: un solo dato de verdad (el estado) con `started()`/`finished()`. Fuera `TurnResult`, y las guardas viven en `game`, no repartidas en los handlers. Al acabar, `currentPlayer: 0` se mantiene | **Cuidado** |
| S10 | `MoveStones` en tres partes (leer la notación, validar, aplicar) con un solo recorrido. `slices` en vez de los helpers caseros | **Cuidado**, lo vigila la tabla del nossë |
| S11 | Tests de api con barreras (pedir `GetStatus` y esperar la respuesta) en vez de `Sleep` y ventanas de tiempo: unos 6 s menos y nada sensible al tiempo | Solo tests |
| S12 | api: CORS como middleware (hoy está repetido 4 veces), `cookie.go`, respuestas JSON con `encoding/json` | Cuidado medio |
| S13 | Textos de error en minúscula y sin puntuación. El cliente no los usa, así que no hay riesgo | Mecánico |

Ficheros finales del servidor:
- `cirya/`: `board.go`, `square.go`, `notation.go`, `move.go`, `fleet.go`, `rules.go`.
- `app/`: `id.go`, `message.go`, `notifications.go`, `game.go`, `room.go`, `handlers.go`, `store.go`.
- `api/`: `server.go`, `cookie.go`, `cors.go`, `socket.go`.

## Cliente

| # | Paso | Riesgo |
|---|---|---|
| C1 | Quitar código muerto y trazas: `render_board`, `restore_piece_position`, `simulation`, `undo_board_state`, variables sin uso, bloques comentados y unos 20 `print` | Mecánico |
| C2 | Los ficheros sin uso (`GameUI.*`, `camera.gd`, `Main.tscn`, `Tray5.tscn`, `table-palace2.tscn`, `HallaciryaLV.tscn` y las piezas VIP) **se conservan** por decisión de Pablo. Las ramas VIP de `Fleet.gd` cargan `CiryaLV.tscn`, que no existe: se deja un comentario | Mecánico |
| C3 | Quitar de `Game.tscn` el nodo `Server` repetido | Cuidado (escena) |
| C4 | Constantes para capas de colisión, alturas de pila, duración de la animación y letras de columna | Mecánico |
| C5 | Nombres en snake_case (`show_highlight`, métodos de `Fleet`) y erratas (`pice_index`, `stackOffest`) | Mecánico |
| C6 | `Notation.gd`: casilla ↔ coordenadas y lectura/escritura de jugadas, en un solo sitio | Cuidado medio |
| C7 | `BoardState.gd`: datos puros (pilas por casilla, `piece_square` devuelve coordenadas y no nodos). Los tests ya no necesitan casillas falsas | **Cuidado** |
| C8 | `Rules.gd` (hoy `Validation`) recibe lo que necesita como argumentos. Se rompe la dependencia circular con `Global` | **Cuidado** |
| C9 | El arrastre pasa de `Global` a `Game.gd`, con un estado explícito (`IDLE`, `DRAGGING`, `RETURNING`) y `_input` partido en pulsar, soltar, mover y girar | **Cuidado** |
| C10 | La reproducción de jugadas del rival pasa a `Game`/`Board`, que son los que mueven piezas 3D. `Global` queda como el estado de la partida y se renombra `Match` | **Cuidado** |
| C11 | Fases del turno explícitas (`WAITING`, `MY_TURN`, `SUBMITTED`, `OPPONENT`, `FINISHED`), con una señal que la UI escucha en vez de recibir llamadas directas | **Cuidado** |
| C12 | Tests repartidos: `test_rules.gd` (puro), `test_notation.gd` (ida y vuelta) y `test_turns.gd`, con un runner que encuentra los `test_*` | Solo tests |

Ficheros finales del cliente:
- `autoload/`: `Match.gd`, `Server.gd`, `Settings.gd`.
- `core/`: `BoardState.gd`, `Move.gd`, `Rules.gd`, `Notation.gd`.
- Escenas: `Game`, `Board`, `Tile`, `Fleet`, `UI`, `Unit`.
- `tests/`.

## Bugs encontrados (después del refactor, un commit cada uno)

- **Servidor:** las salas y sus goroutines no se liberan nunca. Basta un comentario por ahora.
- **Cliente:**
  - El número de jugada del rival sale mal: el cliente ignora `nextTurn`.
  - `InvalidTurn` y `GameFinished` no se tratan, y "Confirmar" da el movimiento por bueno antes de que conteste el servidor (esto ya está en 2.3).
  - Error de precedencia en `data_received` (`a and b || c`).
  - "Deshacer" no deshace el giro de una pieza de la bandeja (R).
  - `board_state` y `pieces` no se vacían entre partidas.
  - `Settings.low()` fallaría porque busca un `GIProbe` que no existe.
