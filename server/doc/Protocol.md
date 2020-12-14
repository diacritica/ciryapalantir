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
    "player": 1
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
    "config": { .. }
    "players": {
        1: "USER_ID",
        2: "USER_ID"
    },
    "status": "WAITING_1", // WAITING_PLAYERS, TURN_X, WIN_X
    "turn: 20,
    "moves": [ "a6 f6", ... ],
    "board": {
        "a": {
            1: ["F1", "F2", "S1"]
        },
        "d": {
            3: ["C1"]
        }
    }
}
```

#### Game started


### UserJoined

### PlayerJoined

### PlayerReady

### StartGame

### TurnPlayed
