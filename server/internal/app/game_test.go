package app

import (
	"errors"
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A game where alice sits in seat 1 and bob in seat 2, both ready
func startedGame(t *testing.T) *Game {
	g := NewGame()

	_, err := g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.SetReady("alice", 1, true)
	require.NoError(t, err)
	started, err := g.SetReady("bob", 2, true)
	require.NoError(t, err)
	require.True(t, started)

	return g
}

func assertRefused(t *testing.T, code ErrorCode, err error) {
	t.Helper()

	var refused refusal
	if assert.True(t, errors.As(err, &refused), "expected a refusal, got %v", err) {
		assert.Equal(t, code, refused.code)
	}
}

func intRef(value int) *int    { return &value }
func boolRef(value bool) *bool { return &value }

func TestConfigDefaults(t *testing.T) {
	config := NewGame().Status().Config

	assert.Equal(t, 300, config.Clock, "five minutes each")
	assert.False(t, config.HennethAnnun)
}

// Anyone while nobody sits, then only the one sitting, then nobody
func TestWhoChangesTheConfig(t *testing.T) {
	g := NewGame()

	config, err := g.ChangeConfig("bob", ConfigChange{Clock: intRef(600)})
	require.NoError(t, err)
	assert.Equal(t, 600, config.Clock)

	_, err = g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.ChangeConfig("bob", ConfigChange{Clock: intRef(180)})
	assertRefused(t, CodeConfigLocked, err)

	config, err = g.ChangeConfig("alice", ConfigChange{HennethAnnun: boolRef(true)})
	require.NoError(t, err)
	assert.Equal(t, 600, config.Clock, "what is not sent stays")
	assert.True(t, config.HennethAnnun)

	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.ChangeConfig("alice", ConfigChange{Clock: intRef(0)})
	assertRefused(t, CodeConfigLocked, err)

	require.NoError(t, g.Stand("bob", 2))
	_, err = g.ChangeConfig("alice", ConfigChange{Clock: intRef(0)})
	assert.NoError(t, err, "alone again")
	assert.Equal(t, 0, g.Status().Config.Clock)
}

func TestConfigValues(t *testing.T) {
	g := NewGame()

	_, err := g.ChangeConfig("alice", ConfigChange{Clock: intRef(301)})
	assertRefused(t, CodeBadMessage, err)
	assert.Equal(t, 300, g.Status().Config.Clock, "a refused change leaves it as it was")

	for _, clock := range Clocks {
		_, err = g.ChangeConfig("alice", ConfigChange{Clock: intRef(clock)})
		assert.NoError(t, err, "%d seconds", clock)
	}

	g.config.Size = 6
	_, err = g.ChangeConfig("alice", ConfigChange{Clock: intRef(300), HennethAnnun: boolRef(true)})
	assertRefused(t, CodeBadMessage, err)
	assert.False(t, g.Status().Config.HennethAnnun, "Henneth Annûn is only for 5×5")
	assert.Equal(t, 900, g.Status().Config.Clock, "and nothing else of the change is taken")
}

func TestNoConfigChangesOnceStarted(t *testing.T) {
	g := startedGame(t)

	_, err := g.ChangeConfig("alice", ConfigChange{Clock: intRef(600)})
	assertRefused(t, CodeGameStarted, err)
}

func TestSeats(t *testing.T) {
	g := NewGame()

	_, err := g.Sit("alice", 3, "Alice", "white")
	assertRefused(t, CodeBadMessage, err)

	_, err = g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)

	_, err = g.Sit("bob", 1, "Bob", "black")
	assertRefused(t, CodeSeatTaken, err)

	assertRefused(t, CodeNotYourSeat, g.Stand("bob", 1))
	require.NoError(t, g.Stand("alice", 1))

	_, err = g.Sit("bob", 1, "Bob", "black")
	assert.NoError(t, err, "a free seat again")
}

func TestStartsWhenBothAreReady(t *testing.T) {
	g := NewGame()
	_, err := g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)

	_, err = g.SetReady("carol", 1, true)
	assertRefused(t, CodeNotYourSeat, err)

	started, err := g.SetReady("alice", 1, true)
	require.NoError(t, err)
	assert.False(t, started)
	assert.Equal(t, NotStarted, g.State())
	assert.Nil(t, g.Status().Board, "no board before the start")

	started, err = g.SetReady("bob", 2, true)
	require.NoError(t, err)
	assert.True(t, started)
	assert.Equal(t, Turn1, g.State())
	assert.Equal(t, 1, g.Player())
	assert.Equal(t, 1, g.Turn())
}

func TestNoSeatChangesOnceStarted(t *testing.T) {
	g := startedGame(t)

	_, err := g.Sit("carol", 1, "Carol", "white")
	assertRefused(t, CodeSeatTaken, err)

	assertRefused(t, CodeGameStarted, g.Stand("alice", 1))

	_, err = g.SetReady("alice", 1, false)
	assertRefused(t, CodeGameStarted, err)

	rejoined, err := g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	assert.True(t, rejoined, "the owner comes back to the seat")
}

func TestPlayRefusals(t *testing.T) {
	g := NewGame()
	_, err := g.Play("alice", 1, 1, "a1")
	assertRefused(t, CodeGameNotStarted, err)

	g = startedGame(t)
	_, err = g.Play("bob", 1, 1, "a1")
	assertRefused(t, CodeNotYourSeat, err)

	_, err = g.Play("bob", 2, 1, "a1")
	assertRefused(t, CodeNotYourTurn, err)

	_, err = g.Play("alice", 1, 2, "a1")
	assertRefused(t, CodeStaleTurn, err)

	_, err = g.Play("alice", 1, 1, "a1>")
	assert.Error(t, err)
	assert.False(t, errors.As(err, &refusal{}), "a move against the rules is not a refusal")
	assert.Equal(t, Turn1, g.State(), "and changes nothing")
	assert.Equal(t, 1, g.Turn())
}

func TestTurnsAlternate(t *testing.T) {
	g := startedGame(t)

	// The opening places a cirya of the opponent
	_, err := g.Play("alice", 1, 1, "a1")
	require.NoError(t, err)
	assert.Equal(t, []string{"C2"}, g.board.Data["1"]["a"])
	assert.Equal(t, Turn2, g.State())
	assert.Equal(t, 2, g.Player())
	assert.Equal(t, 2, g.Turn())

	_, err = g.Play("bob", 2, 2, "e5")
	require.NoError(t, err)
	assert.Equal(t, []string{"C1"}, g.board.Data["5"]["e"])

	_, err = g.Play("alice", 1, 3, "b1")
	require.NoError(t, err)
	assert.Equal(t, []string{"C1"}, g.board.Data["1"]["b"])
	assert.Equal(t, []string{"a1", "e5", "b1"}, g.Status().Moves)
}

func TestLondeFinishesTheGame(t *testing.T) {
	g := startedGame(t)
	g.turn = 3
	g.board.Data = cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}}}

	result, err := g.Play("alice", 1, 3, "e3")
	require.NoError(t, err)
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Londi}, result)
	assert.Equal(t, Win1, g.State())
	assert.True(t, g.Finished())
	assert.Equal(t, 3, g.Turn(), "the turn does not move on")
	assert.Equal(t, 0, *g.Status().Player, "nobody plays any more")

	_, err = g.Play("bob", 2, 4, "a1")
	assertRefused(t, CodeGameFinished, err)
}

func TestEqualFlatsAreADraw(t *testing.T) {
	g := startedGame(t)
	g.turn = 4
	g.state = Turn2
	g.board.Data = cirya.BoardData{"1": {"a": {"C1"}}}
	g.board.Fleets[2].Ciryar = 1
	g.board.Fleets[2].Hallaciryar = 0

	// Bob places his last cirya: one flat each
	result, err := g.Play("bob", 2, 4, "e5")
	require.NoError(t, err)
	assert.Equal(t, cirya.Result{Over: true, Winner: 0, Condition: cirya.Flat}, result)
	assert.Equal(t, Draw, g.State())
}

// The variant T4K is chosen like the rest, and the board of the game has no
// limit to its nossi
func TestTheVariantT4K(t *testing.T) {
	g := NewGame()
	assert.False(t, g.Status().Config.Tak, "the limit by default")

	config, err := g.ChangeConfig("alice", ConfigChange{Tak: boolRef(true)})
	require.NoError(t, err)
	assert.True(t, config.Tak)
	assert.Equal(t, DefaultClock, config.Clock, "the rest stays")

	_, err = g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.ChangeConfig("alice", ConfigChange{Tak: boolRef(false)})
	assertRefused(t, CodeConfigLocked, err)

	_, err = g.SetReady("alice", 1, true)
	require.NoError(t, err)
	_, err = g.SetReady("bob", 2, true)
	require.NoError(t, err)
	assert.True(t, g.board.Unlimited)
}
