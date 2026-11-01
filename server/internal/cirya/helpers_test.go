package cirya_test

import "cirya.me/server/internal/cirya"

// A board with full fleets and these stacks, written bottom stone first
func boardWith(size int, data cirya.BoardData) *cirya.Board {
	board := cirya.NewBoard(size)
	board.Data = copyData(data)
	return board
}

func copyData(data cirya.BoardData) cirya.BoardData {
	res := make(cirya.BoardData)

	for rank, files := range data {
		res[rank] = make(map[string][]string)

		for file, stones := range files {
			res[rank][file] = append([]string{}, stones...)
		}
	}

	return res
}

// The stack on a square written as "c3"
func stackAt(board *cirya.Board, square string) []string {
	return board.Data[square[1:]][square[:1]]
}
