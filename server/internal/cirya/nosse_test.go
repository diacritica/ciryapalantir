package cirya_test

import (
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
)

// Breaking a nossë: the reference the client has to follow (PLAN 2.3b).
// Stacks are written from the bottom to the top, and the carry is dropped
// starting by its bottom stones.
type nosseCase struct {
	name   string
	size   int
	board  cirya.BoardData
	player int
	move   string
	// Squares to check after a legal move, as "a1". Nil when the move is illegal
	want map[string][]string
}

func copyData(data cirya.BoardData) cirya.BoardData {
	res := make(cirya.BoardData)

	for rank, row := range data {
		res[rank] = make(map[string][]string)

		for file, stones := range row {
			res[rank][file] = append([]string{}, stones...)
		}
	}

	return res
}

func square(board *cirya.Board, position string) []string {
	return board.Data[string(position[1])][string(position[0])]
}

var nosseCases = []nosseCase{
	// Legal moves
	{
		name:   "one stone one square",
		board:  cirya.BoardData{"1": {"a": {"C1"}}},
		player: 1, move: "a1+",
		want: map[string][]string{"a1": {}, "a2": {"C1"}},
	},
	{
		name:   "part of the nossë, the rest stays",
		board:  cirya.BoardData{"1": {"a": {"C2", "C1", "C1"}}},
		player: 1, move: "2a1>",
		want: map[string][]string{"a1": {"C2"}, "b1": {"C1", "C1"}},
	},
	{
		name:   "the whole nossë can be carried",
		board:  cirya.BoardData{"1": {"a": {"C2", "C1"}}},
		player: 1, move: "2a1>11",
		want: map[string][]string{"a1": {}, "b1": {"C2"}, "c1": {"C1"}},
	},
	{
		name:   "drops in order, bottom of the carry first",
		board:  cirya.BoardData{"1": {"a": {"C1", "C2", "C1"}}},
		player: 1, move: "3a1+21",
		want: map[string][]string{"a1": {}, "a2": {"C1", "C2"}, "a3": {"C1"}},
	},
	{
		name:   "one stone per square along the way",
		board:  cirya.BoardData{"3": {"e": {"C2", "C1", "C2", "C1"}}},
		player: 1, move: "4e3<1111",
		want: map[string][]string{"e3": {}, "d3": {"C2"}, "c3": {"C1"}, "b3": {"C2"}, "a3": {"C1"}},
	},
	{
		name: "drops over other stacks",
		board: cirya.BoardData{
			"5": {"c": {"C1", "C1"}},
			"4": {"c": {"C2"}},
			"3": {"c": {"C2", "C1"}},
		},
		player: 1, move: "2c5-11",
		want: map[string][]string{"c5": {}, "c4": {"C2", "C1"}, "c3": {"C2", "C1", "C1"}},
	},
	{
		name:   "carry limit is the board size",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "C1", "C1", "C1"}}},
		player: 1, move: "5a1+1112",
		want: map[string][]string{"a1": {}, "a2": {"C1"}, "a5": {"C1", "C1"}},
	},
	{
		name:   "bigger boards carry more",
		size:   7,
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "C1", "C1", "C1", "C1", "C1"}}},
		player: 1, move: "7a1>7",
		want: map[string][]string{"a1": {}, "b1": {"C1", "C1", "C1", "C1", "C1", "C1", "C1"}},
	},
	{
		name:   "a tampa moves on top of ciryar",
		board:  cirya.BoardData{"1": {"a": {"T1"}, "b": {"C2"}}},
		player: 1, move: "a1>",
		want: map[string][]string{"a1": {}, "b1": {"C2", "T1"}},
	},
	{
		name:   "a lone hallacirya flattens a tampa",
		board:  cirya.BoardData{"1": {"a": {"H1"}, "b": {"T2"}}},
		player: 1, move: "a1>",
		want: map[string][]string{"a1": {}, "b1": {"C2", "H1"}},
	},
	{
		name:   "the hallacirya can arrive alone at the end of the carry",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "H1"}, "c": {"T2"}}},
		player: 1, move: "3a1>21",
		want: map[string][]string{"a1": {}, "b1": {"C1", "C1"}, "c1": {"C2", "H1"}},
	},

	// Illegal moves
	{
		name:   "the nossë belongs to the opponent",
		board:  cirya.BoardData{"1": {"a": {"C1", "C2"}}},
		player: 1, move: "a1+",
	},
	{
		name:   "an empty square",
		board:  cirya.BoardData{"1": {"a": {"C1"}}},
		player: 1, move: "b1+",
	},
	{
		name:   "more stones than the nossë has",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1"}}},
		player: 1, move: "3a1+111",
	},
	{
		name:   "over the carry limit",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "C1", "C1", "C1", "C1"}}},
		player: 1, move: "6a1+11112",
	},
	{
		name:   "drops leave stones behind",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "C1"}}},
		player: 1, move: "3a1+11",
	},
	{
		name:   "drops are more than the carry",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1"}}},
		player: 1, move: "2a1+12",
	},
	{
		name:   "a square without stones",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1"}}},
		player: 1, move: "2a1+101",
	},
	{
		name:   "out of the board",
		board:  cirya.BoardData{"1": {"d": {"C1", "C1"}}},
		player: 1, move: "2d1>11",
	},
	{
		name:   "out of the board at the first step",
		board:  cirya.BoardData{"1": {"a": {"C1"}}},
		player: 1, move: "a1-",
	},
	{
		name:   "over a hallacirya",
		board:  cirya.BoardData{"1": {"a": {"C1"}, "b": {"H2"}}},
		player: 1, move: "a1>",
	},
	{
		name:   "over an own hallacirya",
		board:  cirya.BoardData{"1": {"a": {"C1"}, "b": {"H1"}}},
		player: 1, move: "a1>",
	},
	{
		name:   "over a tampa with a cirya",
		board:  cirya.BoardData{"1": {"a": {"C1"}, "b": {"T2"}}},
		player: 1, move: "a1>",
	},
	{
		name:   "over a tampa with a tampa",
		board:  cirya.BoardData{"1": {"a": {"T1"}, "b": {"T2"}}},
		player: 1, move: "a1>",
	},
	{
		name:   "over a tampa with the hallacirya on top of other stones",
		board:  cirya.BoardData{"1": {"a": {"C1", "H1"}, "b": {"T2"}}},
		player: 1, move: "2a1>",
	},
	{
		name:   "a tampa in the middle of the way",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1", "H1"}, "b": {"T2"}}},
		player: 1, move: "3a1>12",
	},
	{
		name:   "a hallacirya at the end of the way",
		board:  cirya.BoardData{"1": {"a": {"C1", "C1"}, "c": {"H2"}}},
		player: 1, move: "2a1>11",
	},
}

func TestBreakingNosse(t *testing.T) {
	for _, c := range nosseCases {
		t.Run(c.name, func(t *testing.T) {
			size := c.size
			if size == 0 {
				size = 5
			}

			before := copyData(c.board)
			board := boardWith(size, copyData(c.board))
			err := safeMove(t, board, c.player, c.move)

			if c.want == nil {
				assert.NotNil(t, err, "%s should be illegal", c.move)
				assert.Equal(t, before, board.Data, "an illegal move must not change the board")
				return
			}

			if assert.Nil(t, err, "%s should be legal", c.move) {
				for position, stones := range c.want {
					if len(stones) == 0 {
						assert.Empty(t, square(board, position), position)
					} else {
						assert.Equal(t, stones, square(board, position), position)
					}
				}
			}
		})
	}
}
