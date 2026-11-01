package cirya_test

import (
	"cirya.me/server/internal/cirya"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPlaceOne(t *testing.T) {
	var board = cirya.MakeBoard(9)
	err1 := board.ProcessMove(1, "a1")
	err2 := board.ProcessMove(2, "Hi9")
	err3 := board.ProcessMove(1, "Td4")
	err4 := board.ProcessMove(1, "x1")
	err5 := board.ProcessMove(1, "a0")

	assert.Nil(t, err1)
	assert.Nil(t, err2)
	assert.Nil(t, err3)

	assert.Equal(t, board.Data["1"]["a"], []string{"C1"})
	assert.Equal(t, board.Data["9"]["i"], []string{"H2"})
	assert.Equal(t, board.Data["4"]["d"], []string{"T1"})

	assert.NotNil(t, err4)
	assert.NotNil(t, err5)
}

func TestPlaceOverExistingFails(t *testing.T) {
	var board = cirya.MakeBoard(9)
	board.ProcessMove(1, "a1")

	var err error

	err = board.ProcessMove(1, "a1")
	assert.NotNil(t, err)

	err = board.ProcessMove(2, "Ha1")
	assert.NotNil(t, err)

	err = board.ProcessMove(1, "Ta1")
	assert.NotNil(t, err)
}

func TestMove(t *testing.T) {
	var err error

	var board = &cirya.Board{
		Data: cirya.BoardData{
			"1": {
				"a": []string{"C1", "C2", "C1", "C1"},
			},

			"5": {
				"c": []string{"C2"},
				"d": []string{"C1", "C2", "H1"},
				"e": []string{"C2"},
			},
		},
		Size: 9,
	}

	board.ProcessMove(1, "a1>")

	assert.Equal(t, board.Data["1"]["a"], []string{"C1", "C2", "C1"})
	assert.Equal(t, board.Data["1"]["b"], []string{"C1"})

	board.ProcessMove(1, "3a1+")

	assert.Equal(t, board.Data["1"]["a"], []string{})
	assert.Equal(t, board.Data["2"]["a"], []string{"C1", "C2", "C1"})

	board.ProcessMove(1, "3a2>111")

	assert.Equal(t, board.Data["1"]["a"], []string{})
	assert.Equal(t, board.Data["2"]["a"], []string{})

	assert.Equal(t, board.Data["2"]["b"], []string{"C1"})
	assert.Equal(t, board.Data["2"]["c"], []string{"C2"})
	assert.Equal(t, board.Data["2"]["d"], []string{"C1"})

	err = board.ProcessMove(1, "2d5-2")

	assert.Nil(t, err)
	assert.Equal(t, board.Data["5"]["d"], []string{"C1"})
	assert.Equal(t, board.Data["4"]["d"], []string{"C2", "H1"})

	board.ProcessMove(2, "c5>")
	board.ProcessMove(2, "e5<")

	assert.Equal(t, board.Data["5"]["c"], []string{})
	assert.Equal(t, board.Data["5"]["d"], []string{"C1", "C2", "C2"})
	assert.Equal(t, board.Data["5"]["e"], []string{})

	board.ProcessMove(2, "3d5<12")

	assert.Equal(t, board.Data["5"]["c"], []string{"C1"})
	assert.Equal(t, board.Data["5"]["b"], []string{"C2", "C2"})
}

func TestMoveOutsideBounds(t *testing.T) {
	var board = &cirya.Board{
		Data: cirya.BoardData{
			"1": {
				"a": []string{"C1", "C1", "C1"},
			},

			"9": {
				"i": []string{"C1", "C1", "C1"},
			},
		},
		Size: 9,
	}

	assert.NotNil(t, board.ProcessMove(1, "a1<"))
	assert.NotNil(t, board.ProcessMove(1, "3a1<"))
	assert.NotNil(t, board.ProcessMove(1, "3a1<111"))

	assert.NotNil(t, board.ProcessMove(1, "a1-"))
	assert.NotNil(t, board.ProcessMove(1, "3a1-"))
	assert.NotNil(t, board.ProcessMove(1, "3a1-111"))

	assert.NotNil(t, board.ProcessMove(1, "i9>"))
	assert.NotNil(t, board.ProcessMove(1, "3i9>"))
	assert.NotNil(t, board.ProcessMove(1, "3i9>111"))

	assert.NotNil(t, board.ProcessMove(1, "i9+"))
	assert.NotNil(t, board.ProcessMove(1, "3i9+"))
	assert.NotNil(t, board.ProcessMove(1, "3i9+111"))
}

func TestMoveOverTampa(t *testing.T) {
	var err error

	var board = &cirya.Board{
		Data: cirya.BoardData{
			"6": {
				"c": []string{"T1"},
				"b": []string{"C1"},
				"d": []string{"H1"},
			},

			"7": {
				"c": []string{"C1", "H1"},
			},
		},
		Size: 9,
	}

	// Invalid moves
	assert.NotNil(t, board.ProcessMove(1, "b6>"))
	assert.NotNil(t, board.ProcessMove(1, "2c7-2"))

	// Valid
	err = board.ProcessMove(1, "d6<")
	assert.Nil(t, err)
	assert.Equal(t, board.Data["6"]["c"], []string{"C1", "H1"})
}
