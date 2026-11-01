package cirya

import "fmt"

// Fleet counts the pieces a player has not placed yet. Tampar come from the same pile as ciryar
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

// FleetEmpty tells if the player has placed every piece of the fleet
func (b *Board) FleetEmpty(player int) bool {
	fleet := b.Fleets[player]
	return fleet != nil && fleet.Empty()
}

func (b *Board) takeFromFleet(player int, stone byte) error {
	fleet := b.Fleets[player]

	switch {
	case fleet == nil:
		return fmt.Errorf("player %d has no fleet", player)
	case stone == 'H' && fleet.Hallaciryar == 0:
		return fmt.Errorf("player %d has no hallaciryar left", player)
	case stone != 'H' && fleet.Ciryar == 0:
		return fmt.Errorf("player %d has no ciryar left", player)
	case stone == 'H':
		fleet.Hallaciryar--
	default:
		fleet.Ciryar--
	}

	return nil
}
