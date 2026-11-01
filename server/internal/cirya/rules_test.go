package cirya_test

import (
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A 5x5 board with the stones placed as "C1@a1"
func boardOf(t *testing.T, stones ...string) *cirya.Board {
	board := cirya.NewBoard(5)

	for _, s := range stones {
		require.Len(t, s, 5, "stone %s", s)
		rank, file := string(s[4]), string(s[3])

		if board.Data[rank] == nil {
			board.Data[rank] = make(map[string][]string)
		}

		board.Data[rank][file] = append(board.Data[rank][file], s[:2])
	}

	return board
}

func TestLondeAcrossFiles(t *testing.T) {
	board := boardOf(t, "C1@a3", "C1@b3", "H1@c3", "C1@d3", "C1@e3")

	assert.True(t, board.Londe(1))
	assert.False(t, board.Londe(2))
}

func TestLondeAcrossRanks(t *testing.T) {
	board := boardOf(t, "C2@c1", "C2@c2", "C2@c3", "C2@c4", "C2@c5")

	assert.True(t, board.Londe(2))
	assert.False(t, board.Londe(1))
}

func TestLondeWithTurns(t *testing.T) {
	// a1 b1 b2 b3 c3 d3 d4 d5
	board := boardOf(t, "C1@a1", "C1@b1", "C1@b2", "C1@b3", "C1@c3", "C1@d3", "C1@d4", "C1@d5")

	assert.True(t, board.Londe(1))
}

func TestTampaBreaksLonde(t *testing.T) {
	board := boardOf(t, "C1@a3", "C1@b3", "T1@c3", "C1@d3", "C1@e3")

	assert.False(t, board.Londe(1))
}

func TestStackOnTopDecidesLonde(t *testing.T) {
	// c3 has a cirya of player 1 covered by one of player 2
	board := boardOf(t, "C1@a3", "C1@b3", "C1@c3", "C2@c3", "C1@d3", "C1@e3")

	assert.False(t, board.Londe(1))

	// and the other way round
	board = boardOf(t, "C1@a3", "C1@b3", "C2@c3", "C1@c3", "C1@d3", "C1@e3")

	assert.True(t, board.Londe(1))
}

func TestDiagonalIsNotLonde(t *testing.T) {
	board := boardOf(t, "C1@a1", "C1@b2", "C1@c3", "C1@d4", "C1@e5")

	assert.False(t, board.Londe(1))
}

// A move that completes both londi is won by the player who moved
func TestSimultaneousLondeWinsMover(t *testing.T) {
	board := boardOf(t,
		"C1@a1", "C1@b1", "C1@c1", "C1@d1", "C1@e1",
		"C2@a5", "C2@b5", "C2@c5", "C2@d5", "C2@e5",
	)

	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Londi}, board.Result(2))
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Londi}, board.Result(1))
}

// A move that only completes the londë of the opponent makes the opponent win
func TestLondeOfOpponentWins(t *testing.T) {
	board := boardOf(t, "C1@a1", "C1@b1", "C1@c1", "C1@d1", "C1@e1")

	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Londi}, board.Result(2))
}

func TestGameGoesOnWithoutLonde(t *testing.T) {
	board := boardOf(t, "C1@a1", "C1@b1", "C2@c1")

	assert.Equal(t, cirya.Result{Over: false, Condition: cirya.NoWin}, board.Result(1))
}

// Full board: only flat ciryar on top count
func TestFullBoardCountsFlats(t *testing.T) {
	board := cirya.NewBoard(5)
	files := "abcde"

	// A checkerboard, so nobody has a londë. a1 belongs to player 2
	for f := 0; f < 5; f++ {
		for r := 1; r <= 5; r++ {
			rank := string(rune('0' + r))
			if board.Data[rank] == nil {
				board.Data[rank] = make(map[string][]string)
			}

			owner := "1"
			if (r+f)%2 == 1 {
				owner = "2"
			}

			board.Data[rank][string(files[f])] = []string{"C" + owner}
		}
	}

	// 13 squares of player 2 and 12 of player 1. A tampa and a hallacirya of player 2 do not count
	assert.Equal(t, 13, board.FlatCount(2))
	assert.Equal(t, 12, board.FlatCount(1))
	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Flat}, board.Result(1))

	board.Data["1"]["a"] = []string{"T2"}
	board.Data["3"]["c"] = []string{"H2"}

	assert.Equal(t, 11, board.FlatCount(2))
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Flat}, board.Result(1))

	// Same flats: draw
	board.Data["5"]["e"] = []string{"T2"}
	board.Data["2"]["a"] = []string{"T1"}
	board.Data["1"]["b"] = []string{"T1"}
	assert.Equal(t, cirya.Result{Over: true, Winner: 0, Condition: cirya.Flat}, board.Result(1))
}

// The game ends when a player has placed the whole fleet
func TestEmptyFleetEndsGame(t *testing.T) {
	board := boardOf(t, "C1@a1", "C2@b2", "C2@c2")
	board.Fleets[2].Ciryar = 0
	board.Fleets[2].Hallaciryar = 0

	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Flat}, board.Result(1))
}

func TestFleetLimits(t *testing.T) {
	board := cirya.NewBoard(5)
	squares := 0

	place := func(move string) error {
		return board.Play(1, move)
	}

	assert.Nil(t, place("Ha1"))
	assert.NotNil(t, place("Hb1"), "only one hallacirya in 5x5")

	// 21 ciryar, tampar included
	for _, rank := range "2345" {
		for _, file := range "abcde" {
			if squares == 20 {
				break
			}
			stone := ""
			if squares%3 == 0 {
				stone = "T"
			}
			assert.Nil(t, place(stone+string(file)+string(rank)))
			squares++
		}
	}

	assert.Nil(t, place("b1"))
	assert.NotNil(t, place("c1"), "no ciryar left")
	assert.True(t, board.FleetEmpty(1))
}

func TestOfficialFleets(t *testing.T) {
	assert.Equal(t, &cirya.Fleet{Ciryar: 21, Hallaciryar: 1}, cirya.NewFleet(5))
	assert.Equal(t, &cirya.Fleet{Ciryar: 30, Hallaciryar: 2}, cirya.NewFleet(6))
	assert.Equal(t, &cirya.Fleet{Ciryar: 40, Hallaciryar: 2}, cirya.NewFleet(7))
}

// The first move places a flat cirya of the opponent, from the opponent's fleet
func TestOpening(t *testing.T) {
	board := cirya.NewBoard(5)

	assert.NotNil(t, board.PlayOpening(1, "Ta1"))
	assert.NotNil(t, board.PlayOpening(1, "Ha1"))
	assert.NotNil(t, board.PlayOpening(1, "a1>"))

	assert.Nil(t, board.PlayOpening(1, "a1"))
	assert.Equal(t, []string{"C2"}, board.Data["1"]["a"])
	assert.Equal(t, 20, board.Fleets[2].Ciryar)
	assert.Equal(t, 21, board.Fleets[1].Ciryar)

	assert.NotNil(t, board.PlayOpening(2, "a1"), "occupied")
}
