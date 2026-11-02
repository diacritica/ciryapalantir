# REST API

## Rooms

### PUT /users

**Response**

```json
{ "id": "K7M2Q9XZ4HR8T3WA" }
```

When the request has no `cirya-user` cookie a new user is created and the response sets the cookie
(path `/`, one year) with the same id. The cookie identifies the user in the websocket.

### PUT /rooms

Creates a room with a new code. Every game is a 5x5 board; the clock and the rules are chosen in the room with **ChangeConfig**.

**Response**

```json
{ "id": "KM7Q2X" }
```

Codes have 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no 0/O or 1/I/L).

### GET /check

Answers `OK` while the server is up.

# WEBSOCKET API

After a room has been created the user can join the WS to send actions and receive notifications related to that room.

The URL to connect will be:

```
ws://IP:PORT/rooms/{code}
```

The `cirya-user` cookie has to be sent. A code that no room has gets `404 Not Found`.
A room ends when it has had no clients for an hour (`-idle` of the server), and its code is free again.

The server sends a ping every 54 seconds and closes connections that do not answer (or send anything) for 60 seconds.
A client that does not read its messages fast enough is disconnected.

The general format to send actions notifications

```json
{
    "type": "ActionType",
    "params": { ... }
}

```

## Actions

Connect and Disconnect, in brackets, are not messages: the server does them when the websocket opens and closes.
Messages from the client with any type that is not an action are ignored.

### (Connect)

Done when you connect to the server. The server will send you back a notification of `Status` with the current state of the room.

=> Will send back a **StatusResponse** to the User
=> Will send a **UserJoined** to the other users

### (Disconnect)

=> Will send a **UserLeft** to the other users

Players keep their seat: they can connect again with the same cookie and keep playing.

### GetStatus

```json
{
    "type": "GetStatus"
}
```
=> Will send back a **StatusResponse** to the User

### ChangeConfig

```json
{
    "type": "ChangeConfig",
    "params": {
        "clock": 300,
        "hennethAnnun": true
    }
}
```
=> Will send a **ConfigChanged** to every user

Either param can be left out, and then it does not change; at least one has to come (**Error** `BAD_MESSAGE`).
* `clock`: seconds for each player, one of 0 (no clock), 180, 300 (the default), 600 or 900 (**Error** `BAD_MESSAGE`).
* `hennethAnnun`: true or false. Each hallacirya only goes into play in one turn, the 16th of black and the 17th of white,
  which are the turns 32 and 33 of the game; in any other one, placing it is an **InvalidTurn**. The player should play it
  in that turn unless that loses the game, but only the player can judge it, so the server does not ask for it. Only on
  the 5x5 board (**Error** `BAD_MESSAGE`).

The configuration is chosen before the game, so the second player always sees the game it is going to play: anyone can
change it while nobody sits, then only the one player sitting, and nobody once both sit (**Error** `CONFIG_LOCKED`) or the
game has started (**Error** `GAME_STARTED`). A refused change leaves all of it as it was.

The clock is described with **GameFinished** and the status.

### JoinGame

```json
{
    "type": "JoinGame",
    "params": {
        "player": 1,
        "color": "white",
        "name": "Anarion"
    }
}
```
=> Will send a "**PlayerJoined**" to every user

`player` has to be 1 or 2. The seat belongs to the user who takes it: nobody else can take it,
get ready or play with it (**Error** `SEAT_TAKEN`). The same user can take both seats.

When the game has started, the owner of the seat gets a **StatusResponse** back (reconnection).
Other users get **Error** `GAME_STARTED` or `SEAT_TAKEN`.

### LeaveGame

```json
{
    "type": "LeaveGame",
    "params": {
        "player": 1
    }
}
```
=> Will send a "**PlayerLeft**" to every user

Only the owner of the seat, and only before the game starts (**Error** `NOT_YOUR_SEAT`, `GAME_STARTED`).

### SetReady

```json
{
    "type": "SetReady",
    "params": {
        "player": 1,
        "ready": false
    }
}
```
=> Will send a "**ReadyChanged**" to every user
=> If both players are ready, will send a **StartGame** to every user

Only the owner of the seat, and only before the game starts (**Error** `NOT_YOUR_SEAT`, `GAME_STARTED`).
`ready` has to be true or false (**Error** `BAD_MESSAGE`).

### SubmitTurn

```json
{
    "type": "SubmitTurn",
    "params": {
        "player": 1,
        "turn": 20,
        "move": "3a2>12"
    }
}
```

=> Will calculate the game status and send either "**Turn**" or "**GameFinished**" to every user
=> If the move is not valid the user will receive an "**InvalidTurn**" **notification**

Before checking the move, the user receives an **Error** when:

* the game has not started or is over: `GAME_NOT_STARTED`, `GAME_FINISHED`
* the user does not own the seat in `player`: `NOT_YOUR_SEAT`
* it is the turn of the other player: `NOT_YOUR_TURN`
* `turn` is not the current turn: `STALE_TURN`


## Notifications

### Error

Only sent to the user whose request could not be done. Nothing changes in the room.

```json
{
    "type": "Error",
    "params": {
        "code": "NOT_YOUR_TURN",
        "message": "it is not your turn"
    }
}
```

Codes: `BAD_MESSAGE`, `SEAT_TAKEN`, `NOT_YOUR_SEAT`, `NOT_YOUR_TURN`, `STALE_TURN`,
`GAME_NOT_STARTED`, `GAME_STARTED`, `GAME_FINISHED`, `CONFIG_LOCKED`.

### InvalidTurn

The move does not follow the rules. The turn does not change and the player can send another move.

```json
{
    "type": "InvalidTurn",
    "params": {
        "error": "cannot drop on c3: only a lone hallacirya goes over a tampa"
    }
}
```

### StatusResponse

```json
{
    "type": "StatusResponse",
    "status": {
        "config": { "ambient": "TAVERN", "pieces": "WOOD", "size": 5, "clock": 300, "hennethAnnun": false },
        "players": {
            "1": { "name": "Name1", "color": "white", "ready": true },
            "2": { "name": "Name2", "color": "black", "ready": true }
        },
        "state": "TURN_1",
        "turn": 21,
        "currentPlayer": 1,
        "moves": [ "a5", "e5", "3a2>12", ... ],
        "board": {
            "1": {
                "a": ["C1", "C2", "T1"]
            },
            "3": {
                "d": ["H1"]
            }
        },
        "fleets": {
            "1": { "ciryar": 12, "hallaciryar": 0 },
            "2": { "ciryar": 13, "hallaciryar": 1 }
        },
        "clocks": { "1": 254300, "2": 187020 },
        "clockRunning": 1
    }
}
```

`players` only has the seats taken and is left out when there are none.
`turn`, `currentPlayer`, `moves`, `board` and `fleets` only come once the game has started; empty squares are left out of `board`.
When the game is over `currentPlayer` is 0.
`clocks` (milliseconds left to each player, at the moment the message is sent) and `clockRunning` (the player whose clock
runs, 0 when none does) only come once a game with clock has started. No clock runs during the openings: the clock of
player 1 starts when player 2 has played turn 2, and from then on each clock runs from the end of the turn of the other
player until the server takes the move of its own player. A refused move does not stop it, nor does a lost connection,
and no time is added after a turn. The clients count down on their own and correct it with every message.

### ConfigChanged

The whole configuration, after a **ChangeConfig**.

```json
{
    "type": "ConfigChanged",
    "params": {
        "config": { "ambient": "TAVERN", "pieces": "WOOD", "size": 5, "clock": 600, "hennethAnnun": true }
    }
}
```

### UserJoined

```json
{
    "type": "UserJoined",
    "params": {
        "username": "alan-turing"
    }
}
```

### UserLeft

```json
{
    "type": "UserLeft",
    "params": {
        "username": "alan-turing"
    }
}
```

### PlayerJoined

```json
{
    "type": "PlayerJoined",
    "params": {
        "name": "Alan Turing",
        "player": 1,
        "color": "white"
    }
}
```

### PlayerLeft

```json
{
    "type": "PlayerLeft",
    "params": {
        "player": 1
    }
}
```

### ReadyChanged

```json
{
    "type": "ReadyChanged",
    "params": {
        "player": 1,
        "ready": true
    }
}
```
### StartGame

```json
{
    "type": "StartGame",
    "params": {
        "nextPlayer": 1,
        "nextTurn": 1
    },
    "status": { ... }
}
```

### Turn

```json
{
    "type": "Turn",
    "params": {
        "player": 2,
        "turn": 10,
        "move": "3a2>12",
        "nextPlayer": 1,
        "nextTurn": 11
    },
    "status": { ... }
}
```

### GameFinished

```json
{
    "type": "GameFinished",
    "params": {
        "result": "WIN_1",
        "winCondition": "LONDI",
        "turn": 10
    },
    "status": { ... }
}
```

* `result`: `WIN_1`, `WIN_2` or `DRAW`.
* `winCondition`:
  * `LONDI`: a player joined two opposite sides of the board with orthogonally adjacent squares topped by
    their ciryar or hallaciryar (tampar do not count). If a move completes both londi, the player who moved wins.
  * `FLAT`: the board is full or a player has placed the whole fleet. Wins the player with more squares
    topped by a flat cirya (tampar, hallaciryar and empty squares do not count). Same count: `DRAW`.
  * `TIME`: the clock of the loser reached 0, however the board was. The server sends it on its own when the clock runs
    out, or instead of the **Turn** of a move that came too late, which is not played. `turn` is then the turn that was
    not played, and the last of `moves` is not a move that ended the game.

## Rules checked by the server

* **Opening:** in turns 1 and 2 each player places a flat cirya **of the opponent** (taken from the opponent's fleet).
  Only a plain placement is allowed, like `a5`.
* **Fleets:** 5x5: 21 ciryar + 1 hallacirya; 6x6: 30 + 2; 7x7: 40 + 2. Tampar come from the ciryar.
  What is left is sent in `status.fleets`: `{ "1": { "ciryar": 15, "hallaciryar": 1 }, "2": { ... } }`.
* **Moves:** at most as many stones as the board size, and the drops have to add up to the stones taken.

## Normal game flow

1. A user creates a room (`PUT /rooms`) and shares its code. Everybody connects to the websocket of the room:
   each one gets a **StatusResponse** and the others a **UserJoined**.
2. Before sitting, or while alone in a seat, a user can choose the clock and the rules with **ChangeConfig**, and
   everybody gets **ConfigChanged**.
3. Two users take the seats with **JoinGame** (players 1 and 2) and everybody gets **PlayerJoined**.
4. Both send **SetReady**. When the second one is ready everybody gets **StartGame**, and it is the turn of player 1.
5. The player whose turn it is sends **SubmitTurn**. Everybody gets **Turn** with the move and who plays next.
   A move against the rules gets **InvalidTurn** and the same player tries again.
6. When a move ends the game everybody gets **GameFinished** instead of **Turn**.

## Board representation

A game board is a square grid where the corner bottom/left is "a1". The opposite corner depends on the board size. For a board of 5x5 it is e5 and for 7x7 it is g7.

Inside a square there is a list of "stones". The first index represents the stone at the **bottom** of the stack. 

The board is keyed first by rank ("1".."9") and then by file ("a".."i"): `board["1"]["a"]` is the square a1.

The format of every stone is "TYPE+PLAYER" where Type is: C (Cirya), T (Tampa), H (Hallacirya). So for example the previous examples:

["C1", "C2", "T1"] is a stack where the stone at the bottom is a Cirya belonging to player 1, then another Cirya for player 2 and finally a Tampa for player 1.

When there is no entry for a row/column it means it's an empty position (so equivalent to []).

## Game states

* NOT_STARTED: Status given to the game when it's first initialized. Will change once both players are ready
* TURN_1/TURN_2: Turn for the player 1/2 will reject movements given by the other player
* WIN_1/WIN_2: Game finished won by the player 1/2
* DRAW: Game finished with a draw

#### Examples

**Blank, no users joined**

```json
{
    "type": "StatusResponse",
    "status": {
        "config": { ... },
        "state": "NOT_STARTED"
    }
}
```

**First player joined, select to play as Player 2 using white**

```json
{
    "type": "StatusResponse",
    "status": {
        "config": { ... },
        "players": {
            "2": { "name": "Name2", "color": "white", "ready": false }
        },
        "state": "NOT_STARTED"
    }
}
```

**Both players joined and ready. Waiting for the first move**

```json
{
    "type": "StatusResponse",
    "status": {
        "config": { ... },
        "players": {
            "1": { "name": "Name1", "color": "white", "ready": true },
            "2": { "name": "Name2", "color": "black", "ready": true }
        },
        "state": "TURN_1",
        "turn": 1,
        "currentPlayer": 1,
        "fleets": { "1": { "ciryar": 21, "hallaciryar": 1 }, "2": { "ciryar": 21, "hallaciryar": 1 } }
    }
}
```
