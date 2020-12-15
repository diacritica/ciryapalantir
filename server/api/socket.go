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
	}()

	for {
		_, msg, err := c.ReadMessage()

		if err != nil {
			log.Print("Error reading message.", err)
			// TODO RETURN ERROR TO CLIENT
			continue
		}

		log.Print("Message:", string(msg))
		message, err := app.ParseMessage(msg)

		if err != nil {
			log.Print("Cannot parse message:", err)
			// TODO RETURN ERROR TO CLIENT
			continue
		}

		log.Print("Parsed:", message)
		message.AddUser(user)
		room.HandleMessage(message)
	}
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
