package api

import (
	"net/http"
	"fmt"
	"cirya.me/server/internal/app"
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

	r.HandleFunc("/check", api.GetCheck).Methods("GET")
	r.HandleFunc("/users", api.SetUser).Methods("PUT")
	r.HandleFunc("/rooms", api.CreateRoom).Methods("PUT")
	r.HandleFunc("/rooms/{room}", api.GetRoomSocket)

	api.router = r

	return api
}

func (a *Api) Router() http.Handler {
	return a.router
}

func (a *Api) GetCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("OK: %s", app.GenerateCode())))
}

func (a *Api) SetUser(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Header().Add("Content-Type", "application/json")
	w.Write([]byte(fmt.Sprintf(`{ "id": "%s"}`, app.GenerateCode())))
}

func (a *Api) CreateRoom(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Header().Add("Content-Type", "application/json")
	w.Write([]byte(fmt.Sprintf(`{ "id": "%s"}`, app.GenerateCode())))
}
