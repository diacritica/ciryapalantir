package main

import (
	"flag"
	"fmt"
	"log"
	"net/url"
	"net/http"
	"github.com/gorilla/websocket"
)

var user = flag.String("u", "default", "-u [user]")

func main() {
	flag.Parse()
	
	u := url.URL {
		Scheme: "ws",
		Host: "127.0.0.1:3333",
		Path: "rooms/test",
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
		}
	}()

	for {
		var input string

		fmt.Print("> ")

		_, err := fmt.Scanln(&input)

		if err != nil {
			log.Print(err)
			continue
		}

		log.Printf("Sending %s", input)
		err = c.WriteMessage(websocket.TextMessage, []byte(input))
		if err != nil { log.Fatal(err) }

	}
}
