package cirya_test

import (
	"testing"

	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
)

func boardWith(size int, data cirya.BoardData) *cirya.Board {
	return &cirya.Board{Data: data, Size: size}
}

// Returns the error, failing the test instead of crashing when the move panics
func safeMove(t *testing.T, board *cirya.Board, player int, move string) (err error) {
	t.Helper()

	defer func() {
		if r := recover(); r != nil {
			t.Errorf("move %s panicked: %v", move, r)
			err = nil
		}
	}()

	return board.ProcessMove(player, move)
}

// S6: drops have to add up to the stones taken
func TestDropsMustAddUpToCount(t *testing.T) {
	board := boardWith(5, cirya.BoardData{
		"1": {"a": []string{"C1"}, "b": []string{"C1", "C1"}},
	})

	// One stone, drops nine
	assert.NotNil(t, safeMove(t, board, 1, "a1+9"))
	// Two stones, drops one
	assert.NotNil(t, safeMove(t, board, 1, "2b1+1"))
	// Two stones, drops three
	assert.NotNil(t, safeMove(t, board, 1, "2b1+111"))

	assert.Equal(t, []string{"C1"}, board.Data["1"]["a"])
	assert.Equal(t, []string{"C1", "C1"}, board.Data["1"]["b"])
	assert.Empty(t, board.Data["2"])
}

// S6: no more stones than the board size can be carried
func TestCarryLimit(t *testing.T) {
	board := boardWith(5, cirya.BoardData{
		"1": {"a": []string{"C2", "C1", "C1", "C1", "C1", "C1"}},
	})

	assert.NotNil(t, safeMove(t, board, 1, "6a1+"))
	assert.NotNil(t, safeMove(t, board, 1, "6a1+1113"))
	assert.Nil(t, safeMove(t, board, 1, "5a1+1112"))
}

// A rejected move leaves the board as it was
func TestFailedMoveLeavesBoardUntouched(t *testing.T) {
	board := boardWith(5, cirya.BoardData{
		"1": {"a": []string{"C1", "C1"}},
		"3": {"a": []string{"T2"}},
	})

	assert.NotNil(t, safeMove(t, board, 1, "2a1+11"))

	assert.Equal(t, []string{"C1", "C1"}, board.Data["1"]["a"])
	assert.Empty(t, board.Data["2"])
	assert.Equal(t, []string{"T2"}, board.Data["3"]["a"])
}
