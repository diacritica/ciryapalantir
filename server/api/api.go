package api

import (
	"net/http"
	"github.com/gorilla/mux"
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
