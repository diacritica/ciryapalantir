package app

import (
	"testing"
	"time"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A game with five minutes each that white has just won by Londë
func finishedGame(t *testing.T) (*Game, *fakeTime) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")
	g.board.Data = cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}}}
	clock.pass(10 * time.Second)
	require.True(t, play(t, g, "alice", 1, "e3").Over)
	return g, clock
}

func TestRematchIsOffered(t *testing.T) {
	g, clock := finishedGame(t)

	rematch := g.Status().Rematch
	require.NotNil(t, rematch)
	assert.Equal(t, RematchOpen, rematch.State)
	assert.Empty(t, rematch.Accepted)
	assert.Equal(t, int64(30000), rematch.Left)

	clock.pass(12 * time.Second)
	assert.Equal(t, int64(18000), g.Status().Rematch.Left)
}

// Both accept: the players swap their seats and colours, and a new game
// starts from the beginning with the same configuration
func TestRematchSwapsTheSeats(t *testing.T) {
	g, _ := finishedGame(t)

	started, err := g.Rematch("alice", 1, true)
	require.NoError(t, err)
	assert.False(t, started, "waiting for the other one")
	assert.Equal(t, []int{1}, g.Status().Rematch.Accepted)

	started, err = g.Rematch("bob", 2, true)
	require.NoError(t, err)
	assert.True(t, started)

	status := g.Status()
	assert.Equal(t, "Bob", status.Players[1].Name)
	assert.Equal(t, "white", status.Players[1].Color)
	assert.Equal(t, "Alice", status.Players[2].Name)
	assert.Equal(t, "black", status.Players[2].Color)
	assert.Equal(t, Turn1, status.State)
	assert.Empty(t, status.Moves)
	assert.Empty(t, status.Board)
	assert.Equal(t, int64(300000), status.Clocks[1])
	assert.Nil(t, status.Rematch, "no offer during the game")

	// Alice has the seat of black now, and Bob plays first
	_, err = g.Play("alice", 2, 1, "c3")
	assertRefused(t, CodeNotYourTurn, err)
	play(t, g, "bob", 1, "c3")
}

// One no is enough, whatever the other one said
func TestOneNoIsEnough(t *testing.T) {
	g, _ := finishedGame(t)

	_, err := g.Rematch("alice", 1, true)
	require.NoError(t, err)
	_, err = g.Rematch("bob", 2, false)
	require.NoError(t, err)

	assert.Equal(t, RematchDeclined, g.Status().Rematch.State)
	_, err = g.Rematch("bob", 2, true)
	assertRefused(t, CodeNoRematch, err)
	_, err = g.Rematch("alice", 1, true)
	assertRefused(t, CodeNoRematch, err)
	assert.Equal(t, Win1, g.State(), "the game stays there")
}

func TestRematchExpires(t *testing.T) {
	g, clock := finishedGame(t)

	_, err := g.Rematch("alice", 1, true)
	require.NoError(t, err)

	clock.pass(29 * time.Second)
	assert.False(t, g.ExpireRematch())
	clock.pass(time.Second)
	assert.True(t, g.ExpireRematch())
	assert.Equal(t, RematchExpired, g.Status().Rematch.State)

	_, err = g.Rematch("bob", 2, true)
	assertRefused(t, CodeNoRematch, err)
}

// Only the players answer, and only once the game is over; a game lost on
// time offers it too
func TestWhoAnswersTheRematch(t *testing.T) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")

	_, err := g.Rematch("alice", 1, true)
	assertRefused(t, CodeNoRematch, err)

	play(t, g, "bob", 2, "c2")
	clock.pass(301 * time.Second)
	_, over := g.Timeout()
	require.True(t, over)
	assert.Equal(t, RematchOpen, g.Status().Rematch.State)

	_, err = g.Rematch("carol", 1, true)
	assertRefused(t, CodeNotYourSeat, err)
}

// The room closes the offer on its own when the time passes, and starts the
// new game when both accept
func TestTheRoomAndTheRematch(t *testing.T) {
	rematchTime = 50 * time.Millisecond
	defer func() { rematchTime = 30 * time.Second }()

	r, alice, bob := roomWithAGame(t)
	finish(t, r, alice, bob)
	r.Receive(alice, parse(t, Rematch, Params{"player": 1, "accept": true}))
	changed := expect(t, bob, RematchChanged)
	assert.Equal(t, "OPEN", changed["params"].(map[string]any)["state"])

	expired := expect(t, bob, RematchChanged)
	assert.Equal(t, "EXPIRED", expired["params"].(map[string]any)["state"])

	rematchTime = 10 * time.Second
	r, alice, bob = roomWithAGame(t)
	finish(t, r, alice, bob)
	r.Receive(alice, parse(t, Rematch, Params{"player": 1, "accept": true}))
	r.Receive(bob, parse(t, Rematch, Params{"player": 2, "accept": true}))
	started := expect(t, alice, StartGame)
	assert.Equal(t, true, started["params"].(map[string]any)["rematch"])
	players := started["status"].(map[string]any)["players"].(map[string]any)
	assert.Equal(t, "Bob", players["1"].(map[string]any)["name"])
}

func roomWithAGame(t *testing.T) (*Room, *Client, *Client) {
	r := NewRoom("rematch")
	alice, bob := NewClient("alice"), NewClient("bob")
	r.Join(alice)
	r.Join(bob)
	r.Receive(alice, parse(t, JoinGame, Params{"player": 1, "name": "Alice", "color": "white"}))
	r.Receive(bob, parse(t, JoinGame, Params{"player": 2, "name": "Bob", "color": "black"}))
	r.Receive(alice, parse(t, SetReady, Params{"player": 1, "ready": true}))
	r.Receive(bob, parse(t, SetReady, Params{"player": 2, "ready": true}))
	expect(t, alice, StartGame)
	expect(t, bob, StartGame)
	return r, alice, bob
}

// White makes a Londë along the first rank: black placed its first cirya
// on a1 in the opening
func finish(t *testing.T, r *Room, alice, bob *Client) {
	turns := []string{"e5", "a1", "b1", "a5", "c1", "b5", "d1", "c5", "e1"}

	for i, move := range turns {
		player, client := 1+i%2, alice
		if player == 2 {
			client = bob
		}
		r.Receive(client, parse(t, SubmitTurn, Params{"player": player, "turn": i + 1, "move": move}))
	}

	expect(t, bob, GameFinished)
}
