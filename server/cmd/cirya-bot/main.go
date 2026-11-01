// A player for trying the game alone: it sits in a room and, on every turn
// of its seat, places a flat cirya on the first empty square, which is
// always legal. Start the server, create a room in the game and run:
//
//	go run ./cmd/cirya-bot -room KM7Q2X
//
// With -moves it plays those turns first, in order, for scripted games:
//
//	go run ./cmd/cirya-bot -room KM7Q2X -moves b1,Ta4,e5
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

var (
	server = flag.String("server", "127.0.0.1:3333", "host:port of the server")
	room   = flag.String("room", "", "code of the room")
	seat   = flag.Int("seat", 2, "seat to take, 1 (white) or 2 (black)")
	name   = flag.String("name", "Bot", "name shown to the other player")
	moves  = flag.String("moves", "", "turns to play first, separated by commas")
	delay  = flag.Duration("delay", 0, "time to think before every turn")
)

type message struct {
	Type   string         `json:"type"`
	Params map[string]any `json:"params,omitempty"`
	Status *status        `json:"status,omitempty"`
}

type status struct {
	Config struct {
		Size int `json:"size"`
	} `json:"config"`
	Board map[string]map[string][]string `json:"board"`
}

func main() {
	flag.Parse()

	if *room == "" {
		log.Fatal("the code of the room is missing: -room CODE")
	}

	user, err := newUser()
	if err != nil {
		log.Fatal(err)
	}

	header := http.Header{"Cookie": {"cirya-user=" + user}}
	conn, _, err := websocket.DefaultDialer.Dial(fmt.Sprintf("ws://%s/rooms/%s", *server, *room), header)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	color := map[int]string{1: "white", 2: "black"}[*seat]
	send(conn, message{Type: "JoinGame", Params: map[string]any{"player": *seat, "color": color, "name": *name}})
	send(conn, message{Type: "SetReady", Params: map[string]any{"player": *seat, "ready": true}})
	log.Printf("sitting in seat %d of room %s", *seat, *room)
	script := strings.FieldsFunc(*moves, func(r rune) bool { return r == ',' })

	for {
		var m message
		if err := conn.ReadJSON(&m); err != nil {
			log.Fatal(err)
		}

		switch m.Type {
		case "StartGame", "Turn":
			if int(m.Params["nextPlayer"].(float64)) == *seat {
				move := firstEmpty(*m.Status)
				if len(script) > 0 {
					move, script = script[0], script[1:]
				}
				time.Sleep(*delay)
				log.Printf("turn %v: %s", m.Params["nextTurn"], move)
				send(conn, message{Type: "SubmitTurn", Params: map[string]any{"player": *seat, "turn": m.Params["nextTurn"], "move": move}})
			}
		case "InvalidTurn", "Error":
			log.Printf("%s: %v", m.Type, m.Params)
		case "GameFinished":
			log.Printf("game over: %v", m.Params)
			return
		}
	}
}

// The user of the bot, given by the server
func newUser() (string, error) {
	req, _ := http.NewRequest(http.MethodPut, fmt.Sprintf("http://%s/users", *server), nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	var body struct{ ID string }
	err = json.NewDecoder(res.Body).Decode(&body)
	return body.ID, err
}

func send(conn *websocket.Conn, m message) {
	if err := conn.WriteJSON(m); err != nil {
		log.Fatal(err)
	}
}

// The first empty square, rank by rank from a1. The board is full when the
// game would already be over
func firstEmpty(s status) string {
	for rank := 1; rank <= s.Config.Size; rank++ {
		for file := 0; file < s.Config.Size; file++ {
			r, f := fmt.Sprint(rank), string(rune('a'+file))

			if len(s.Board[r][f]) == 0 {
				return f + r
			}
		}
	}

	return ""
}
