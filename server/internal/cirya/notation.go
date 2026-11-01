package cirya

import "regexp"

// Turns are written as in Tak:
//
//	c3, Tc3, Hc3   place a flat cirya, a tampa or a hallacirya on c3
//	3c3>21         take 3 stones from c3 and move them right, dropping 2 on d3 and 1 on e3
//
// Without a count one stone is taken, and without drops all of them go to the
// next square. Directions: + up a rank, - down a rank, > right a file, < left a file.
var (
	placementRe = regexp.MustCompile(`^([HT]?)([a-i][1-9])$`)
	moveRe      = regexp.MustCompile(`^([1-9]?)([a-i][1-9])([-+<>])([1-9]*)[HT]?$`)
)

var directions = map[byte]direction{'+': up, '-': down, '>': right, '<': left}

type placement struct {
	stone byte
	at    square
}

type move struct {
	from  square
	count int
	dir   direction
	drops []int
}

func parsePlacement(turn string) (placement, bool) {
	groups := placementRe.FindStringSubmatch(turn)

	if groups == nil {
		return placement{}, false
	}

	p := placement{stone: 'C', at: parseSquare(groups[2])}

	if groups[1] != "" {
		p.stone = groups[1][0]
	}

	return p, true
}

func parseMove(turn string) (move, bool) {
	groups := moveRe.FindStringSubmatch(turn)

	if groups == nil {
		return move{}, false
	}

	m := move{from: parseSquare(groups[2]), count: 1, dir: directions[groups[3][0]]}

	if groups[1] != "" {
		m.count = digit(groups[1][0])
	}

	if groups[4] == "" {
		m.drops = []int{m.count}
	}

	for i := 0; i < len(groups[4]); i++ {
		m.drops = append(m.drops, digit(groups[4][i]))
	}

	return m, true
}

func digit(c byte) int {
	return int(c - '0')
}
