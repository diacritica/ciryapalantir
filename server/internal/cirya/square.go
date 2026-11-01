package cirya

import "strings"

const (
	fileNames = "abcdefghi"
	rankNames = "123456789"
)

// A square of the board counted from 0: file 0 is "a" and rank 0 is "1"
type square struct {
	file, rank int
}

// Reads a square as the notation writes it, like "c3". The caller has
// already checked the format
func parseSquare(name string) square {
	return square{
		file: strings.IndexByte(fileNames, name[0]),
		rank: strings.IndexByte(rankNames, name[1]),
	}
}

func (s square) String() string {
	return string(fileNames[s.file]) + string(rankNames[s.rank])
}

// The keys of the square in BoardData
func (s square) keys() (rank, file string) {
	return rankNames[s.rank : s.rank+1], fileNames[s.file : s.file+1]
}

func (s square) on(size int) bool {
	return s.file >= 0 && s.file < size && s.rank >= 0 && s.rank < size
}

type direction int

const (
	up direction = iota
	right
	down
	left
)

func (s square) step(d direction) square {
	switch d {
	case up:
		s.rank++
	case down:
		s.rank--
	case right:
		s.file++
	case left:
		s.file--
	}

	return s
}
