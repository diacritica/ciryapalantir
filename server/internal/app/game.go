package app

type game struct {
	id ID
}

type Game interface {
	Status() GameStatus
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
	Config GameConfig `json:"config"`
	Players map[string]PlayerStatus `json:"players"`
	State string `json:"state"`
	Moves []string `json:"moves"`
	Board Board `json:"board"`
}

func NewGame(id ID) Game {
	return &game {
		id: id,
	}
}

func (g *game) Status() GameStatus {
	var status GameStatus

	return status
}
