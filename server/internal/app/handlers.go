package app

import (
	"errors"
	"log"

	"cirya.me/server/internal/cirya"
)

// The handlers run in the room goroutine. They read the params, ask the game
// and tell the clients: the rules about seats and turns live in Game. A
// missing player, turn or move gets the answer of the game for a wrong one

func (r *Room) dispatch(m *Message, c *Client) {
	switch m.Type {
	case GetStatus:
		r.reply(c, statusResponse(r.game.Status()))
	case ChangeConfig:
		r.onChangeConfig(m, c)
	case JoinGame:
		r.onJoinGame(m, c)
	case LeaveGame:
		r.onLeaveGame(m, c)
	case SetReady:
		r.onSetReady(m, c)
	case SubmitTurn:
		r.onSubmitTurn(m, c)
	default:
		log.Printf("room %s: cannot handle %s", r.code, m.Type)
	}
}

func (r *Room) onConnect(c *Client) {
	r.reply(c, statusResponse(r.game.Status()))
	r.broadcastExcept(c, userJoined(c.user))
}

func (r *Room) onDisconnect(c *Client) {
	r.broadcast(userLeft(c.user))
}

func (r *Room) onChangeConfig(m *Message, c *Client) {
	var clock *int
	var hennethAnnun *bool

	if _, present := m.Params["clock"]; present {
		value, ok := m.intParam("clock")

		if !ok {
			r.reply(c, errorMessage(CodeBadMessage, "clock has to be a number of seconds"))
			return
		}

		clock = &value
	}

	if _, present := m.Params["hennethAnnun"]; present {
		value, ok := m.boolParam("hennethAnnun")

		if !ok {
			r.reply(c, errorMessage(CodeBadMessage, "hennethAnnun has to be true or false"))
			return
		}

		hennethAnnun = &value
	}

	if clock == nil && hennethAnnun == nil {
		r.reply(c, errorMessage(CodeBadMessage, "nothing to change: send clock or hennethAnnun"))
		return
	}

	config, err := r.game.ChangeConfig(c.user, clock, hennethAnnun)

	if err != nil {
		r.refuse(c, err)
		return
	}

	r.broadcast(configChanged(config))
}

func (r *Room) onJoinGame(m *Message, c *Client) {
	player, _ := m.intParam("player")
	name, _ := m.stringParam("name")
	color, _ := m.stringParam("color")
	rejoined, err := r.game.Sit(c.user, player, name, color)

	switch {
	case err != nil:
		r.refuse(c, err)
	case rejoined:
		r.reply(c, statusResponse(r.game.Status()))
	default:
		r.broadcast(playerJoined(name, player, color))
	}
}

func (r *Room) onLeaveGame(m *Message, c *Client) {
	player, _ := m.intParam("player")

	if err := r.game.Stand(c.user, player); err != nil {
		r.refuse(c, err)
		return
	}

	r.broadcast(playerLeft(player))
}

func (r *Room) onSetReady(m *Message, c *Client) {
	player, _ := m.intParam("player")
	ready, ok := m.boolParam("ready")

	if !ok {
		r.reply(c, errorMessage(CodeBadMessage, "ready has to be true or false"))
		return
	}

	started, err := r.game.SetReady(c.user, player, ready)

	if err != nil {
		r.refuse(c, err)
		return
	}

	r.broadcast(readyChanged(player, ready))

	if started {
		r.broadcast(gameStarted(r.game.Status()))
	}
}

func (r *Room) onSubmitTurn(m *Message, c *Client) {
	player, _ := m.intParam("player")
	turn, _ := m.intParam("turn")
	move, _ := m.stringParam("move")
	g := r.game
	result, err := g.Play(c.user, player, turn, move)

	switch {
	case err != nil:
		r.refuse(c, err)
	case result.Over:
		r.broadcast(gameFinished(g.State(), result.Condition, turn, g.Status()))
	default:
		r.broadcast(turnPlayed(player, turn, move, g.Player(), g.Turn(), g.Status()))
	}
}

// The clock of the player whose turn it is ran out: the other one wins
func (r *Room) onTimeout() {
	if turn, over := r.game.Timeout(); over {
		r.broadcast(gameFinished(r.game.State(), cirya.Time, turn, r.game.Status()))
	}
}

// Tells the client why the game refused its request: an Error for seats and
// turns, an InvalidTurn for a move against the rules
func (r *Room) refuse(c *Client, err error) {
	var refused refusal

	if errors.As(err, &refused) {
		r.reply(c, errorMessage(refused.code, refused.text))
	} else {
		r.reply(c, invalidTurn(err))
	}
}
