// Package cirya holds the rules of Cirya: the board, the turns in Tak
// notation and how a game ends.
package cirya

import (
	"fmt"
	"strings"
)

// BoardData holds the stacks by rank and file, bottom stone first: data["3"]["c"]
// is the stack on c3. A stone is its kind and its owner: "C1" is a flat cirya
// of player 1, "T2" a tampa of player 2 and "H1" a hallacirya of player 1.
// It is also how the board travels in the protocol.
type BoardData map[string]map[string][]string

// Board is a board of Size × Size squares and the pieces each player has not placed yet
type Board struct {
	Data   BoardData
	Size   int
	Fleets map[int]*Fleet
}

func NewBoard(size int) *Board {
	return &Board{
		Data:   make(BoardData),
		Size:   size,
		Fleets: map[int]*Fleet{1: NewFleet(size), 2: NewFleet(size)},
	}
}

func Opponent(player int) int {
	return 3 - player
}

func (b *Board) stack(s square) []string {
	rank, file := s.keys()
	return b.Data[rank][file]
}

func (b *Board) setStack(s square, stones []string) {
	rank, file := s.keys()

	if b.Data[rank] == nil {
		b.Data[rank] = make(map[string][]string)
	}

	b.Data[rank][file] = stones
}

func (b *Board) squares() []square {
	all := make([]square, 0, b.Size*b.Size)

	for rank := 0; rank < b.Size; rank++ {
		for file := 0; file < b.Size; file++ {
			all = append(all, square{file, rank})
		}
	}

	return all
}

func top(stack []string) string {
	if len(stack) == 0 {
		return ""
	}

	return stack[len(stack)-1]
}

// 'C', 'T' or 'H', and 0 for no stone
func kind(stone string) byte {
	if stone == "" {
		return 0
	}

	return stone[0]
}

// 1 or 2, and 0 for no stone
func owner(stone string) int {
	if stone == "" {
		return 0
	}

	return digit(stone[1])
}

// String draws the board as text, rank 1 at the bottom, with the height of the stacks
func (b *Board) String() string {
	var sb strings.Builder

	sb.WriteString("  ")
	for file := 0; file < b.Size; file++ {
		fmt.Fprintf(&sb, "%7c", fileNames[file])
	}

	for rank := b.Size - 1; rank >= 0; rank-- {
		fmt.Fprintf(&sb, "\n%c ", rankNames[rank])

		for file := 0; file < b.Size; file++ {
			stack := b.stack(square{file, rank})

			switch len(stack) {
			case 0:
				sb.WriteString("      _")
			case 1:
				fmt.Fprintf(&sb, "%7s", stack[0])
			default:
				fmt.Fprintf(&sb, "%7s", fmt.Sprintf("[%d]%s", len(stack)-1, top(stack)))
			}
		}
	}

	return sb.String()
}
