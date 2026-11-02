package app

import (
	"fmt"
	"slices"
	"time"

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
	CodeConfigLocked   ErrorCode = "CONFIG_LOCKED"
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
	// By seat number, 1 or 2
	seats map[int]Seat
	state GameState
	// The turn being played, counting the turns of both players from 1
	turn  int
	moves []string
	board *cirya.Board

	// The time left to each player, nil for a game without clock
	clocks map[int]time.Duration
	// The player whose clock runs, 0 when none does, and since when
	running int
	since   time.Time
	// The time now, which the tests set
	now func() time.Time
}

// A second of the clock. The tests make it shorter
var clockUnit = time.Second

type GameConfig struct {
	Ambient string `json:"ambient"`
	Pieces  string `json:"pieces"`
	Size    int    `json:"size"`
	// Seconds on the clock of each player, 0 for no clock
	Clock int `json:"clock"`
	// Each hallacirya only goes into play in one turn: the 16th of black and
	// the 17th of white. Only on the 5×5 board
	HennethAnnun bool `json:"hennethAnnun"`
}

// The times a game can be played with, in seconds; 0 is no clock
var Clocks = []int{0, 180, 300, 600, 900}

const DefaultClock = 300

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
	Config  GameConfig           `json:"config"`
	Players map[int]Seat         `json:"players,omitempty"`
	State   GameState            `json:"state"`
	Moves   []string             `json:"moves,omitempty"`
	Board   cirya.BoardData      `json:"board,omitempty"`
	Turn    *int                 `json:"turn,omitempty"`
	Player  *int                 `json:"currentPlayer,omitempty"`
	Fleets  map[int]*cirya.Fleet `json:"fleets,omitempty"`
	// Milliseconds left to each player, and the player whose clock runs
	Clocks       map[int]int64 `json:"clocks,omitempty"`
	ClockRunning *int          `json:"clockRunning,omitempty"`
}

// NewGame makes a game waiting for its players. The board comes when it starts
func NewGame() *Game {
	return &Game{
		config: GameConfig{Ambient: "TAVERN", Pieces: "WOOD", Size: 5, Clock: DefaultClock},
		seats:  make(map[int]Seat),
		state:  NotStarted,
		now:    time.Now,
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

	if g.clocks != nil {
		running := g.running
		status.Clocks = map[int]int64{1: g.left(1).Milliseconds(), 2: g.left(2).Milliseconds()}
		status.ClockRunning = &running
	}

	return status
}

// ChangeConfig sets the clock, the Henneth Annûn rule, or both, which are
// nil when they do not change. It is chosen before the game: by anyone while
// nobody sits, then only by the one player sitting, and by nobody once both
// sit, so the second player always sees the game it is going to play
func (g *Game) ChangeConfig(user ID, clock *int, hennethAnnun *bool) (GameConfig, error) {
	if g.Started() {
		return g.config, refusal{CodeGameStarted, "the game has already started"}
	}

	if len(g.seats) == 2 {
		return g.config, refusal{CodeConfigLocked, "both players sit: the configuration cannot change"}
	}

	for _, seat := range g.seats {
		if seat.UserID != user {
			return g.config, refusal{CodeConfigLocked, "only the player sitting can change the configuration"}
		}
	}

	config := g.config

	if clock != nil {
		if !slices.Contains(Clocks, *clock) {
			return g.config, refusal{CodeBadMessage, fmt.Sprintf("clock has to be one of %v seconds", Clocks)}
		}

		config.Clock = *clock
	}

	if hennethAnnun != nil {
		if *hennethAnnun && config.Size != 5 {
			return g.config, refusal{CodeBadMessage, "the Henneth Annûn rule is only for the 5×5 board"}
		}

		config.HennethAnnun = *hennethAnnun
	}

	g.config = config
	return config, nil
}

// Sit gives the seat to the user. Once the game has started only its owner
// can come back to it, and then rejoined is true
func (g *Game) Sit(user ID, player int, name, color string) (rejoined bool, err error) {
	if err := checkSeat(player); err != nil {
		return false, err
	}

	seat, taken := g.seats[player]

	switch {
	case taken && seat.UserID != user:
		return false, refusal{CodeSeatTaken, "this seat is taken by another user"}
	case g.Started() && taken:
		return true, nil
	case g.Started():
		return false, refusal{CodeGameStarted, "the game has already started"}
	}

	g.seats[player] = Seat{UserID: user, Name: name, Color: color}
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

	delete(g.seats, player)
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

	seat := g.seats[player]
	seat.Ready = ready
	g.seats[player] = seat

	if !g.seats[1].Ready || !g.seats[2].Ready {
		return false, nil
	}

	g.state = Turn1
	g.turn = 1
	g.moves = make([]string, 0)
	g.board = cirya.NewBoard(g.config.Size)

	if g.config.Clock > 0 {
		full := time.Duration(g.config.Clock) * clockUnit
		g.clocks = map[int]time.Duration{1: full, 2: full}
	}

	return true, nil
}

// The time left to the player now, never below 0
func (g *Game) left(player int) time.Duration {
	left := g.clocks[player]

	if player == g.running {
		left -= g.now().Sub(g.since)
	}

	return max(left, 0)
}

// TimeLeft is the time until the running clock ends, and false when no clock runs
func (g *Game) TimeLeft() (time.Duration, bool) {
	if g.running == 0 {
		return 0, false
	}

	return g.left(g.running), true
}

// Timeout ends the game when the running clock has reached 0: the other
// player wins. over tells if it did, and turn is the turn that was not played
func (g *Game) Timeout() (turn int, over bool) {
	if g.running == 0 || g.left(g.running) > 0 {
		return g.turn, false
	}

	g.timeUp(g.running)
	return g.turn, true
}

// The clock of the player has run out
func (g *Game) timeUp(player int) cirya.Result {
	g.clocks[player] = 0
	g.running = 0

	if player == 1 {
		g.state = Win2
	} else {
		g.state = Win1
	}

	return cirya.Result{Over: true, Winner: 3 - player, Condition: cirya.Time}
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

	// A move that comes when the time is over does not count
	if g.clocks != nil && g.running == player && g.left(player) == 0 {
		return g.timeUp(player), nil
	}

	if g.config.HennethAnnun {
		if err := cirya.HennethAnnun(g.turn, move); err != nil {
			return cirya.Result{}, err
		}
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

	// The clocks start once black has played its opening, and then each
	// one runs until its player has played
	if g.clocks != nil {
		if g.running == player {
			g.clocks[player] = g.left(player)
		}

		g.running = 0

		if !result.Over && g.turn >= 2 {
			g.running, g.since = 3-player, g.now()
		}
	}

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

	if seat, ok := g.seats[player]; !ok || seat.UserID != user {
		return refusal{CodeNotYourSeat, "this seat belongs to another user"}
	}

	return nil
}
