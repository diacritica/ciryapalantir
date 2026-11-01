package cirya_test

import (
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
)

func TestLonde(t *testing.T) {
	for _, c := range []struct {
		name   string
		board  cirya.BoardData
		player int
		want   bool
	}{
		{
			name:   "across the files",
			board:  cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"H1"}, "d": {"C1"}, "e": {"C1"}}},
			player: 1, want: true,
		},
		{
			name:   "not for the other player",
			board:  cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"H1"}, "d": {"C1"}, "e": {"C1"}}},
			player: 2, want: false,
		},
		{
			name: "across the ranks",
			board: cirya.BoardData{
				"1": {"c": {"C2"}}, "2": {"c": {"C2"}}, "3": {"c": {"C2"}}, "4": {"c": {"C2"}}, "5": {"c": {"C2"}},
			},
			player: 2, want: true,
		},
		{
			name: "with turns",
			board: cirya.BoardData{
				"1": {"a": {"C1"}, "b": {"C1"}},
				"2": {"b": {"C1"}},
				"3": {"b": {"C1"}, "c": {"C1"}, "d": {"C1"}},
				"4": {"d": {"C1"}},
				"5": {"d": {"C1"}},
			},
			player: 1, want: true,
		},
		{
			name:   "a tampa breaks it",
			board:  cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"T1"}, "d": {"C1"}, "e": {"C1"}}},
			player: 1, want: false,
		},
		{
			name:   "covered by the opponent",
			board:  cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"C1", "C2"}, "d": {"C1"}, "e": {"C1"}}},
			player: 1, want: false,
		},
		{
			name:   "the top stone decides",
			board:  cirya.BoardData{"3": {"a": {"C1"}, "b": {"C1"}, "c": {"C2", "C1"}, "d": {"C1"}, "e": {"C1"}}},
			player: 1, want: true,
		},
		{
			name: "a diagonal is not a londë",
			board: cirya.BoardData{
				"1": {"a": {"C1"}}, "2": {"b": {"C1"}}, "3": {"c": {"C1"}}, "4": {"d": {"C1"}}, "5": {"e": {"C1"}},
			},
			player: 1, want: false,
		},
	} {
		t.Run(c.name, func(t *testing.T) {
			assert.Equal(t, c.want, boardWith(5, c.board).Londe(c.player))
		})
	}
}

func TestResult(t *testing.T) {
	bothLondi := boardWith(5, cirya.BoardData{
		"1": {"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}, "e": {"C1"}},
		"5": {"a": {"C2"}, "b": {"C2"}, "c": {"C2"}, "d": {"C2"}, "e": {"C2"}},
	})
	londe1 := boardWith(5, cirya.BoardData{"1": {"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}, "e": {"C1"}}})
	open := boardWith(5, cirya.BoardData{"1": {"a": {"C1"}, "b": {"C1"}, "c": {"C2"}}})

	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Londi}, bothLondi.Result(2), "both londi: the mover wins")
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Londi}, bothLondi.Result(1), "both londi: the mover wins")
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Londi}, londe1.Result(2), "the londë of the opponent")
	assert.Equal(t, cirya.Result{Condition: cirya.NoWin}, open.Result(1), "the game goes on")
}

// A full board without londë: only flat ciryar on top count
func TestFullBoardCountsFlats(t *testing.T) {
	// A checkerboard where a1 belongs to player 2: 13 squares for player 2 and 12 for player 1
	data := cirya.BoardData{}
	for r, rank := range "12345" {
		data[string(rank)] = map[string][]string{}
		for f, file := range "abcde" {
			owner := "1"
			if (r+f)%2 == 0 {
				owner = "2"
			}
			data[string(rank)][string(file)] = []string{"C" + owner}
		}
	}
	board := boardWith(5, data)

	assert.Equal(t, 13, board.FlatCount(2))
	assert.Equal(t, 12, board.FlatCount(1))
	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Flat}, board.Result(1))

	// A tampa and a hallacirya do not count
	board.Data["1"]["a"] = []string{"T2"}
	board.Data["3"]["c"] = []string{"H2"}
	assert.Equal(t, 11, board.FlatCount(2))
	assert.Equal(t, cirya.Result{Over: true, Winner: 1, Condition: cirya.Flat}, board.Result(1))

	// The same flats: a draw
	board.Data["5"]["e"] = []string{"T2"}
	board.Data["2"]["a"] = []string{"T1"}
	board.Data["1"]["b"] = []string{"T1"}
	assert.Equal(t, cirya.Result{Over: true, Winner: 0, Condition: cirya.Flat}, board.Result(1))
}

// The game ends when a player has placed the whole fleet
func TestEmptyFleetEndsGame(t *testing.T) {
	board := boardWith(5, cirya.BoardData{"1": {"a": {"C1"}}, "2": {"b": {"C2"}, "c": {"C2"}}})
	board.Fleets[2].Ciryar = 0
	board.Fleets[2].Hallaciryar = 0

	assert.Equal(t, cirya.Result{Over: true, Winner: 2, Condition: cirya.Flat}, board.Result(1))
}
