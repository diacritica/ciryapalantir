package app

import (
	"slices"
	"time"
)

// When a game ends each player is offered a new one, with the colours swapped.
// It starts when both accept within RematchTime. It is over for both as soon
// as one does not want it, or when the time passes, and then nobody leaves the
// room: the game stays there to look at. Every game that ends offers it again

type RematchState string

const (
	RematchOpen     RematchState = "OPEN"
	RematchDeclined RematchState = "DECLINED"
	RematchExpired  RematchState = "EXPIRED"
)

// Seconds to accept a rematch; the tests make them shorter, like the clock
var rematchTime = 30 * time.Second

type rematchOffer struct {
	// Empty while the game is not over
	state    RematchState
	until    time.Time
	accepted map[int]bool
}

// RematchStatus is the offer as the clients see it, in the status
type RematchStatus struct {
	State    RematchState `json:"state"`
	Accepted []int        `json:"accepted"`
	// Milliseconds to accept, while it is open
	Left int64 `json:"left"`
}

func (g *Game) offerRematch() {
	g.rematch = rematchOffer{state: RematchOpen, until: g.now().Add(rematchTime), accepted: make(map[int]bool)}
}

func (g *Game) rematchStatus() RematchStatus {
	status := RematchStatus{State: g.rematch.state, Accepted: make([]int, 0)}

	for player := range g.rematch.accepted {
		status.Accepted = append(status.Accepted, player)
	}

	slices.Sort(status.Accepted)

	if g.rematch.state == RematchOpen {
		status.Left = max(g.rematch.until.Sub(g.now()), 0).Milliseconds()
	}

	return status
}

// Rematch is the answer of a player to the offer. When it is the second yes
// the players swap their seats, so white plays black, and the new game starts
func (g *Game) Rematch(user ID, player int, accept bool) (started bool, err error) {
	if err := g.checkOwner(user, player); err != nil {
		return false, err
	}

	g.ExpireRematch()

	if g.rematch.state != RematchOpen {
		return false, refusal{CodeNoRematch, "there is no rematch to answer"}
	}

	if !accept {
		g.rematch.state = RematchDeclined
		return false, nil
	}

	g.rematch.accepted[player] = true

	if !g.rematch.accepted[1] || !g.rematch.accepted[2] {
		return false, nil
	}

	white, black := g.seats[1], g.seats[2]
	white.Color, black.Color = black.Color, white.Color
	g.seats[1], g.seats[2] = black, white
	g.start()
	return true, nil
}

// RematchLeft tells how long the offer stays open
func (g *Game) RematchLeft() (time.Duration, bool) {
	if g.rematch.state != RematchOpen {
		return 0, false
	}

	return max(g.rematch.until.Sub(g.now()), 0), true
}

// ExpireRematch closes the offer once its time has passed, and tells whether
// it did now
func (g *Game) ExpireRematch() bool {
	if g.rematch.state != RematchOpen || g.now().Before(g.rematch.until) {
		return false
	}

	g.rematch.state = RematchExpired
	return true
}
