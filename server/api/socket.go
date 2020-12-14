package api

import (
	"log"
	"io"
	"net/http"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

type Message interface {
	Format() []byte
}

type Room struct {
	id string
	channels map[string]chan Message
}

type message struct {
	data string
}

func ParseMessage(u string, m []byte) Message {
	return message{ data: u + "-" + string(m) }
}

func (m message) Format() []byte {
	return []byte(m.data)
}

var rooms = make(map[string]Room)

const (
	messageType = websocket.TextMessage
)

func (a *Api) GetRoomSocket(w http.ResponseWriter, r *http.Request) {
	upgrader := websocket.Upgrader {}
	upgrader.CheckOrigin = func(r *http.Request) bool { return true }

	vars := mux.Vars(r)
	roomId, ok := vars["room"]

	if !ok {
		// Couldn't find room in parameters
		log.Print("Error, couldn't find room in parameters")
		return
	}

	room, ok := rooms[roomId]

	if !ok {
		// We don't have the room. We create one
		room = Room {
			id: roomId,
			channels: make(map[string]chan Message),
		}

		log.Print("Created room ", roomId)

		rooms[roomId] = room
	}

	var user string
	cookie, err := r.Cookie("cirya-user")

	if err != nil {
		// Cannot find user
		log.Print("Couldn't find user")
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(403)
		io.WriteString(w, "User cookie not present")
		return
	}
	
	user = cookie.Value

	c, err := upgrader.Upgrade(w, r, nil);

	if err != nil {
		log.Print("Error on upgrade", err)
		return
	}

	defer c.Close()

	log.Printf("ROOM %s. User %s", room.id, user)

	userChan := make(chan Message)
	room.SetChannel(user, userChan)

	go func () {
		for {
			message := <-userChan
			log.Print("User:", user, ".", message)
			err = c.WriteMessage(messageType, message.Format())
		}
	}()

	for {
		_, msg, err := c.ReadMessage()

		if err != nil {
			log.Print("Error reading message.", err)
			break
		}

		log.Print("Message:", string(msg))
		message := ParseMessage(user, msg)
		room.Process(message)
	}
}

func (r *Room) SetChannel(u string, ch chan Message) {
	r.channels[u] = ch
}

func (r *Room) Process(m Message) {
	for _, ch := range r.channels {
		ch <- m
	}
}
