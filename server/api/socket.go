package api

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"cirya.me/server/internal/app"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

const MSG_TYPE = websocket.TextMessage

const (
	// Time allowed to write a message to the client
	writeWait = 10 * time.Second

	// Time allowed without hearing from the client (pongs included)
	pongWait = 60 * time.Second

	// Pings are sent with this period, it must be less than pongWait
	pingPeriod = (pongWait * 9) / 10

	maxMessageSize = 4096
)

func (a *Api) GetRoomSocket(w http.ResponseWriter, r *http.Request) {
	a.CorsHeaders(w)

	if r.Method == http.MethodOptions {
		return
	}
	upgrader := websocket.Upgrader{}
	upgrader.CheckOrigin = corsHandler

	room, err := getRoom(r)

	if err != nil {
		log.Printf("Problem looking up the room: %v", err)
		returnError(w, 404, "Room not found")
		return
	}

	user, err := getUser(r)

	if err != nil {
		log.Printf("Problem looking up the user")
		returnError(w, 403, "User not allowed")
		return
	}

	c, err := upgrader.Upgrade(w, r, nil)

	if err != nil {
		log.Print("Error on upgrade", err)
		return
	}

	client := app.NewClient(user)
	room.Join(client)

	go SendMessages(c, client)
	ReadMessages(c, room, client)
}

// Main read loop. Delegates every message to the room
func ReadMessages(c *websocket.Conn, room *app.Room, client *app.Client) {
	defer func() {
		room.Leave(client)
		c.Close()
	}()

	c.SetReadLimit(maxMessageSize)
	c.SetReadDeadline(time.Now().Add(pongWait))
	c.SetPongHandler(func(string) error {
		c.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, msg, err := c.ReadMessage()

		if err != nil {
			// When the user disconnects we get an error reading
			break
		}

		c.SetReadDeadline(time.Now().Add(pongWait))

		message, err := app.ParseMessage(msg)

		if err != nil {
			log.Print("Cannot parse message:", err)
			// TODO RETURN ERROR TO CLIENT
			continue
		}

		room.Receive(client, message)
	}
}

// Sends the room messages back to the user and keeps the connection alive.
// Ends when the room drops the client or the connection fails.
func SendMessages(c *websocket.Conn, client *app.Client) {
	ticker := time.NewTicker(pingPeriod)

	defer func() {
		ticker.Stop()
		c.Close()
	}()

	for {
		select {
		case msg, ok := <-client.Send():
			c.SetWriteDeadline(time.Now().Add(writeWait))

			if !ok {
				c.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.WriteMessage(MSG_TYPE, msg); err != nil {
				log.Print("Error:", err)
				return
			}

		case <-ticker.C:
			c.SetWriteDeadline(time.Now().Add(writeWait))

			if err := c.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
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
func getRoom(r *http.Request) (*app.Room, error) {
	vars := mux.Vars(r)
	roomId, ok := vars["room"]

	if !ok {
		// Couldn't find room in parameters
		return nil, fmt.Errorf("Error, couldn't find room in parameters")
	}

	return store.Room(app.ID(roomId)), nil
}

/*
Extracts a User from the current request
*/
func getUser(r *http.Request) (app.ID, error) {
	userId, err := GetUserCookieValue(r)

	if err != nil {
		return "", fmt.Errorf("Error, user not present in cookie")
	}

	return app.ID(userId), nil
}
