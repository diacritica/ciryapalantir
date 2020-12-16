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

func (a *Api) GetRoomSocket(w http.ResponseWriter, r *http.Request) {
	upgrader := websocket.Upgrader {}
	upgrader.CheckOrigin = corsHandler

	room, err := getRoom(r)

	if err != nil {
		log.Printf("Problem looking up the room", err)
		returnError(w, 404, "Room not found")
		return
	}

	game, err := getGame(room)
	
	if err != nil {
		log.Printf("Problem looking up the game", err)
		returnError(w, 404, "Game not found")
		return
	}

	user, err := getUser(r)

	if err != nil {
		log.Printf("Problem looking up the user")
		returnError(w, 403, "User not allowed")
		return
	}

	c, err := upgrader.Upgrade(w, r, nil);

	if err != nil {
		log.Print("Error on upgrade", err)
		return
	}

	defer c.Close()

	// room.AddUser(user)
	// defer room.RemoveUser(user)

	// Starts a go routine to send messages back to the user
	go SendMessages(c, room, user)

	app.HandleMessage(app.ConnectMessage(user), room, game)
	defer app.HandleMessage(app.DisconnectMessage(user), room, game)

	// Main read loop
	for {
		_, msg, err := c.ReadMessage()

		if err != nil {
			// When the user disconnects we get an error reading
			// log.Print("Error reading message.", err)
			break
		}

		message, err := app.ParseMessage(msg)

		if err != nil {
			log.Print("Cannot parse message:", err)
			// TODO RETURN ERROR TO CLIENT
			continue
		}

		log.Print("Received:", message)
		message.AddUser(user)

		// Delegates to handlers
		app.HandleMessage(message, room, game)
	}
}

func SendMessages(c *websocket.Conn, room app.Room, user app.User) {
	finish := make(chan bool)

	for {
		select {
		case message := <- room.UserMessage(user):
			bmsg, err := message.Format()

			if err != nil {
				log.Print("Error:", err)
				finish <- true
			}

			err = c.WriteMessage(MSG_TYPE, bmsg)

			if err != nil {
				log.Print("Error:", err)
				finish <- true
			}

		case _ = <- finish:
			break
		}
	}
}

func returnError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	io.WriteString(w, msg)
}

func corsHandler(r *http.Request) bool {
	return true
}

/*
   Retrieves a Room given the request
 */
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

func getGame(room app.Room) (app.Game, error){
	gameId := room.CurrentGame()
	store := app.GetStore()
	result, err := store.Get(app.ID(gameId))

	if err != nil {
		return nil, err
	}

	var game app.Game
	
	if result == nil {
		game = app.NewGame(gameId)
		store.Save(app.ID(gameId), game)
	} else {
		var ok bool
		game, ok = result.(app.Game)

		if !ok {
			return nil, fmt.Errorf("Error, stored ID is not a room")
		}
	}

	return game, nil
}

/*
   Extracts a User from the current request
 */
func getUser(r *http.Request) (app.User, error) {
	cookie, err := r.Cookie("cirya-user")

	if err != nil {
		return nil, fmt.Errorf("Error, user not present in cookie")
	}
	
	userId := cookie.Value

	return app.NewUser(userId), nil
}
