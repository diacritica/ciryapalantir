package app

type Game struct {
	id ID
}

type PlayerStatus struct {
	name string
	color string
	ready bool
}

type GameConfig struct {
	ambient string
	pieces string
	size int
}

// Board format
type Board map[string]map[string][]string

type GameStatus struct {
	config GameConfig
	players map[string]PlayerStatus
	state string
	moves []string
	board Board
}
