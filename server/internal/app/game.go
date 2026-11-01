package app

import (
	"cirya.me/server/internal/cirya"
	"fmt"
	"strconv"
)

type GameStatus struct {
	Config  GameConfig              `json:"config,omitempty"`
	Players map[string]PlayerStatus `json:"players,omitempty"`
	State   GameState               `json:"state,omitempty"`
	Moves   []string                `json:"moves,omitempty"`
	Board   cirya.BoardData         `json:"board,omitempty"`
	Turn    *int                    `json:"turn,omitempty"`
	Player  *int                    `json:"currentPlayer,omitempty"`
	Fleets  map[int]*cirya.Fleet    `json:"fleets,omitempty"`
}

type game struct {
	id      ID
	config  GameConfig
	players map[string]PlayerStatus
	state   GameState
	moves   []string
	board   *cirya.Board
	turn    int
	player  int
}

type GameState string

const (
	NOT_STARTED GameState = "NOT_STARTED"

	TURN_1 = "TURN_1"
	TURN_2 = "TURN_2"

	// End states
	WIN_1 = "WIN_1"
	WIN_2 = "WIN_2"
	DRAW  = "DRAW"
)

type WinCondition string

const (
	NONE   WinCondition = "NONE"
	LONDI               = "LONDI"
	FLAT                = "FLAT"
	RESIGN              = "RESIGN"
)

type TurnResult struct {
	State        GameState
	NextTurn     int
	NextPlayer   int
	EndGame      bool
	WinCondition WinCondition
}

type Game interface {
	Status() GameStatus
	State() GameState
	Seat(player int) (PlayerStatus, bool)
	AddPlayer(user ID, name string, player int, color string)
	RemovePlayer(player int)
	SetReady(player int, ready bool)

	ArePlayersReady() bool
	StartGame()

	CurrentPlayer() int
	CurrentTurn() int
	Turn(move string) (TurnResult, error)
}

type PlayerStatus struct {
	// The user sitting in this seat, the only one who can play with it
	UserID ID     `json:"-"`
	Name   string `json:"name"`
	Color  string `json:"color"`
	Ready  bool   `json:"ready"`
}

type GameConfig struct {
	Ambient string `json:"ambient"`
	Pieces  string `json:"pieces"`
	Size    int    `json:"size"`
}

func NewGame(id ID) Game {
	return &game{
		id: id,
		config: GameConfig{
			Ambient: "TAVERN",
			Pieces:  "WOOD",
			Size:    5,
		},
		players: make(map[string]PlayerStatus),
		state:   NOT_STARTED,
		moves:   make([]string, 0),
		board:   cirya.MakeBoard(5),
		turn:    1,
		player:  1,
	}
}

func (g *game) Status() GameStatus {
	status := GameStatus{
		Config:  g.config,
		Players: g.players,
		State:   g.state,
	}

	if g.state != NOT_STARTED {
		status.Moves = g.moves
		status.Board = g.board.Data
		status.Turn = &g.turn
		status.Player = &g.player
		status.Fleets = g.board.Fleets
	}

	return status
}

func (g *game) State() GameState {
	return g.state
}

func (g *game) Seat(player int) (PlayerStatus, bool) {
	status, ok := g.players[strconv.Itoa(player)]
	return status, ok
}

func (g *game) AddPlayer(user ID, name string, player int, color string) {
	status := PlayerStatus{
		UserID: user,
		Name:   name,
		Color:  color,
		Ready:  false,
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

func (g *game) Turn(move string) (TurnResult, error) {
	var result TurnResult
	var err error

	// The first move of each player places a cirya of the opponent
	if g.turn <= 2 {
		err = g.board.ProcessOpening(g.player, move)
	} else {
		err = g.board.ProcessMove(g.player, move)
	}

	if err != nil {
		return result, err
	}

	fmt.Println(g.board.String())

	g.moves = append(g.moves, move)
	end := g.board.Result(g.player)

	if end.Over {
		switch end.Winner {
		case 1:
			result.State = WIN_1
		case 2:
			result.State = WIN_2
		default:
			result.State = DRAW
		}

		result.EndGame = true
		result.WinCondition = WinCondition(end.Condition)

		g.state = result.State
		g.player = 0

		return result, nil
	}

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

	return result, nil
}
