package cirya_test

import (
	"encoding/json"
	"os"
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Turns on small positions, each one legal or not, which the rules of the
// client (core/Rules.gd and core/BotBoard.gd, in client/tests/test_shared.gd)
// check too: a rule changed here and not there, or there and not here, fails
// on one side. The board is 5x5 with full fleets unless they say otherwise,
// and white plays the odd turns
type sharedTurn struct {
	Name         string                 `json:"name"`
	Board        map[string][]string    `json:"board"`
	Turn         int                    `json:"turn"`
	Move         string                 `json:"move"`
	Legal        bool                   `json:"legal"`
	Unlimited    bool                   `json:"unlimited"`
	HennethAnnun bool                   `json:"hennethAnnun"`
	Fleets       map[string]cirya.Fleet `json:"fleets"`
}

func TestTheSharedTurns(t *testing.T) {
	data, err := os.ReadFile("testdata/turns.json")
	require.NoError(t, err)

	var turns []sharedTurn
	require.NoError(t, json.Unmarshal(data, &turns))
	require.NotEmpty(t, turns)

	for _, turn := range turns {
		board := boardWith(5, cirya.BoardData{})
		board.Unlimited = turn.Unlimited

		for square, stones := range turn.Board {
			if board.Data[square[1:]] == nil {
				board.Data[square[1:]] = make(map[string][]string)
			}

			board.Data[square[1:]][square[:1]] = stones
		}

		for player, fleet := range turn.Fleets {
			fleet := fleet
			board.Fleets[int(player[0]-'0')] = &fleet
		}

		err := playShared(board, turn)
		assert.Equal(t, turn.Legal, err == nil, "%s: %s (%v)", turn.Name, turn.Move, err)
	}
}

// The turn played on the board as the server plays it, white in odd turns
func playShared(board *cirya.Board, turn sharedTurn) error {
	player := 2 - turn.Turn%2

	if turn.Turn <= 2 {
		return board.PlayOpening(player, turn.Move)
	}

	if turn.HennethAnnun {
		if err := cirya.HennethAnnun(turn.Turn, turn.Move); err != nil {
			return err
		}
	}

	return board.Play(player, turn.Move)
}
