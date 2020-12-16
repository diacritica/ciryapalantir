package cirya

import (
	"fmt"
	"strconv"
	"strings"
)

type BoardData map[string]map[string][]string

type Board struct{
	Data BoardData
	Size int
}

type MoveDirection int

const (
	UP MoveDirection = iota
	RIGHT
	DOWN
	LEFT
)

var ranks = []string {"a", "b", "c", "d", "e", "f", "g", "h", "i" }
var files = []string {"1", "2", "3", "4", "5", "6", "7", "8", "9" }

func MakeBoard(size int) *Board {
	return &Board {
		Data: make(BoardData),
		Size: size,
	}
}

func (b *Board) PlaceStone(player int, stone string, position string) error {
	rankKey, fileKey := parsePosition(position)
	entry := fmt.Sprintf("%s%d", stone, player)

	if !b.empty(rankKey, fileKey) {
		err := fmt.Errorf("Cannot place stone in occupied position %s", position)
		return err
	}

	b.set(rankKey, fileKey, []string { entry })
	return nil
}

func (b *Board) ControlingPlayer(position string) int {
	rankKey, fileKey := parsePosition(position)
	stones := b.get(rankKey, fileKey)

	if len(stones) == 0 {
		return 0
	}

	last := stones[len(stones) - 1]

	res, _ := strconv.Atoi(string(last[1]))
	return res
}

func (b *Board) StonesInPosition(position string) int {
	rankKey, fileKey := parsePosition(position)
	return len(b.get(rankKey, fileKey))
}

func (b *Board) MoveStones(player int, position string, count int, direction MoveDirection, drops []int) error {

	if b.ControlingPlayer(position) != player {
		return fmt.Errorf("Player %d doesnt' control the position %s", player, position)
	}

	if b.StonesInPosition(position) < count {
		return fmt.Errorf("Not enough stones in position %s. Expected at least %d, found %d", position, count, b.StonesInPosition(position))
	}

	rankKey, fileKey := parsePosition(position)

	current := b.get(rankKey, fileKey)
	toDrop := current[len(current)-count:]

	b.set(rankKey, fileKey, current[:len(current) - count])

	for _, drop := range drops {
		var err error
		rankKey, fileKey, err = next(rankKey, fileKey, b.Size, direction)

		if err != nil {
			return err
		}

		old := b.get(rankKey, fileKey)

		if len(old) > 0 && strings.HasPrefix(old[len(old) - 1], "H") {
			return fmt.Errorf("Cannot put a nose over a Hallacirya")
		}

		if len(old) > 0 && strings.HasPrefix(old[len(old) - 1], "T") {
			return fmt.Errorf("Cannot put a nose over a Tampar")
		}
		
		b.set(rankKey, fileKey, append(old, toDrop[:drop]...))
		toDrop = toDrop[drop:]
	}

	return nil
}

func (b *Board) String() string {
	var sb strings.Builder

	sb.WriteString("   ")
	for _, file := range files {
		sb.WriteString(fmt.Sprintf("%6s", file))
	}

	sb.WriteString("\n")
	
	for _, rank := range reverse(ranks[:b.Size]) {
		sb.WriteString(fmt.Sprintf("%s. ", rank))
		
		for _, file := range files[:b.Size] {

			val := b.get(rank, file)

			if len(val) == 0 {
				sb.WriteString(fmt.Sprintf("%6s", "_"))
			} else if len(val) == 1 {
				sb.WriteString(fmt.Sprintf("%6s", val[0]))
			} else {
				kl := fmt.Sprintf("[%d]%s", len(val)-1, val[len(val)-1])
				sb.WriteString(fmt.Sprintf("%6s", kl))
			}
		}
		sb.WriteString("\n")
	}

	return sb.String()
}
