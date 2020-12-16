package app

import (
	"log"
)

func HandleMessage(m Message, r Room, g Game) {
	switch m.Type() {
	case Connect:
		go DoConnect(m, r, g)
		
	case Disconnect:
		go DoDisconnect(m, r, g)
		
	case GetStatus:
		go DoGetStatus(m, r, g)
		
	case ChangeConfig:
		go DoChangeConfig(m, r, g)
		
	case JoinGame:
		go DoJoinGame(m, r, g)

	case LeaveGame:
		go DoLeaveGame(m, r, g)

	case SetReady:
		go DoSetReady(m, r, g)
		
	case SubmitTurn:
		go DoSubmitTurn(m, r, g)

	default:
		log.Printf("Cannot handle message %s", m.Type())
	}
}

func DoConnect(m Message, r Room, g Game) {
	user := m.User()
	r.AddUser(user)

	msg := UserJoinedMessage(user)
	r.Broadcast(msg)
}

func DoDisconnect(m Message, r Room, g Game) {
	user := m.User()
	r.RemoveUser(user)

	msg := UserLeftMessage(user)
	r.Broadcast(msg)
}

func DoGetStatus(m Message, r Room, g Game) {
	user := m.User()
	msg := StatusResponseMessage(g)
	msg.AddStatus(g.Status())
	r.UserMessage(user) <- msg
}

func DoChangeConfig(m Message, r Room, g Game) {
	log.Print("DoChangeConfig")
}

func DoJoinGame(m Message, r Room, g Game) {
	// TODO Handle errors

	name, _ := m.GetString("name")
	player, _ := m.GetInt("player")
	color, _ := m.GetString("color")

	g.AddPlayer(name, player, color)

	msg := PlayerJoinedMessage(name, player, color)
	r.Broadcast(msg)
}

func DoLeaveGame(m Message, r Room, g Game) {
	player, _ := m.GetInt("player")
	g.RemovePlayer(player)
	msg := PlayerLeftMessage(player)
	r.Broadcast(msg)
}

func DoSetReady(m Message, r Room, g Game) {
	player, _ := m.GetInt("player")
	ready, _ := m.GetBool("ready")

	g.SetReady(player, ready)
	
	msg := ReadyChangedMessage(player, ready)
	r.Broadcast(msg)

	// If both players are ready we can start the game
	if g.ArePlayersReady() {
		g.StartGame()

		msg = StartGameMessage()
		msg.AddStatus(g.Status())
		r.Broadcast(msg)
	}
}

func DoSubmitTurn(m Message, r Room, g Game) {
	player, _ := m.GetInt("player")
	turn, _ := m.GetInt("turn")
	move, _ := m.GetString("move")

	if player == g.CurrentPlayer() && turn == g.CurrentTurn() {
		result, err := g.Turn(move)

		var msg Message

		if err != nil {
			user := m.User()
			r.UserMessage(user) <- InvalidTurnMessage(err.Error())
			return
		}

		if result.EndGame {
			msg = GameFinishedMessage(result.State, result.WinCondition, turn)
		} else {
			msg = TurnMessage(player, turn, move, result.NextPlayer, result.NextTurn)
		}

		msg.AddStatus(g.Status())

		r.Broadcast(msg)
	}

}
