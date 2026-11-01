package cirya

type WinCondition string

const (
	NoWin WinCondition = "NONE"
	Londi WinCondition = "LONDI"
	Flat  WinCondition = "FLAT"
)

// Result tells if a game is over, who won and how
type Result struct {
	Over bool
	// 1 or 2, and 0 when the game ends in a draw
	Winner    int
	Condition WinCondition
}

// Result checks the board after a turn of the given player
func (b *Board) Result(mover int) Result {
	// A turn that completes both londi is won by the player who made it
	if b.Londe(mover) {
		return Result{Over: true, Winner: mover, Condition: Londi}
	}

	if b.Londe(Opponent(mover)) {
		return Result{Over: true, Winner: Opponent(mover), Condition: Londi}
	}

	if b.Full() || b.FleetEmpty(1) || b.FleetEmpty(2) {
		result := Result{Over: true, Condition: Flat}

		switch flats1, flats2 := b.FlatCount(1), b.FlatCount(2); {
		case flats1 > flats2:
			result.Winner = 1
		case flats2 > flats1:
			result.Winner = 2
		}

		return result
	}

	return Result{Condition: NoWin}
}

// Londe tells if the player joins two opposite sides of the board with
// orthogonally adjacent squares, each with a cirya or a hallacirya of the
// player on top. Tampar do not count
func (b *Board) Londe(player int) bool {
	last := b.Size - 1

	return b.connects(player, func(s square) bool { return s.rank == 0 }, func(s square) bool { return s.rank == last }) ||
		b.connects(player, func(s square) bool { return s.file == 0 }, func(s square) bool { return s.file == last })
}

func (b *Board) inLonde(player int, s square) bool {
	head := top(b.stack(s))
	return (kind(head) == 'C' || kind(head) == 'H') && owner(head) == player
}

// A breadth-first search from the squares on one side to the other one
func (b *Board) connects(player int, start, end func(square) bool) bool {
	visited := make(map[square]bool)
	pending := make([]square, 0)

	for _, s := range b.squares() {
		if start(s) && b.inLonde(player, s) {
			visited[s] = true
			pending = append(pending, s)
		}
	}

	for len(pending) > 0 {
		current := pending[0]
		pending = pending[1:]

		if end(current) {
			return true
		}

		for _, d := range []direction{up, right, down, left} {
			next := current.step(d)

			if next.on(b.Size) && !visited[next] && b.inLonde(player, next) {
				visited[next] = true
				pending = append(pending, next)
			}
		}
	}

	return false
}

// Full tells if every square has a stack
func (b *Board) Full() bool {
	for _, s := range b.squares() {
		if len(b.stack(s)) == 0 {
			return false
		}
	}

	return true
}

// FlatCount counts the squares with a flat cirya of the player on top
func (b *Board) FlatCount(player int) int {
	count := 0

	for _, s := range b.squares() {
		head := top(b.stack(s))

		if kind(head) == 'C' && owner(head) == player {
			count++
		}
	}

	return count
}
