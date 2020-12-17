package main

import (
	"flag"
	"fmt"
	"log"
	"net/url"
	"net/http"
	"bufio"
	"os"
	"strings"
	"encoding/json"
	//"cirya.me/server/internal/app"
	"github.com/gorilla/websocket"
)

var host = flag.String("h", "127.0.0.1:3333", "-h [host]")
var user = flag.String("u", "default", "-u [user]")
var room = flag.String("r", "test", "-r [room]")

func main() {
	var msg string
	var player int
	var turn int

	flag.Parse()
	
	u := url.URL {
		Scheme: "ws",
		Host: *host,
		Path: fmt.Sprintf("rooms/%s", *room),
	}

	log.Printf("Conecting to %s", u.String())

	header := make(http.Header)
	header["Cookie"] = []string { fmt.Sprintf("cirya-user=%s", *user) }

	c, _, err := websocket.DefaultDialer.Dial(u.String(), header)

	if err != nil {
		log.Fatal("Dialing error ", err)
	}

	defer c.Close()


	go func() {
		for {
			_, message, err := c.ReadMessage()
			if err != nil { log.Print(err) }
			log.Printf("Received %s", message)

			var data struct {
				Params struct {
					NextTurn int `json:"nextTurn"`
				} `json:"params"`
			}
			json.Unmarshal(message, &data)


			if data.Params.NextTurn > 0 {
				turn = data.Params.NextTurn
				log.Printf(">>> Turn: %d", turn)
			}

			//if (data.Params != nil && data.Params.NextTurn != nil) {
			//	turn = *data.Params.NextTurn
			//}
		}
	}()

	scanner := bufio.NewScanner(os.Stdin)

	for scanner.Scan() {
		
		input := scanner.Text()

		switch {
		case input == "status":
			msg = `{"type": "GetStatus"}`

		case input == "join1":
			player = 1
			msg = `{
			  "type": "JoinGame",
        "params": {
          "player": 1,
          "color": "white",
          "name": "Player1"
        }
			}`

		case input == "join2":
			player = 2
			msg = `{
			  "type": "JoinGame",
        "params": {
          "player": 2,
          "color": "black",
          "name": "Player2"
        }
			}`

		case input == "ready":
			msg = fmt.Sprintf(`{
        "type": "SetReady",
        "params": {
          "player": %d,
          "ready": true
        }
      }`, player)

		case strings.HasPrefix(input, "move"):
			args := strings.ReplaceAll(input, "move ", "")
			msg = fmt.Sprintf(`{
        "type": "SubmitTurn",
        "params": {
          "player": %d,
          "turn": %d,
          "move": "%s"
        }
      }`, player, turn, args)

		default:
			fmt.Println("")
			continue
		}

		fmt.Println("Sending:", input)
		err = c.WriteMessage(websocket.TextMessage, []byte(msg))
		if err != nil { log.Fatal(err) }
	}

	if err := scanner.Err(); err != nil {
		os.Exit(1)
	}

}
