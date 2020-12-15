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
    "ambient": "ROYAL",
    "pieces": "WOOD",
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

=> Will send back a **StatusResponse** to the User
=> Will send a **UserJoined** to the other users

### (Disconnect)

=> Will send a **UserLeft** to the other users
=> If the user is a player will send a **PlayerLeft** as well

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
=> Will send a "**PlayerJoined**" to the other users


### LeaveGame

```json
{
    "type": "LeaveGame",
    "params": {
        "player": 1
    }
}
```
=> Will send a "**PlayerLeft**" to the other users

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
=> Will send a "**ReadyChanged**" to the other users

### Submit

```json
{
    "type": "SubmitTurn",
    "params": {
        "player": 1,
        "turn": 20,
        "move": "a6 f6"
    }
}
```

=> Will calculate the game status and send either "**Turn**" or "**GameFinished**"
=> If the turn is not valid the user will recive an "**InvalidTurn**" **notification**




## Notifications

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
        "state": "WAITING_1",
        "turn: 20,
        "moves": [ "a6 f6", ... ],
        "board": {
            "a": {
                1: ["C1", "C2", "T1"]
            },
            "d": {
                3: ["H1"]
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

### Turn

```json
{
    "type": "Turn",
    "params": {
        "player": 1,
        "turn": 10,
        "move": "a6 f6",
        "next": 2
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

The format of every stone is "TYPE+PLAYER" where Type is: C (Cirya), S (Tampa), H (Hallacirya). So for example the previous examples:

["C1", "C2", "T1"] is a stack where the stone at the bottom is a Cirya belonging to player 1, then another Cirya for player 2 and finally a Tampa for player 1.

When there is no entry for a row/column it means it's an empty position (so equivalent to []).

## Game states

* WAITING_PLAYERS: Status given to the game when it's first initialized. Will change once the game is ready
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
        "state": "WAITING_PLAYERS"
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
        "state": "WAITING_PLAYERS"
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
