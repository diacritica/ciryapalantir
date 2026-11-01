package cirya

import (
	"errors"
	"fmt"
	"slices"
)

// Play applies a turn of the player, in notation, or says why it is not
// legal. A rejected turn leaves the board untouched
func (b *Board) Play(player int, turn string) error {
	if p, ok := parsePlacement(turn); ok {
		return b.place(player, p)
	}

	if m, ok := parseMove(turn); ok {
		return b.move(player, m)
	}

	return fmt.Errorf("%q is not a valid turn", turn)
}

// PlayOpening applies the first turn of a player, which places a flat cirya
// of the opponent, as in Tak
func (b *Board) PlayOpening(player int, turn string) error {
	p, ok := parsePlacement(turn)

	if !ok || p.stone != 'C' {
		return fmt.Errorf("the first turn places a flat cirya of the opponent, %q is not one", turn)
	}

	return b.place(Opponent(player), p)
}

func (b *Board) place(player int, p placement) error {
	if !p.at.on(b.Size) {
		return fmt.Errorf("%s is off the board", p.at)
	}

	if len(b.stack(p.at)) > 0 {
		return fmt.Errorf("%s is not empty", p.at)
	}

	if err := b.takeFromFleet(player, p.stone); err != nil {
		return err
	}

	b.setStack(p.at, []string{fmt.Sprintf("%c%d", p.stone, player)})
	return nil
}

// Carries the top stones of a stack the player controls in one direction,
// dropping some on every square along the way, the bottom ones first
func (b *Board) move(player int, m move) error {
	from := b.stack(m.from)
	dropped := 0

	for _, n := range m.drops {
		dropped += n
	}

	switch {
	case owner(top(from)) != player:
		return fmt.Errorf("player %d does not control %s", player, m.from)
	case m.count > b.Size:
		return fmt.Errorf("cannot carry %d stones, the limit is %d", m.count, b.Size)
	case m.count > len(from):
		return fmt.Errorf("%s has %d stones, not %d", m.from, len(from), m.count)
	case dropped != m.count:
		return fmt.Errorf("the drops add up to %d but %d stones are carried", dropped, m.count)
	}

	// Every new stack is worked out before changing the board
	left := len(from) - m.count
	carried := from[left:]
	stacks := make(map[square][]string, len(m.drops))
	at := m.from

	for _, n := range m.drops {
		at = at.step(m.dir)

		if !at.on(b.Size) {
			return errors.New("the move goes off the board")
		}

		stack, err := dropOn(b.stack(at), carried[:n])

		if err != nil {
			return fmt.Errorf("cannot drop on %s: %w", at, err)
		}

		stacks[at] = stack
		carried = carried[n:]
	}

	b.setStack(m.from, from[:left:left])

	for at, stack := range stacks {
		b.setStack(at, stack)
	}

	return nil
}

// The stack once the stones are dropped on it. Nothing goes over a
// hallacirya, and over a tampa only a lone hallacirya, which flattens it
func dropOn(stack, stones []string) ([]string, error) {
	head := top(stack)

	switch kind(head) {
	case 'H':
		return nil, errors.New("there is a hallacirya")
	case 'T':
		if len(stones) != 1 || kind(stones[0]) != 'H' {
			return nil, errors.New("only a lone hallacirya goes over a tampa")
		}

		flattened := "C" + head[1:]
		return slices.Concat(stack[:len(stack)-1], []string{flattened}, stones), nil
	}

	return slices.Concat(stack, stones), nil
}
