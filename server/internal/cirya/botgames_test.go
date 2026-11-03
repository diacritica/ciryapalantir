package cirya_test

import (
	"encoding/json"
	"os"
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Random games played by the board of the bot in the client, written by
// client/tests/dump_bot_games.gd: every turn it thinks legal has to be
// legal here, end the game when it ends it there, and lead to the same board.
// client/tests/test_shared.gd plays them with the lists of the client too
type botGame struct {
	Unlimited bool                `json:"unlimited"`
	Moves     []string            `json:"moves"`
	Board     map[string][]string `json:"board"`
	Result    struct {
		Over      bool   `json:"over"`
		Winner    int    `json:"winner"`
		Condition string `json:"condition"`
	} `json:"result"`
}

func TestTheGamesOfTheBot(t *testing.T) {
	data, err := os.ReadFile("testdata/bot_games.json")
	require.NoError(t, err)

	var games []botGame
	require.NoError(t, json.Unmarshal(data, &games))
	require.NotEmpty(t, games)

	for g, game := range games {
		board := cirya.NewBoard(5)
		board.Unlimited = game.Unlimited
		var result cirya.Result

		for i, move := range game.Moves {
			player := 1 + i%2

			if i < 2 {
				err = board.PlayOpening(player, move)
			} else {
				err = board.Play(player, move)
			}

			require.NoError(t, err, "game %d, turn %d: %s", g, i+1, move)
			result = board.Result(player)

			if i < len(game.Moves)-1 {
				require.False(t, result.Over, "game %d ended at turn %d, before the bot thought", g, i+1)
			}
		}

		assert.Equal(t, game.Result.Over, result.Over, "game %d", g)
		assert.Equal(t, game.Result.Winner, result.Winner, "game %d", g)
		assert.Equal(t, game.Result.Condition, string(result.Condition), "game %d", g)

		stacks := make(map[string][]string)

		for rank, files := range board.Data {
			for file, stones := range files {
				if len(stones) > 0 {
					stacks[file+rank] = stones
				}
			}
		}

		assert.Equal(t, game.Board, stacks, "game %d: the board at the end", g)
	}
}
