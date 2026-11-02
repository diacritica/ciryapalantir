package app

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A started game, with the Henneth Annûn rule or without it
func hennethGame(t *testing.T, rule bool) *Game {
	g := NewGame()
	_, err := g.ChangeConfig("alice", nil, &rule)
	require.NoError(t, err)

	_, err = g.Sit("alice", 1, "Alice", "white")
	require.NoError(t, err)
	_, err = g.Sit("bob", 2, "Bob", "black")
	require.NoError(t, err)
	_, err = g.SetReady("alice", 1, true)
	require.NoError(t, err)
	_, err = g.SetReady("bob", 2, true)
	require.NoError(t, err)

	return g
}

// Turns that never end the game: after the openings each player moves its
// one cirya to the next square and back, white on the fifth rank and black on
// the first one
func shuffle(turn int) string {
	switch {
	case turn == 1:
		return "a1"
	case turn == 2:
		return "e5"
	case turn%2 == 1:
		return []string{"e5<", "d5>"}[(turn-3)/2%2]
	default:
		return []string{"a1>", "b1<"}[(turn-4)/2%2]
	}
}

// Plays the shuffle up to the given turn, not included
func shuffleUntil(t *testing.T, g *Game, turn int) {
	t.Helper()

	for g.Turn() < turn {
		user := map[int]ID{1: "alice", 2: "bob"}[g.Player()]
		play(t, g, user, g.Player(), shuffle(g.Turn()))
	}
}

func refusedHallacirya(t *testing.T, g *Game, square string) {
	t.Helper()

	user := map[int]ID{1: "alice", 2: "bob"}[g.Player()]
	_, err := g.Play(user, g.Player(), g.Turn(), "H"+square)
	assert.Error(t, err, "turn %d", g.Turn())
	assert.Len(t, g.Status().Moves, g.Turn()-1, "the refused turn is not played")
}

// Black can play its hallacirya in its 16th turn and white in its 17th, the
// 32nd and the 33rd of the game, and not before
func TestHennethAnnunTurns(t *testing.T) {
	g := hennethGame(t, true)
	shuffleUntil(t, g, 3)
	refusedHallacirya(t, g, "c3")
	shuffleUntil(t, g, 4)
	refusedHallacirya(t, g, "c3")
	shuffleUntil(t, g, 31)
	refusedHallacirya(t, g, "c3")
	play(t, g, "alice", 1, shuffle(31))

	assert.Equal(t, 32, g.Turn())
	assert.False(t, play(t, g, "bob", 2, "Hc3").Over, "the 16th turn of black")
	assert.False(t, play(t, g, "alice", 1, "Hc4").Over, "the 17th turn of white")
}

// Once its turn is gone, the hallacirya is never played
func TestHennethAnnunGoneForEver(t *testing.T) {
	g := hennethGame(t, true)
	shuffleUntil(t, g, 34)

	refusedHallacirya(t, g, "c3")
	play(t, g, "bob", 2, shuffle(34))
	refusedHallacirya(t, g, "c3")
	play(t, g, "alice", 1, shuffle(35))
	shuffleUntil(t, g, 51)
	refusedHallacirya(t, g, "c3")
}

// Without the rule the hallacirya is played whenever
func TestWithoutHennethAnnun(t *testing.T) {
	g := hennethGame(t, false)
	shuffleUntil(t, g, 3)

	play(t, g, "alice", 1, "Hc3")
	play(t, g, "bob", 2, "Hc4")
	assert.Equal(t, []string{"a1", "e5", "Hc3", "Hc4"}, g.Status().Moves)
}
