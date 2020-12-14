package api

import (
	"fmt"
	"io"
	"log"
	"net/http"

	"cirya.me/server/internal/app"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

const MSG_TYPE = websocket.TextMessage

func corsHandler(r *http.Request) bool {
	return true
}

func getRoom(r *http.Request) (app.Room, error) {
	vars := mux.Vars(r)
	roomId, ok := vars["room"]

	if !ok {
		// Couldn't find room in parameters
		return nil, fmt.Errorf("Error, couldn't find room in parameters")
	}

	store := app.GetStore()
	result, err := store.Get(app.ID(roomId))

	if err != nil {
		return nil, err
	}

	var room app.Room
	
	if result == nil {
		room = app.NewRoom()
		store.Save(app.ID(roomId), room)
	} else {
		room, ok = result.(app.Room)

		if !ok {
			return nil, fmt.Errorf("Error, stored ID is not a room")
		}
	}

	return room, nil
}

func getUser(r *http.Request) (app.User, error) {
	cookie, err := r.Cookie("cirya-user")

	if err != nil {
		return nil, fmt.Errorf("Error, user not present in cookie")
	}
	
	userId := cookie.Value

	return app.NewUser(userId), nil
}

func (a *Api) GetRoomSocket(w http.ResponseWriter, r *http.Request) {
	upgrader := websocket.Upgrader {}
	upgrader.CheckOrigin = corsHandler

	room, err := getRoom(r)

	if err != nil {
		log.Printf("Problem looking up the room", err)
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(404)
		io.WriteString(w, "Room not found")
		return
	}
	
	user, err := getUser(r)

	if err != nil {
		log.Printf("Problem looking up the user")
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(403)
		io.WriteString(w, "User not allowed")
		return
	}

	c, err := upgrader.Upgrade(w, r, nil);

	if err != nil {
		log.Print("Error on upgrade", err)
		return
	}

	defer c.Close()

	room.AddUser(user)
	defer room.RemoveUser(user)

	finish := make(chan interface{})

	go func () {
		for {
			select {
			case message := <- room.UserMessage(user):
				err = c.WriteMessage(MSG_TYPE, message.Format())

			case _ = <- finish:
				break
			}
		}
	}()

	for {
		_, msg, err := c.ReadMessage()

		if err != nil {
			log.Print("Error reading message.", err)
			finish <- true
			break
		}

		log.Print("Message:", string(msg))
		message := app.ParseMessage(msg)
		message.AddUser(user)
		room.HandleMessage(message)
	}

	////
	

	/*
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
	*/
}


/*
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
*/
