package app

import "cirya.me/server/internal/cirya"

func statusResponse(status GameStatus) *Message {
	return &Message{Type: StatusResponse, Status: &status}
}

func userJoined(user ID) *Message {
	return &Message{Type: UserJoined, Params: Params{"username": user}}
}

func userLeft(user ID) *Message {
	return &Message{Type: UserLeft, Params: Params{"username": user}}
}

func playerJoined(name string, player int, color string) *Message {
	return &Message{Type: PlayerJoined, Params: Params{"name": name, "player": player, "color": color}}
}

func playerLeft(player int) *Message {
	return &Message{Type: PlayerLeft, Params: Params{"player": player}}
}

func readyChanged(player int, ready bool) *Message {
	return &Message{Type: ReadyChanged, Params: Params{"player": player, "ready": ready}}
}

func gameStarted(status GameStatus) *Message {
	return &Message{Type: StartGame, Params: Params{"nextPlayer": 1, "nextTurn": 1}, Status: &status}
}

func turnPlayed(player, turn int, move string, nextPlayer, nextTurn int, status GameStatus) *Message {
	return &Message{
		Type: Turn,
		Params: Params{
			"player":     player,
			"turn":       turn,
			"move":       move,
			"nextPlayer": nextPlayer,
			"nextTurn":   nextTurn,
		},
		Status: &status,
	}
}

func gameFinished(result GameState, condition cirya.WinCondition, turn int, status GameStatus) *Message {
	return &Message{
		Type:   GameFinished,
		Params: Params{"result": result, "winCondition": condition, "turn": turn},
		Status: &status,
	}
}

// The move is not legal: only the player who sent it gets this
func invalidTurn(err error) *Message {
	return &Message{Type: InvalidTurn, Params: Params{"error": err.Error()}}
}

// A request the game refuses: only the user who sent it gets this
func errorMessage(code ErrorCode, text string) *Message {
	return &Message{Type: Error, Params: Params{"code": code, "message": text}}
}
