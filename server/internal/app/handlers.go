package app

import (
	"fmt"
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
	// Reserved: the configuration cannot be changed yet
}

func fail(r *room, c *Client, code ErrorCode, text string) {
	r.Reply(c, ErrorMessage(code, text))
}

// Reads the "player" param, which has to be a seat: 1 or 2
func seatParam(m Message, r *room, c *Client) (int, bool) {
	player, err := m.GetInt("player")

	if err != nil || (player != 1 && player != 2) {
		fail(r, c, BAD_MESSAGE, "player has to be 1 or 2")
		return 0, false
	}

	return player, true
}

// Checks the user of the client sits in the given seat
func ownsSeat(r *room, c *Client, player int) bool {
	seat, ok := r.game.Seat(player)

	if !ok || seat.UserID != c.user.Id() {
		fail(r, c, NOT_YOUR_SEAT, "This seat belongs to another user")
		return false
	}

	return true
}

func DoJoinGame(m Message, r *room, c *Client) {
	g := r.game
	player, ok := seatParam(m, r, c)

	if !ok {
		return
	}

	name, _ := m.GetString("name")
	color, _ := m.GetString("color")
	seat, taken := g.Seat(player)

	if taken && seat.UserID != c.user.Id() {
		fail(r, c, SEAT_TAKEN, "This seat is taken by another user")
		return
	}

	// The owner of the seat is coming back to a started game
	if g.State() != NOT_STARTED {
		if taken {
			DoGetStatus(m, r, c)
		} else {
			fail(r, c, GAME_STARTED, "The game has already started")
		}
		return
	}

	g.AddPlayer(c.user.Id(), name, player, color)

	msg := PlayerJoinedMessage(name, player, color)
	r.Broadcast(msg)
}

func DoLeaveGame(m Message, r *room, c *Client) {
	player, ok := seatParam(m, r, c)

	if !ok || !ownsSeat(r, c, player) {
		return
	}

	if r.game.State() != NOT_STARTED {
		fail(r, c, GAME_STARTED, "Cannot leave a started game")
		return
	}

	r.game.RemovePlayer(player)
	msg := PlayerLeftMessage(player)
	r.Broadcast(msg)
}

func DoSetReady(m Message, r *room, c *Client) {
	g := r.game
	player, ok := seatParam(m, r, c)

	if !ok || !ownsSeat(r, c, player) {
		return
	}

	if g.State() != NOT_STARTED {
		fail(r, c, GAME_STARTED, "The game has already started")
		return
	}

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

func DoSubmitTurn(m Message, r *room, c *Client) {
	g := r.game

	switch g.State() {
	case NOT_STARTED:
		fail(r, c, GAME_NOT_STARTED, "The game has not started yet")
		return
	case WIN_1, WIN_2, DRAW:
		fail(r, c, GAME_FINISHED, "The game is over")
		return
	}

	player, ok := seatParam(m, r, c)

	if !ok || !ownsSeat(r, c, player) {
		return
	}

	turn, _ := m.GetInt("turn")
	move, _ := m.GetString("move")

	if player != g.CurrentPlayer() {
		fail(r, c, NOT_YOUR_TURN, "It is not your turn")
		return
	}

	if turn != g.CurrentTurn() {
		fail(r, c, STALE_TURN, fmt.Sprintf("Expected turn %d", g.CurrentTurn()))
		return
	}

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
