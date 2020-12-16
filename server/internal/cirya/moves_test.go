package cirya_test

import (
	"fmt"
	"testing"
	"github.com/stretchr/testify/assert"
	"cirya.me/server/internal/cirya"
)

func TestPlaceOne(t *testing.T) {
	var board = cirya.MakeBoard(9)
	board.ProcessMove(1, "a1")
	board.ProcessMove(2, "Hi9")
	board.ProcessMove(1, "Td4")

	assert.Equal(t, board.Data["a"]["1"], []string{ "C1" })
	assert.Equal(t, board.Data["i"]["9"], []string{ "H2" })
	assert.Equal(t, board.Data["d"]["4"], []string{ "T1" })
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
	var board = &cirya.Board {
		Data: cirya.BoardData {
			"a": {
				"1": []string { "C1", "C2", "C1", "C1" },
			},

			"e": {
				"3": []string { "C2" },
				"4": []string { "C1", "C2", "H1" },
				"5": []string { "C2" },
			},
		},
		Size: 9,
	}

	fmt.Println(" == INITIAL ==")
	fmt.Println(board.String())

	board.ProcessMove(1, "a1>")

	fmt.Printf(" == %s ==\n", "a1>")
	fmt.Println(board.String())
	
	assert.Equal(t, board.Data["a"]["1"], []string { "C1", "C2", "C1" })
	assert.Equal(t, board.Data["a"]["2"], []string { "C1" })

	board.ProcessMove(1, "3a1+")
	fmt.Printf(" == %s ==\n", "3a1+")
	fmt.Println(board.String())
	
	assert.Equal(t, board.Data["a"]["1"], []string { })
	assert.Equal(t, board.Data["b"]["1"], []string { "C1", "C2", "C1" })

	board.ProcessMove(1, "3b1>111")
	fmt.Printf(" == %s ==\n", "3b1>111")
	fmt.Println(board.String())
	
	assert.Equal(t, board.Data["a"]["1"], []string { })
	assert.Equal(t, board.Data["b"]["1"], []string { })

	assert.Equal(t, board.Data["b"]["2"], []string { "C1" })
	assert.Equal(t, board.Data["b"]["3"], []string { "C2" })
	assert.Equal(t, board.Data["b"]["4"], []string { "C1" })

	board.ProcessMove(1, "2e4-2")
	fmt.Printf(" == %s ==\n", "2e4-2")
	fmt.Println(board.String())

	assert.Equal(t, board.Data["e"]["4"], []string { "C1" })
	assert.Equal(t, board.Data["d"]["4"], []string { "C2", "H1" })


	board.ProcessMove(2, "e3>")
	board.ProcessMove(2, "e5<")
	fmt.Printf(" == %s ==\n", "e3>, e5<")
	fmt.Println(board.String())

	assert.Equal(t, board.Data["e"]["3"], []string { })
	assert.Equal(t, board.Data["e"]["4"], []string { "C1", "C2", "C2" })
	assert.Equal(t, board.Data["e"]["5"], []string { })

	board.ProcessMove(2, "3e4<12")
	fmt.Printf(" == %s ==\n", "3e4<12")
	fmt.Println(board.String())

	assert.Equal(t, board.Data["e"]["3"], []string { "C1" })
	assert.Equal(t, board.Data["e"]["2"], []string { "C2", "C2" })
}
