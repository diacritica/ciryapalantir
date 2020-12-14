# REST API

## Rooms

### PUT /users

**Request**

```json
{ "username": "alan-turing" }
```

**Response**

If the response is OK will retrieve a `Set-Cookie` that will allow the user to continue sending requests

### PUT /rooms

**Request**

```json
{
    "ambient": "ROYAL", // ROYAL, TAVERN
    "pieces": "WOOD", // "WOOD", "GLOSSY"
    "size": 5
}
```

**Response**

```json
{ "code": "XX-XXXX" }
```

# WEBSOCKET API

After a room has been created the user can join the WS to send actions and receive notifications related to that room.

The URL to connect will be:

```
ws://IP:PORT/ws/rooms/{code}
```

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

### RequestStatus

```json
{
    "type": "RequestStatus"
}
```

### RequestPlayer

```json
{
    "type": "RequestPlayer",
    "player": 1,
    "set": "white"
}
```

### Ready

```json
{
    "type": "Ready"
}
```

### SendTurn

```json
{
    "type": "SendTurn",
    "player": 1,
    "turn": 20,
    "move": "a6 f6"
}
```

## Notifications

### Status

```json
{
    "owner": "USER_ID",
    "config": { .. },
    "players": {
        "1": { "username: "USER_ID", "subset": "white", "ready": true },
        "2": { "username: "USER_ID", "subset": "black", "ready": true }
    },
    "status": "WAITING_1",
    "turn: 20,
    "moves": [ "a6 f6", ... ],
    "board": {
        "a": {
            "1": ["C1", "C2", "T1"]
        },
        "d": {
            "3": ["H1"]
        }
    }
}
```

#### Board representation

A game board is a square grid where the corner bottom/left is "a1". The opposite corner depends on the board size. For a board of 5x5 is 5e and for 7x7 is 7g

Inside a square there is a list of "stones". The first index represents the stone at the **bottom** of the stack. 

The format of every stone is "TYPE+PLAYER" where Type is: C (Cirya), S (Tampa), H (Hallacirya). So for example the previous examples:

["C1", "C2", "T1"] is a stack where the stone at the bottom is a Cirya belonging to player 1, then another Cirya for player 2 and finally a Tampa for player 1.

When there is no entry for a row/column it means it's an empty position (so equivalent to []).

#### Game statuses

* WAITING_PLAYERS: Status given to the game when it's first initialized. Will change once the game is ready
* TURN_1/TURN_2: Turn for the player 1/2 will reject movements given by the other player
* WIN_1/WIN_2: Game finished won by the player 1/2
* DRAW: Game finished with a draw

#### Examples

**Blank, no users joined**

```json
{
    "owner": "USER_ID",
    "config": { ... },
    "players": {},
    "status": "WAITING_PLAYERS"
}
```

**First player joined, select to play as Player 2 using white**

```json
{
    "owner": "USER_ID",
    "config": { ... },
    "players": {
        "2": { "username": "USER_ID", "subset": "white", "ready": false }
    },
    "status": "WAITING_PLAYERS"
}
```

**Both players joined and ready. Wainting for first move**

```json
{
    "owner": "USER_ID",
    "config": { ... },
    "players": {
        "1": { "username": "USER_ID", "subset": "white", "ready": true },
        "2": { "username": "USER_ID", "subset": "white", "ready": true }
    },
    "status": "TURN_1",
    "moves": [],
    "board": {}
}
```

### UserJoined

### PlayerJoined

### PlayerReady

### StartGame

### TurnPlayed
