package app

import (
	"fmt"
	"strconv"
	"cirya.me/server/internal/cirya"
)

type GameStatus struct {
	Config GameConfig `json:"config,omitempty"`
	Players map[string]PlayerStatus `json:"players,omitempty"`
	State GameState `json:"state,omitempty"`
	Moves []string `json:"moves,omitempty"`
	Board cirya.BoardData `json:"board,omitempty"`
	Turn *int `json:"turn,omitempty"`
	Player *int `json:"currentPlayer,omitempty"`
}

type game struct {
	id ID
	config GameConfig
	players map[string]PlayerStatus
	state GameState
	moves []string
	board *cirya.Board
	turn int
	player int
}

type GameState string

const (
	NOT_STARTED GameState = "NOT_STARTED"

	TURN_1 = "TURN_1"
	TURN_2 = "TURN_2"

	// End states
	WIN_1 = "WIN_1"
	WIN_2 = "WIN_2"
	DRAW = "DRAW"
)

type WinCondition string

const(
	NONE WinCondition = "NONE"
	LONDI = "LONDI"
	FLAT = "FLAT"
	RESIGN = "RESIGN"
)

type TurnResult struct {
	State GameState
	NextTurn int
	NextPlayer int
	EndGame bool
	WinCondition WinCondition
}

type Game interface {
	Status() GameStatus
	AddPlayer(name string, player int, color string)
	RemovePlayer(player int)
	SetReady(player int, ready bool)

	ArePlayersReady() bool
	StartGame()

	CurrentPlayer() int
	CurrentTurn() int
	Turn(move string) TurnResult
}

type PlayerStatus struct {
	Name string `json:"name"`
	Color string `json:"color"`
	Ready bool `json:"ready"`
}

type GameConfig struct {
	Ambient string `json:"ambient"`
	Pieces string `json:"pieces"`
	Size int `json:"size"`
}

func NewGame(id ID) Game {
	return &game {
		id: id,
		config: GameConfig {
			Ambient: "TAVERN",
			Pieces: "WOOD",
			Size: 5,
		},
		players: make(map[string]PlayerStatus),
		state: NOT_STARTED,
		moves: make([]string, 0),
		board: cirya.MakeBoard(5),
		turn: 1,
		player: 1,
	}
}

func (g *game) Status() GameStatus {
	status := GameStatus {
		Config: g.config,
		Players: g.players,
		State: g.state,
	}

	if g.state != NOT_STARTED {
		status.Moves = g.moves
		status.Board = g.board.Data
		status.Turn = &g.turn
		status.Player = &g.player
	}
	
	return status
}

func (g *game) AddPlayer(name string, player int, color string) {
	status := PlayerStatus {
		Name: name,
		Color: color,
		Ready: false,
	}

	g.players[strconv.Itoa(player)] = status
}

func (g *game) RemovePlayer(player int) {
	delete(g.players, strconv.Itoa(player))
}

func (g *game) SetReady(player int, ready bool) {
	status, _ := g.players[strconv.Itoa(player)]
	status.Ready = ready
	g.players[strconv.Itoa(player)] = status
}

func (g *game) ArePlayersReady() bool {
	return g.players["1"].Ready && g.players["2"].Ready
}

func (g *game) StartGame() {
	g.state = TURN_1
	g.turn = 1
	g.player = 1
	g.board = cirya.MakeBoard(g.config.Size)
}

func (g *game) CurrentPlayer() int {
	return g.player
}

func (g *game) CurrentTurn() int {
	return g.turn
}

func (g *game) Turn(move string) TurnResult {
	var result TurnResult

	g.moves = append(g.moves, move)
	
	if (move == "fin") {
		result.State = WIN_1
		result.EndGame = true
		result.WinCondition = LONDI

		g.state = result.State
		g.turn = 0
		g.player = 0
		
		return result
	}

	g.board.ProcessMove(g.player, move)

	fmt.Println(g.board.String())

	if g.state == TURN_1 {
		result.State = TURN_2
		result.NextPlayer = 2
	} else {
		result.State = TURN_1
		result.NextPlayer = 1
	}

	result.NextTurn = g.turn + 1
	result.EndGame = false
	result.WinCondition = NONE

	g.state = result.State
	g.turn = result.NextTurn
	g.player = result.NextPlayer
	
	return result
}
