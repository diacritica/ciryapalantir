package app

import (
	"testing"
	"time"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A started game with five minutes each and a clock the test moves on
type fakeTime struct{ now time.Time }

func (f *fakeTime) pass(d time.Duration) { f.now = f.now.Add(d) }

func clockGame(t *testing.T) (*Game, *fakeTime) {
	clock := &fakeTime{now: time.Date(2026, 12, 1, 18, 0, 0, 0, time.UTC)}
	g := NewGame()
	g.now = func() time.Time { return clock.now }

	_, err := g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.SetReady("alice", 1, true)
	require.NoError(t, err)
	_, err = g.SetReady("bob", 2, true)
	require.NoError(t, err)

	return g, clock
}

func play(t *testing.T, g *Game, user ID, player int, move string) cirya.Result {
	t.Helper()
	result, err := g.Play(user, player, g.Turn(), move)
	require.NoError(t, err)
	return result
}

func clocksOf(g *Game) (int64, int64, int) {
	status := g.Status()
	return status.Clocks[1], status.Clocks[2], *status.ClockRunning
}

// The openings are free: the clock of white starts once black has placed its cirya
func TestClocksStartAfterTheOpenings(t *testing.T) {
	g, clock := clockGame(t)

	white, black, running := clocksOf(g)
	assert.Equal(t, []int64{300000, 300000}, []int64{white, black})
	assert.Equal(t, 0, running, "no clock runs before the openings")

	clock.pass(20 * time.Second)
	play(t, g, "alice", 1, "c3")
	clock.pass(30 * time.Second)
	play(t, g, "bob", 2, "c2")

	white, black, running = clocksOf(g)
	assert.Equal(t, []int64{300000, 300000}, []int64{white, black}, "the openings took no time")
	assert.Equal(t, 1, running)

	clock.pass(7 * time.Second)
	white, _, _ = clocksOf(g)
	assert.Equal(t, int64(293000), white, "the clock of white runs")

	play(t, g, "alice", 1, "a1")
	clock.pass(4 * time.Second)

	white, black, running = clocksOf(g)
	assert.Equal(t, []int64{293000, 296000}, []int64{white, black}, "white stopped and black runs")
	assert.Equal(t, 2, running)
}

// A move the rules refuse does not stop the clock
func TestRefusedMoveDoesNotStopTheClock(t *testing.T) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")

	clock.pass(10 * time.Second)
	_, err := g.Play("alice", 1, 3, "c3")
	require.Error(t, err)
	clock.pass(5 * time.Second)

	white, _, running := clocksOf(g)
	assert.Equal(t, int64(285000), white)
	assert.Equal(t, 1, running)
}

// The player whose clock reaches 0 loses, however the board is
func TestTheClockRunsOut(t *testing.T) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")
	play(t, g, "alice", 1, "a1")

	left, running := g.TimeLeft()
	assert.True(t, running)
	assert.Equal(t, 300*time.Second, left)

	clock.pass(299 * time.Second)
	_, over := g.Timeout()
	assert.False(t, over, "a second is left")

	clock.pass(time.Second)
	turn, over := g.Timeout()
	assert.True(t, over)
	assert.Equal(t, 4, turn, "the turn black did not play")
	assert.Equal(t, Win1, g.State())

	_, black, running2 := clocksOf(g)
	assert.Equal(t, int64(0), black)
	assert.Equal(t, 0, running2, "no clock runs once the game is over")
	_, running = g.TimeLeft()
	assert.False(t, running)

	_, err := g.Play("bob", 2, 4, "b1")
	assertRefused(t, CodeGameFinished, err)
}

// A move that comes after the time is over loses instead of counting
func TestLateMoveLoses(t *testing.T) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")

	clock.pass(301 * time.Second)
	result := play(t, g, "alice", 1, "a1")

	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Time}, result)
	assert.Equal(t, Win2, g.State())
	assert.Equal(t, []string{"c3", "c2"}, g.Status().Moves, "the late move is not played")
}

// A game that ends on the board stops the clocks
func TestTheBoardEndsTheClocks(t *testing.T) {
	g, clock := clockGame(t)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")
	g.board.Data = cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}}}

	clock.pass(3 * time.Second)
	assert.Equal(t, cirya.Londi, play(t, g, "alice", 1, "e3").Condition)

	white, _, running := clocksOf(g)
	assert.Equal(t, int64(297000), white)
	assert.Equal(t, 0, running)
}

func TestNoClock(t *testing.T) {
	g := NewGame()
	zero := 0
	_, err := g.ChangeConfig("alice", &zero, nil)
	require.NoError(t, err)

	_, err = g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.SetReady("alice", 1, true)
	require.NoError(t, err)
	_, err = g.SetReady("bob", 2, true)
	require.NoError(t, err)
	play(t, g, "alice", 1, "c3")
	play(t, g, "bob", 2, "c2")

	assert.Nil(t, g.Status().Clocks)
	assert.Nil(t, g.Status().ClockRunning)
	_, running := g.TimeLeft()
	assert.False(t, running)
}

// The room ends the game on its own when the clock runs out, with seconds
// made milliseconds so the test does not wait
func TestTheRoomEndsTheGameOnTime(t *testing.T) {
	clockUnit = time.Millisecond
	defer func() { clockUnit = time.Second }()

	r := NewRoom("clock")
	alice, bob := NewClient("alice"), NewClient("bob")
	r.Join(alice)
	r.Join(bob)

	r.Receive(alice, parse(t, ChangeConfig, Params{"clock": 180}))
	expect(t, bob, ConfigChanged)
	r.Receive(alice, parse(t, JoinGame, Params{"player": 1, "name": "Alice", "color": "white"}))
	r.Receive(bob, parse(t, JoinGame, Params{"player": 2, "name": "Bob", "color": "black"}))
	r.Receive(alice, parse(t, SetReady, Params{"player": 1, "ready": true}))
	r.Receive(bob, parse(t, SetReady, Params{"player": 2, "ready": true}))
	expect(t, alice, StartGame)
	r.Receive(alice, parse(t, SubmitTurn, Params{"player": 1, "turn": 1, "move": "c3"}))
	r.Receive(bob, parse(t, SubmitTurn, Params{"player": 2, "turn": 2, "move": "c2"}))

	finished := expect(t, bob, GameFinished)
	params := finished["params"].(map[string]any)
	assert.Equal(t, "WIN_2", params["result"], "white did not play in time")
	assert.Equal(t, "TIME", params["winCondition"])
	assert.Equal(t, float64(3), params["turn"])
	clocks := finished["status"].(map[string]any)["clocks"].(map[string]any)
	assert.Equal(t, float64(0), clocks["1"])
	assert.Equal(t, float64(180), clocks["2"])
}
