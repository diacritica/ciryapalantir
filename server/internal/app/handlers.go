package app

import (
	"log"
)

// Runs inside the room goroutine: handlers can use the room and its game freely
func HandleMessage(m Message, r *room, c *Client) {
	switch m.Type() {
	case Connect:
		DoConnect(m, r, c)

	case Disconnect:
		DoDisconnect(m, r, c)

	case GetStatus:
		DoGetStatus(m, r, c)

	case ChangeConfig:
		DoChangeConfig(m, r, c)

	case JoinGame:
		DoJoinGame(m, r, c)

	case LeaveGame:
		DoLeaveGame(m, r, c)

	case SetReady:
		DoSetReady(m, r, c)

	case SubmitTurn:
		DoSubmitTurn(m, r, c)

	default:
		log.Printf("Cannot handle message %s", m.Type())
	}
}

func DoConnect(m Message, r *room, c *Client) {
	DoGetStatus(m, r, c)
	r.BroadcastExcept(c, UserJoinedMessage(c.user))
}

func DoDisconnect(m Message, r *room, c *Client) {
	r.Broadcast(UserLeftMessage(c.user))
}

func DoGetStatus(m Message, r *room, c *Client) {
	msg := StatusResponseMessage(r.game)
	msg.AddStatus(r.game.Status())
	r.Reply(c, msg)
}

func DoChangeConfig(m Message, r *room, c *Client) {
	log.Print("DoChangeConfig")
}

func DoJoinGame(m Message, r *room, c *Client) {
	// TODO Handle errors

	name, _ := m.GetString("name")
	player, _ := m.GetInt("player")
	color, _ := m.GetString("color")

	r.game.AddPlayer(name, player, color)

	msg := PlayerJoinedMessage(name, player, color)
	r.Broadcast(msg)
}

func DoLeaveGame(m Message, r *room, c *Client) {
	player, _ := m.GetInt("player")
	r.game.RemovePlayer(player)
	msg := PlayerLeftMessage(player)
	r.Broadcast(msg)
}

func DoSetReady(m Message, r *room, c *Client) {
	g := r.game
	player, _ := m.GetInt("player")
	ready, _ := m.GetBool("ready")

	g.SetReady(player, ready)

	msg := ReadyChangedMessage(player, ready)
	r.Broadcast(msg)

	// If both players are ready we can start the game, only once
	if g.Status().State == NOT_STARTED && g.ArePlayersReady() {
		g.StartGame()

		msg = StartGameMessage()
		msg.AddStatus(g.Status())
		r.Broadcast(msg)
	}
}

func DoSubmitTurn(m Message, r *room, c *Client) {
	g := r.game
	player, _ := m.GetInt("player")
	turn, _ := m.GetInt("turn")
	move, _ := m.GetString("move")

	if player == g.CurrentPlayer() && turn == g.CurrentTurn() {
		result, err := g.Turn(move)

		var msg Message

		if err != nil {
			r.Reply(c, InvalidTurnMessage(err.Error()))
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
