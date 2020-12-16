package cirya

import (
	"fmt"
	"regexp"
	"strconv"
)

// (stone)(position)
var placeRe = regexp.MustCompile(`^(?P<stone>[HT])?(?P<position>[a-j][1-9])$`)

// (count)(position)(direction)(drop counts)(stone)
var moveRe = regexp.MustCompile(`^(?P<count>[1-9])?(?P<position>[a-j][1-9])(?P<direction>[<>\+\-])(?P<dropCounts>[1-9]*)(?P<stone>[HT])?$`)

func (b *Board) ProcessMove(player int, move string) error {

	// Check if the move is a placement from fleet
	if placeRe.MatchString(move) {
		groups := placeRe.FindStringSubmatch(move)

		stone := groups[1]

		if stone == "" {
			stone = "C"
		}
		
		position := groups[2]

		err := b.PlaceStone(player, stone, position)

		return err
	}

	if moveRe.MatchString(move) {
		groups := moveRe.FindStringSubmatch(move)

		countStr := groups[1]

		if countStr == "" {
			countStr = "1"
		}

		count, err := strconv.Atoi(countStr)

		if err != nil {
			return err
		}
		
		position := groups[2]
		directionSymbol := groups[3]

		var direction MoveDirection
		switch directionSymbol {
		case "+":
			direction = UP
		case ">":
			direction = RIGHT
		case "-":
			direction = DOWN
		case "<":
			direction = LEFT
		default:
			return fmt.Errorf("No valid direction %s", directionSymbol)
		}

		dropCountsStr := groups[4]

		if dropCountsStr == "" {
			dropCountsStr = countStr
		}

		drops := make([]int, 0)
		for _, ch := range dropCountsStr {
			val, err := strconv.Atoi(string(ch))

			if err != nil {
				return err
			}
			
			drops = append(drops, val)
		}

		err = b.MoveStones(player, position, count, direction, drops)

		return err
	}

	return fmt.Errorf("No valid movement %s", move)
}
