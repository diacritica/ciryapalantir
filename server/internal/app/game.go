package app

import (
	"fmt"
	"strconv"

	"cirya.me/server/internal/cirya"
)

// GameState is where a game is:
//
//	NOT_STARTED → TURN_1 ⇄ TURN_2 → WIN_1, WIN_2 or DRAW
//
// Players sit and get ready while it has not started, and it starts when
// both are ready.
type GameState string

const (
	NotStarted GameState = "NOT_STARTED"
	Turn1      GameState = "TURN_1"
	Turn2      GameState = "TURN_2"
	Win1       GameState = "WIN_1"
	Win2       GameState = "WIN_2"
	Draw       GameState = "DRAW"
)

// ErrorCode is why the game refuses a request, sent back in an Error notification
type ErrorCode string

const (
	CodeBadMessage     ErrorCode = "BAD_MESSAGE"
	CodeSeatTaken      ErrorCode = "SEAT_TAKEN"
	CodeNotYourSeat    ErrorCode = "NOT_YOUR_SEAT"
	CodeNotYourTurn    ErrorCode = "NOT_YOUR_TURN"
	CodeStaleTurn      ErrorCode = "STALE_TURN"
	CodeGameNotStarted ErrorCode = "GAME_NOT_STARTED"
	CodeGameStarted    ErrorCode = "GAME_STARTED"
	CodeGameFinished   ErrorCode = "GAME_FINISHED"
)

type refusal struct {
	code ErrorCode
	text string
}

func (r refusal) Error() string {
	return string(r.code) + ": " + r.text
}

// Game is the game of a room. It is only used from the room goroutine
type Game struct {
	config GameConfig
	// By seat number, "1" or "2", as the protocol sends them
	seats map[string]Seat
	state GameState
	// Turns played by both players, from 1
	turn  int
	moves []string
	board *cirya.Board
}

type GameConfig struct {
	Ambient string `json:"ambient"`
	Pieces  string `json:"pieces"`
	Size    int    `json:"size"`
}

// Seat is one of the two places at the table
type Seat struct {
	// The user sitting here, the only one who can play with this seat
	UserID ID     `json:"-"`
	Name   string `json:"name"`
	Color  string `json:"color"`
	Ready  bool   `json:"ready"`
}

// GameStatus is the whole game as the clients see it. The board, the turn
// and the fleets are only there once the game has started
type GameStatus struct {
	Config  GameConfig           `json:"config,omitempty"`
	Players map[string]Seat      `json:"players,omitempty"`
	State   GameState            `json:"state,omitempty"`
	Moves   []string             `json:"moves,omitempty"`
	Board   cirya.BoardData      `json:"board,omitempty"`
	Turn    *int                 `json:"turn,omitempty"`
	Player  *int                 `json:"currentPlayer,omitempty"`
	Fleets  map[int]*cirya.Fleet `json:"fleets,omitempty"`
}

func NewGame() *Game {
	config := GameConfig{Ambient: "TAVERN", Pieces: "WOOD", Size: 5}

	return &Game{
		config: config,
		seats:  make(map[string]Seat),
		state:  NotStarted,
		turn:   1,
		moves:  make([]string, 0),
		board:  cirya.NewBoard(config.Size),
	}
}

func (g *Game) State() GameState {
	return g.state
}

func (g *Game) Turn() int {
	return g.turn
}

// Player is the player whose turn it is, and 0 when nobody can play
func (g *Game) Player() int {
	switch g.state {
	case Turn1:
		return 1
	case Turn2:
		return 2
	}

	return 0
}

func (g *Game) Started() bool {
	return g.state != NotStarted
}

func (g *Game) Finished() bool {
	return g.state == Win1 || g.state == Win2 || g.state == Draw
}

func (g *Game) Status() GameStatus {
	status := GameStatus{Config: g.config, Players: g.seats, State: g.state}

	if g.Started() {
		turn, player := g.turn, g.Player()
		status.Moves = g.moves
		status.Board = g.board.Data
		status.Turn = &turn
		status.Player = &player
		status.Fleets = g.board.Fleets
	}

	return status
}

// Sit gives the seat to the user. Once the game has started only its owner
// can come back to it, and then rejoined is true
func (g *Game) Sit(user ID, player int, name, color string) (rejoined bool, err error) {
	if err := checkSeat(player); err != nil {
		return false, err
	}

	seat, taken := g.seats[strconv.Itoa(player)]

	switch {
	case taken && seat.UserID != user:
		return false, refusal{CodeSeatTaken, "this seat is taken by another user"}
	case g.Started() && taken:
		return true, nil
	case g.Started():
		return false, refusal{CodeGameStarted, "the game has already started"}
	}

	g.seats[strconv.Itoa(player)] = Seat{UserID: user, Name: name, Color: color}
	return false, nil
}

// Stand frees the seat of the user before the game starts
func (g *Game) Stand(user ID, player int) error {
	if err := g.checkOwner(user, player); err != nil {
		return err
	}

	if g.Started() {
		return refusal{CodeGameStarted, "cannot leave a started game"}
	}

	delete(g.seats, strconv.Itoa(player))
	return nil
}

// SetReady starts the game when both players are ready, and then started is true
func (g *Game) SetReady(user ID, player int, ready bool) (started bool, err error) {
	if err := g.checkOwner(user, player); err != nil {
		return false, err
	}

	if g.Started() {
		return false, refusal{CodeGameStarted, "the game has already started"}
	}

	seat := g.seats[strconv.Itoa(player)]
	seat.Ready = ready
	g.seats[strconv.Itoa(player)] = seat

	if !g.seats["1"].Ready || !g.seats["2"].Ready {
		return false, nil
	}

	g.state = Turn1
	g.turn = 1
	g.board = cirya.NewBoard(g.config.Size)
	return true, nil
}

// Play makes the move of the player for the given turn. A move that breaks
// the rules is a plain error and leaves the game as it was
func (g *Game) Play(user ID, player, turn int, move string) (cirya.Result, error) {
	switch {
	case !g.Started():
		return cirya.Result{}, refusal{CodeGameNotStarted, "the game has not started yet"}
	case g.Finished():
		return cirya.Result{}, refusal{CodeGameFinished, "the game is over"}
	}

	if err := g.checkOwner(user, player); err != nil {
		return cirya.Result{}, err
	}

	switch {
	case player != g.Player():
		return cirya.Result{}, refusal{CodeNotYourTurn, "it is not your turn"}
	case turn != g.turn:
		return cirya.Result{}, refusal{CodeStaleTurn, fmt.Sprintf("expected turn %d", g.turn)}
	}

	var err error

	// The first turn of each player places a cirya of the opponent
	if g.turn <= 2 {
		err = g.board.PlayOpening(player, move)
	} else {
		err = g.board.Play(player, move)
	}

	if err != nil {
		return cirya.Result{}, err
	}

	g.moves = append(g.moves, move)
	result := g.board.Result(player)

	switch {
	case result.Over && result.Winner == 1:
		g.state = Win1
	case result.Over && result.Winner == 2:
		g.state = Win2
	case result.Over:
		g.state = Draw
	case g.state == Turn1:
		g.state, g.turn = Turn2, g.turn+1
	default:
		g.state, g.turn = Turn1, g.turn+1
	}

	return result, nil
}

func checkSeat(player int) error {
	if player != 1 && player != 2 {
		return refusal{CodeBadMessage, "player has to be 1 or 2"}
	}

	return nil
}

func (g *Game) checkOwner(user ID, player int) error {
	if err := checkSeat(player); err != nil {
		return err
	}

	if seat, ok := g.seats[strconv.Itoa(player)]; !ok || seat.UserID != user {
		return refusal{CodeNotYourSeat, "this seat belongs to another user"}
	}

	return nil
}
