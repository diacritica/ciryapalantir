package cirya

import (
	"fmt"
)

// Pieces a player has not placed yet. Tampar come from the same pile as ciryar
type Fleet struct {
	Ciryar      int `json:"ciryar"`
	Hallaciryar int `json:"hallaciryar"`
}

// Official fleets for every board size
var fleets = map[int]Fleet{
	5: {Ciryar: 21, Hallaciryar: 1},
	6: {Ciryar: 30, Hallaciryar: 2},
	7: {Ciryar: 40, Hallaciryar: 2},
}

func NewFleet(size int) *Fleet {
	fleet, ok := fleets[size]

	if !ok {
		// Not an official size: as many pieces as squares, no limit in practice
		fleet = Fleet{Ciryar: size * size, Hallaciryar: 2}
	}

	return &fleet
}

func (f *Fleet) Empty() bool {
	return f.Ciryar == 0 && f.Hallaciryar == 0
}

func (b *Board) takeFromFleet(player int, stone string) error {
	if b.Fleets == nil {
		return nil
	}

	fleet, ok := b.Fleets[player]

	if !ok {
		return fmt.Errorf("Player %d has no fleet", player)
	}

	if stone == "H" {
		if fleet.Hallaciryar == 0 {
			return fmt.Errorf("Player %d has no hallaciryar left", player)
		}
		fleet.Hallaciryar--
	} else {
		if fleet.Ciryar == 0 {
			return fmt.Errorf("Player %d has no ciryar left", player)
		}
		fleet.Ciryar--
	}

	return nil
}

// True when a player has placed every piece of the fleet
func (b *Board) FleetEmpty(player int) bool {
	if b.Fleets == nil {
		return false
	}

	fleet, ok := b.Fleets[player]
	return ok && fleet.Empty()
}
