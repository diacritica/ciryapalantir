package api

import (
	"log"
	"net/http"
	"time"

	"cirya.me/server/internal/app"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the client
	writeWait = 10 * time.Second

	// Time allowed without hearing from the client, pongs included
	pongWait = 60 * time.Second

	// Pings are sent with this period, which has to be less than pongWait
	pingPeriod = pongWait * 9 / 10

	maxMessageSize = 4096
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Connects the user of the cookie to a room made with PUT /rooms
func (s *server) roomSocket(w http.ResponseWriter, r *http.Request) {
	user, ok := userOf(r)

	if !ok {
		http.Error(w, "the cirya-user cookie is missing", http.StatusForbidden)
		return
	}

	room, ok := s.store.Room(app.ID(mux.Vars(r)["code"]))

	if !ok {
		http.Error(w, "there is no room with that code", http.StatusNotFound)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)

	if err != nil {
		log.Print("websocket upgrade: ", err)
		return
	}

	client := app.NewClient(user)

	// The room ended just now, for lack of clients
	if !room.Join(client) {
		conn.Close()
		return
	}

	go writeMessages(conn, client)
	readMessages(conn, room, client)
}

// Hands every message of the client to the room until the connection ends
func readMessages(conn *websocket.Conn, room *app.Room, client *app.Client) {
	defer func() {
		room.Leave(client)
		conn.Close()
	}()

	conn.SetReadLimit(maxMessageSize)
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		_, data, err := conn.ReadMessage()

		if err != nil {
			return
		}

		conn.SetReadDeadline(time.Now().Add(pongWait))
		message, err := app.ParseMessage(data)

		if err != nil {
			log.Print("ignoring a message: ", err)
			continue
		}

		room.Receive(client, message)
	}
}

// Sends the messages of the room to the client and keeps the connection
// alive. Ends when the room drops the client or the connection fails
func writeMessages(conn *websocket.Conn, client *app.Client) {
	ticker := time.NewTicker(pingPeriod)

	defer func() {
		ticker.Stop()
		conn.Close()
	}()

	for {
		select {
		case data, ok := <-client.Send():
			conn.SetWriteDeadline(time.Now().Add(writeWait))

			if !ok {
				conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
				return
			}

		case <-ticker.C:
			conn.SetWriteDeadline(time.Now().Add(writeWait))

			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
