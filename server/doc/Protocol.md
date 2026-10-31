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

Creates a room with a new code. The configuration is not sent yet: every game is a 5x5 board.

**Response**

```json
{ "id": "KM7Q2X" }
```

Codes have 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no 0/O or 1/I/L).

# WEBSOCKET API

After a room has been created the user can join the WS to send actions and receive notifications related to that room.

The URL to connect will be:

```
ws://IP:PORT/rooms/{code}
```

The `cirya-user` cookie has to be sent. Connecting to a code that does not exist creates that room.

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

### (Connect)

Action by default when you connect to the server. The server will send you back a notification of `Status` with the current state of the room.

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

TODO

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

### Submit

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
        "message": "It is not your turn"
    }
}
```

Codes: `BAD_MESSAGE`, `SEAT_TAKEN`, `NOT_YOUR_SEAT`, `NOT_YOUR_TURN`, `STALE_TURN`,
`GAME_NOT_STARTED`, `GAME_STARTED`, `GAME_FINISHED`.

### InvalidTurn

The move does not follow the rules. The turn does not change and the player can send another move.

```json
{
    "type": "InvalidTurn",
    "params": {
        "error": "Cannot put stones over Tampar"
    }
}
```

### StatusResponse

```json
{
    "type": "StatusResponse",
    "status": {
        "config": { .. },
        "players": {
            1: { "name: "Name1", "color": "white", "ready": true },
            2: { "name: "Name2", "color": "black", "ready": true }
        },
        "state": "TURN_1",
        "turn: 20,
        "moves": [ "a6 f6", ... ],
        "board": {
            "1": {
                "a": ["C1", "C2", "T1"]
            },
            "3": {
                "d": ["H1"]
            }
        }
    }
}
```

### ConfigChanged

TODO

### UserJoined

```json
{
    "type": "UserJoined",
    "params: {
        "username": "alan-turing"
    }
}
```

### UserLeft

```json
{
    "type": "UserLeft",
    "params: {
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
        "player": 1,
        "turn": 10,
        "move": "a6 f6",
        "nextPlayer": 2,
        "nextTurn": 2
    },
    "status": { ... }
}
```

### GameFinished

```json
{
    "type": "GameFinished",
    "params": {
        "result": "WIN_1"
        "winCondition": "LONDI",
        "turn": 10
    },
    "status": { ... }
}
```

## Normal game flow

This will be a "normal" game flow. After the room has been created the users will join the room by connecting to the Websocket for that room. Everyone player that connects will receive a "**Status**" and the rest of the users will receive a notification "UserJoined".

After that, we need both players. Two of the users should send messages "**RequestPlayer**" with both slots (player 1/2).

Every player need to send a "**Ready**" message before the game can start. When both players send a "**Ready**" the game status will change to show the turn of the first player and a "**TurnPlayer**" will be send to all peers indicating that the system is waiting for the turn of the player.

Only the player whose turn is now can send the message "SendTurn" with his next move. The game will process the turn and eventually will notify the "TurnPlayer" with the next player and the new board state.

One after the other both players send turns until one of them wins the match and a message "GameFinished" is send.

## Board representation

A game board is a square grid where the corner bottom/left is "a1". The opposite corner depends on the board size. For a board of 5x5 is 5e and for 7x7 is 7g

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
    "type": "Status"
    "status": {
        "config": { ... },
        "players": {},
        "state": "NOT_STARTED"
    }
}
```

**First player joined, select to play as Player 2 using white**

```json
{
    "type": "Status"
    "status": {
        "config": { ... },
        "players": {
            "2": { "name: "Name2", "color": "white", "ready": false }
        },
        "state": "NOT_STARTED"
    }
}
```

**Both players joined and ready. Wainting for first move**

```json
{
    "type": "Status"
    "status": {
        "owner": "USER_ID",
        "config": { ... },
        "players": {
            "1": { "name: "Name1", "color": "white", "ready": true },
            "2": { "name: "Name2", "color": "white", "ready": true }
        },
        "state": "TURN_1",
        "moves": [],
        "board": {}
    }
}
```
