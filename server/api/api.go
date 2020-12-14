package api

import (
	"net/http"
	"github.com/gorilla/mux"

	"log"
	"github.com/gorilla/websocket"
)

type Api struct {
	router http.Handler
}

type Server interface {
	Router() http.Handler
}

func New() Server {
	r := mux.NewRouter()
	api := &Api{}
	
	r.HandleFunc("/users", api.SetUser).Methods("PUT")
	r.HandleFunc("/rooms", api.CreateRoom).Methods("PUT")
	r.HandleFunc("/rooms/{room}", api.GetRoomSocket)

	api.router = r

	return api
}

func (a *Api) Router() http.Handler {
	return a.router
}

func (a *Api) SetUser(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func (a *Api) CreateRoom(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

var upgrader = websocket.Upgrader {}

func echo(w http.ResponseWriter, r *http.Request) {
	log.Print("Connection")

	upgrader.CheckOrigin = func(r *http.Request) bool { return true }

	c, err := upgrader.Upgrade(w, r, nil)

	if err != nil { log.Fatal(err) }

	defer c.Close()

	log.Print("Waiting for message...")

	for {
		mt, message, err := c.ReadMessage()
		if err != nil { log.Fatal(err) }

		log.Printf("Message: %s", message)

		err = c.WriteMessage(mt, message)
		if err != nil { log.Fatal(err) }
	}
}
