package cirya_test

import (
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A turn of player 1 on a 5×5 board, unless the case says otherwise
type turnCase struct {
	name   string
	size   int
	board  cirya.BoardData
	player int
	turn   string
	// Stacks after a legal turn, by square. Nil when the turn is illegal
	want map[string][]string
}

func (c turnCase) run(t *testing.T) {
	size, player := c.size, c.player

	if size == 0 {
		size = 5
	}

	if player == 0 {
		player = 1
	}

	board := boardWith(size, c.board)
	err := board.Play(player, c.turn)

	if c.want == nil {
		assert.Error(t, err, "%s should be illegal", c.turn)
		assert.Equal(t, copyData(c.board), board.Data, "an illegal turn must not change the board")
		return
	}

	require.NoError(t, err, "%s should be legal", c.turn)

	for square, stones := range c.want {
		if len(stones) == 0 {
			assert.Empty(t, stackAt(board, square), square)
		} else {
			assert.Equal(t, stones, stackAt(board, square), square)
		}
	}
}

func TestPlacement(t *testing.T) {
	for _, c := range []turnCase{
		{name: "a flat cirya", turn: "a1", want: map[string][]string{"a1": {"C1"}}},
		{name: "a tampa", turn: "Td4", want: map[string][]string{"d4": {"T1"}}},
		{name: "a hallacirya", player: 2, turn: "He5", want: map[string][]string{"e5": {"H2"}}},
		{name: "the far corner of a big board", size: 9, turn: "i9", want: map[string][]string{"i9": {"C1"}}},

		{name: "an occupied square", board: cirya.BoardData{"1": {"a": {"C2"}}}, turn: "a1"},
		{name: "a hallacirya on an occupied square", board: cirya.BoardData{"1": {"a": {"C2"}}}, turn: "Ha1"},
		{name: "off the board", turn: "f1"},
		{name: "not a square", turn: "x1"},
		{name: "rank 0", turn: "a0"},
		{name: "not a turn", turn: "a1x"},
	} {
		t.Run(c.name, c.run)
	}
}

// Breaking a nossë: the reference the client follows
func TestMove(t *testing.T) {
	for _, c := range []turnCase{
		{
			name:  "one stone one square",
			board: cirya.BoardData{"1": {"a": {"C1"}}},
			turn:  "a1+",
			want:  map[string][]string{"a1": {}, "a2": {"C1"}},
		},
		{
			name:  "part of the nossë, the rest stays",
			board: cirya.BoardData{"1": {"a": {"C2", "C1", "C1"}}},
			turn:  "2a1>",
			want:  map[string][]string{"a1": {"C2"}, "b1": {"C1", "C1"}},
		},
		{
			name:  "the whole nossë",
			board: cirya.BoardData{"1": {"a": {"C2", "C1"}}},
			turn:  "2a1>11",
			want:  map[string][]string{"a1": {}, "b1": {"C2"}, "c1": {"C1"}},
		},
		{
			name:  "the bottom of the carry is dropped first",
			board: cirya.BoardData{"1": {"a": {"C1", "C2", "C1"}}},
			turn:  "3a1+21",
			want:  map[string][]string{"a1": {}, "a2": {"C1", "C2"}, "a3": {"C1"}},
		},
		{
			name:  "one stone on every square",
			board: cirya.BoardData{"3": {"e": {"C2", "C1", "C2", "C1"}}},
			turn:  "4e3<1111",
			want:  map[string][]string{"e3": {}, "d3": {"C2"}, "c3": {"C1"}, "b3": {"C2"}, "a3": {"C1"}},
		},
		{
			name: "over other stacks",
			board: cirya.BoardData{
				"5": {"c": {"C1", "C1"}},
				"4": {"c": {"C2"}},
				"3": {"c": {"C2", "C1"}},
			},
			turn: "2c5-11",
			want: map[string][]string{"c5": {}, "c4": {"C2", "C1"}, "c3": {"C2", "C1", "C1"}},
		},
		{
			name:  "the carry limit is the board size",
			board: cirya.BoardData{"1": {"a": {"C1", "C1", "C1", "C1", "C1"}}},
			turn:  "5a1+1112",
			want:  map[string][]string{"a1": {}, "a2": {"C1"}, "a5": {"C1", "C1"}},
		},
		{
			name:  "bigger boards carry more",
			size:  7,
			board: cirya.BoardData{"1": {"a": {"C1", "C1", "C1", "C1", "C1", "C1", "C1"}}},
			turn:  "7a1>7",
			want:  map[string][]string{"a1": {}, "b1": {"C1", "C1", "C1", "C1", "C1", "C1", "C1"}},
		},
		{
			name:  "a tampa goes over ciryar",
			board: cirya.BoardData{"1": {"a": {"T1"}, "b": {"C2"}}},
			turn:  "a1>",
			want:  map[string][]string{"a1": {}, "b1": {"C2", "T1"}},
		},
		{
			name:  "a lone hallacirya flattens a tampa",
			board: cirya.BoardData{"1": {"a": {"H1"}, "b": {"T2"}}},
			turn:  "a1>",
			want:  map[string][]string{"a1": {}, "b1": {"C2", "H1"}},
		},
		{
			name:  "the hallacirya arrives alone at the end of the carry",
			board: cirya.BoardData{"1": {"a": {"C1", "C1", "H1"}, "c": {"T2"}}},
			turn:  "3a1>21",
			want:  map[string][]string{"a1": {}, "b1": {"C1", "C1"}, "c1": {"C2", "H1"}},
		},
		{
			name:  "the stone after the drops is ignored",
			board: cirya.BoardData{"1": {"a": {"C1", "H1"}}},
			turn:  "2a1+11H",
			want:  map[string][]string{"a2": {"C1"}, "a3": {"H1"}},
		},

		{name: "the nossë of the opponent", board: cirya.BoardData{"1": {"a": {"C1", "C2"}}}, turn: "a1+"},
		{name: "an empty square", board: cirya.BoardData{"1": {"a": {"C1"}}}, turn: "b1+"},
		{name: "more stones than the nossë has", board: cirya.BoardData{"1": {"a": {"C1", "C1"}}}, turn: "3a1+111"},
		{name: "over the carry limit", board: cirya.BoardData{"1": {"a": {"C2", "C1", "C1", "C1", "C1", "C1"}}}, turn: "6a1+1113"},
		{name: "the drops leave stones behind", board: cirya.BoardData{"1": {"a": {"C1", "C1", "C1"}}}, turn: "3a1+11"},
		{name: "the drops are more than the carry", board: cirya.BoardData{"1": {"a": {"C1", "C1"}}}, turn: "2a1+12"},
		{name: "one stone and nine drops", board: cirya.BoardData{"1": {"a": {"C1"}}}, turn: "a1+9"},
		{name: "a square without stones", board: cirya.BoardData{"1": {"a": {"C1", "C1"}}}, turn: "2a1+101"},
		{name: "off the board on the way", board: cirya.BoardData{"1": {"d": {"C1", "C1"}}}, turn: "2d1>11"},
		{name: "off the board at once", board: cirya.BoardData{"1": {"a": {"C1"}}}, turn: "a1-"},
		{name: "off the far corner", size: 9, board: cirya.BoardData{"9": {"i": {"C1", "C1", "C1"}}}, turn: "3i9+111"},
		{name: "over a hallacirya", board: cirya.BoardData{"1": {"a": {"C1"}, "b": {"H2"}}}, turn: "a1>"},
		{name: "over an own hallacirya", board: cirya.BoardData{"1": {"a": {"C1"}, "b": {"H1"}}}, turn: "a1>"},
		{name: "a cirya over a tampa", board: cirya.BoardData{"1": {"a": {"C1"}, "b": {"T2"}}}, turn: "a1>"},
		{name: "a tampa over a tampa", board: cirya.BoardData{"1": {"a": {"T1"}, "b": {"T2"}}}, turn: "a1>"},
		{name: "a hallacirya with company over a tampa", board: cirya.BoardData{"1": {"a": {"C1", "H1"}, "b": {"T2"}}}, turn: "2a1>"},
		{name: "a tampa in the middle of the way", board: cirya.BoardData{"1": {"a": {"C1", "C1", "H1"}, "b": {"T2"}}}, turn: "3a1>12"},
		{name: "a hallacirya at the end of the way", board: cirya.BoardData{"1": {"a": {"C1", "C1"}, "c": {"H2"}}}, turn: "2a1>11"},
	} {
		t.Run(c.name, c.run)
	}
}

// The first turn of each player places a flat cirya of the opponent, from
// the fleet of the opponent
func TestOpening(t *testing.T) {
	board := cirya.NewBoard(5)

	assert.Error(t, board.PlayOpening(1, "Ta1"), "a tampa")
	assert.Error(t, board.PlayOpening(1, "Ha1"), "a hallacirya")
	assert.Error(t, board.PlayOpening(1, "a1>"), "a move")

	require.NoError(t, board.PlayOpening(1, "a1"))
	assert.Equal(t, []string{"C2"}, stackAt(board, "a1"))
	assert.Equal(t, 20, board.Fleets[2].Ciryar)
	assert.Equal(t, 21, board.Fleets[1].Ciryar)

	assert.Error(t, board.PlayOpening(2, "a1"), "an occupied square")
}

func TestFleetLimits(t *testing.T) {
	board := cirya.NewBoard(5)

	require.NoError(t, board.Play(1, "Ha1"))
	assert.Error(t, board.Play(1, "Hb1"), "only one hallacirya in 5×5")

	// 21 ciryar, tampar included: 20 on ranks 2 to 5, one of every three standing
	placed := 0
	for _, rank := range "2345" {
		for _, file := range "abcde" {
			turn := string(file) + string(rank)
			if placed%3 == 0 {
				turn = "T" + turn
			}
			require.NoError(t, board.Play(1, turn))
			placed++
		}
	}

	require.NoError(t, board.Play(1, "b1"))
	assert.Error(t, board.Play(1, "c1"), "no ciryar left")
	assert.True(t, board.FleetEmpty(1))
}

func TestOfficialFleets(t *testing.T) {
	assert.Equal(t, &cirya.Fleet{Ciryar: 21, Hallaciryar: 1}, cirya.NewFleet(5))
	assert.Equal(t, &cirya.Fleet{Ciryar: 30, Hallaciryar: 2}, cirya.NewFleet(6))
	assert.Equal(t, &cirya.Fleet{Ciryar: 40, Hallaciryar: 2}, cirya.NewFleet(7))
}
