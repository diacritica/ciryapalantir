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

var ranks = []string {"1", "2", "3", "4", "5", "6", "7", "8", "9" }
var files = []string {"a", "b", "c", "d", "e", "f", "g", "h", "i" }

func MakeBoard(size int) *Board {
	return &Board {
		Data: make(BoardData),
		Size: size,
	}
}

func (b *Board) PlaceStone(player int, stone string, position string) error {
	rank, file := parsePosition(position)
	entry := fmt.Sprintf("%s%d", stone, player)

	if !b.empty(rank, file) {
		err := fmt.Errorf("Cannot place stone in occupied position %s", position)
		return err
	}

	if !checkRank(rank, b.Size) || !checkFile(file, b.Size) {
		err := fmt.Errorf("Invalid position %s", position)
		return err
	}

	b.set(rank, file, []string { entry })

	return nil
}

func (b *Board) ControlingPlayer(position string) int {
	rank, file := parsePosition(position)
	stones := b.get(rank, file)

	if len(stones) == 0 {
		return 0
	}

	last := stones[len(stones) - 1]

	res, _ := strconv.Atoi(string(last[1]))
	return res
}

func (b *Board) StonesInPosition(position string) int {
	rank, file := parsePosition(position)
	return len(b.get(rank, file))
}

func (b *Board) MoveStones(player int, position string, count int, direction MoveDirection, drops []int) error {
	var err error
	var current, currentDrop []string
	
	if b.ControlingPlayer(position) != player {
		return fmt.Errorf("Player %d doesnt' control the position %s", player, position)
	}

	if count < 1 || count > b.Size {
		return fmt.Errorf("Cannot carry %d stones, the limit is %d", count, b.Size)
	}

	if b.StonesInPosition(position) < count {
		return fmt.Errorf("Not enough stones in position %s. Expected at least %d, found %d", position, count, b.StonesInPosition(position))
	}

	dropped := 0
	for _, drop := range drops {
		if drop < 1 {
			return fmt.Errorf("Every drop must leave at least one stone")
		}
		dropped += drop
	}

	if dropped != count {
		return fmt.Errorf("Drops add up to %d but %d stones were taken", dropped, count)
	}

	rank, file := parsePosition(position)
	current = b.get(rank, file)
	toDrop := current[len(current)-count:]

	// Validate the drop squares before changing anything in the board
	for _, drop := range drops {
		rank, file, err = next(rank, file, b.Size, direction)

		if err != nil {
			return err
		}

		current = b.get(rank, file)
		currentDrop = toDrop[:drop]

		if !checkRank(rank, b.Size) || !checkFile(file, b.Size) {
			return fmt.Errorf("Drop position %s%s is not valid", rank, file)
		}

		var head string

		if len(current) > 0 {
			head = current[len(current) - 1]
		}

		if strings.HasPrefix(head, "H") {
			return fmt.Errorf("Cannot put stones over a Hallacirya")
		}

		// If the piece to drop is only a Hallacirya, is OK. Otherwise, error
		isHallaciryaMove := len(currentDrop) == 1 && strings.HasPrefix(currentDrop[0], "H")

		if strings.HasPrefix(head, "T") && !isHallaciryaMove {
			return fmt.Errorf("Cannot put stones over Tampar")
		}

		toDrop = toDrop[drop:]
	}

	rank, file = parsePosition(position)
	current = b.get(rank, file)
	toDrop = current[len(current)-count:]

	b.set(rank, file, current[:len(current) - count])

	for _, drop := range drops {
		rank, file, _ = next(rank, file, b.Size, direction)
		current = b.get(rank, file)
		currentDrop = toDrop[:drop]

		// Checking if hallacirya "flats" a Tampar
		var head string

		if len(current) > 0 {
			head = current[len(current) - 1]
		}
		
		// If the piece to drop is only a Hallacirya, is OK. Otherwise, error
		isHallaciryaMove := len(currentDrop) == 1 && strings.HasPrefix(currentDrop[0], "H")

		if strings.HasPrefix(head, "T") && isHallaciryaMove {
			flattenTampar := "C" + string(head[1])
			currentDrop = append([]string { flattenTampar }, currentDrop...)
			b.set(rank, file, append(current[:len(current) - 1], currentDrop...))
		} else {
			b.set(rank, file, append(current, currentDrop...))
		}
		
		toDrop = toDrop[drop:]
	}

	return nil
}

func (b *Board) String() string {
	var sb strings.Builder

	sb.WriteString("   ")
	for _, file := range files[:b.Size] {
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
