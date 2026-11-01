package cirya

import (
	"strconv"
	"strings"
)

type WinCondition string

const (
	NONE  WinCondition = "NONE"
	LONDI WinCondition = "LONDI"
	FLAT  WinCondition = "FLAT"
)

type Result struct {
	Over bool
	// 1 or 2, 0 when the game ends in a draw
	Winner    int
	Condition WinCondition
}

func (b *Board) top(rank string, file string) string {
	stones := b.get(rank, file)

	if len(stones) == 0 {
		return ""
	}

	return stones[len(stones)-1]
}

// Ciryar and hallaciryar on top are part of a londë, tampar are not
func (b *Board) inLonde(player int, rank string, file string) bool {
	top := b.top(rank, file)
	owner := strconv.Itoa(player)

	return (strings.HasPrefix(top, "C") || strings.HasPrefix(top, "H")) && strings.HasSuffix(top, owner)
}

// A londë joins two opposite sides of the board with orthogonally
// adjacent squares controlled by the player
func (b *Board) Londe(player int) bool {
	size := b.Size

	// From the first rank to the last one
	if b.connects(player, func(r, f int) bool { return r == 0 }, func(r, f int) bool { return r == size-1 }) {
		return true
	}

	// From the first file to the last one
	return b.connects(player, func(r, f int) bool { return f == 0 }, func(r, f int) bool { return f == size-1 })
}

func (b *Board) connects(player int, start func(r, f int) bool, end func(r, f int) bool) bool {
	type square struct{ r, f int }

	size := b.Size
	visited := make(map[square]bool)
	pending := make([]square, 0)

	for r := 0; r < size; r++ {
		for f := 0; f < size; f++ {
			if start(r, f) && b.inLonde(player, ranks[r], files[f]) {
				pending = append(pending, square{r, f})
				visited[square{r, f}] = true
			}
		}
	}

	for len(pending) > 0 {
		current := pending[0]
		pending = pending[1:]

		if end(current.r, current.f) {
			return true
		}

		for _, d := range []square{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
			next := square{current.r + d.r, current.f + d.f}

			if next.r < 0 || next.r >= size || next.f < 0 || next.f >= size || visited[next] {
				continue
			}

			if b.inLonde(player, ranks[next.r], files[next.f]) {
				visited[next] = true
				pending = append(pending, next)
			}
		}
	}

	return false
}

func (b *Board) Full() bool {
	for _, rank := range ranks[:b.Size] {
		for _, file := range files[:b.Size] {
			if b.empty(rank, file) {
				return false
			}
		}
	}

	return true
}

// Squares with a flat cirya of the player on top
func (b *Board) FlatCount(player int) int {
	count := 0
	flat := "C" + strconv.Itoa(player)

	for _, rank := range ranks[:b.Size] {
		for _, file := range files[:b.Size] {
			if b.top(rank, file) == flat {
				count++
			}
		}
	}

	return count
}

// Checks the board after a move of the given player
func (b *Board) Result(mover int) Result {
	// If the move completes both londi, the player who moved wins
	if b.Londe(mover) {
		return Result{Over: true, Winner: mover, Condition: LONDI}
	}

	if b.Londe(Opponent(mover)) {
		return Result{Over: true, Winner: Opponent(mover), Condition: LONDI}
	}

	if b.Full() || b.FleetEmpty(1) || b.FleetEmpty(2) {
		flats1, flats2 := b.FlatCount(1), b.FlatCount(2)
		result := Result{Over: true, Condition: FLAT}

		if flats1 > flats2 {
			result.Winner = 1
		} else if flats2 > flats1 {
			result.Winner = 2
		}

		return result
	}

	return Result{Over: false, Condition: NONE}
}
