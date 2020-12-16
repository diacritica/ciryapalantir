package app

func ConnectMessage(user User) Message {
	return &message {
		FromUser: user.Id(),
		Kind: Connect,
	}
}

func DisconnectMessage(user User) Message {
	return &message {
		FromUser: user.Id(),
		Kind: Disconnect,
	}
}

func StatusResponseMessage(g Game) Message {
	return &message {
		Kind: StatusResponse,
	}
}

func ConfigChangedMessage() Message {
	return nil
}

func UserJoinedMessage(user User) Message {
	params := make(ParamMap)
	params["username"] = user.Id()
		
	return &message {
		Kind: UserJoined,
		Params: params,
	}
}

func UserLeftMessage(user User) Message {
	params := make(ParamMap)
	params["username"] = user.Id()
	
	return &message {
		Kind: UserLeft,
		Params: params,
	}
}

func PlayerJoinedMessage(name string, player int, color string) Message {
	params := make(ParamMap)
	params["name"] = name
	params["player"] = player
	params["color"] = color
	
	return &message {
		Kind: PlayerJoined,
		Params: params,
	}
}

func PlayerLeftMessage(player int) Message {
	params := make(ParamMap)
	params["player"] = player
	
	return &message {
		Kind: PlayerLeft,
		Params: params,
	}
}

func ReadyChangedMessage(player int, ready bool) Message {
	params := make(ParamMap)
	params["player"] = player
	params["ready"] = ready
	
	return &message {
		Kind: ReadyChanged,
		Params: params,
	}
}

func StartGameMessage() Message {
	params := make(ParamMap)
	params["nextPlayer"] = 1
	params["nextTurn"] = 1
	
	return &message {
		Kind: StartGame,
		Params: params,
	}
}

func TurnMessage(player int, turn int, move string, nextPlayer int, nextTurn int) Message {
	params := make(ParamMap)
	params["player"] = player
	params["turn"] = turn
	params["move"] = move
	params["nextPlayer"] = nextPlayer
	params["nextTurn"] = nextTurn
	
	return &message {
		Kind: Turn,
		Params: params,
	}
}

func GameFinishedMessage(state GameState, winCondition WinCondition, turn int) Message {
	params := make(ParamMap)
	params["result"] = string(state)
	params["winCondition"] = string(winCondition)
	params["turn"] = turn
	
	return &message {
		Kind: GameFinished,
		Params: params,
	}
}

func InvalidTurnMessage(error string) Message {
	params := make(ParamMap)
	params["error"] = error
	
	return &message {
		Kind: InvalidTurn,
		Params: params,
	}
}
