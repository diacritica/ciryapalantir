// Package api serves the HTTP endpoints and the websockets of the rooms
package api

import (
	"encoding/json"
	"net/http"

	"cirya.me/server/internal/app"
	"github.com/gorilla/mux"
)

type server struct {
	store *app.Store
}

// New returns the handler of the whole server:
//
//	GET /              redirects to the game
//	/game/...          the web export of the game, which gives the browser a user
//	GET /check         answers OK while the server is up
//	PUT /users         the user of the cookie, created if needed
//	PUT /rooms         a new room
//	GET /rooms/{code}  the websocket of a room, see doc/Protocol.md
func New(store *app.Store) http.Handler {
	s := &server{store: store}
	r := mux.NewRouter()
	game := http.StripPrefix("/game", http.FileServer(http.Dir("./static")))

	r.HandleFunc("/", s.index).Methods(http.MethodGet)
	r.PathPrefix("/game").Handler(withUser(game))
	r.HandleFunc("/check", cors(s.check)).Methods(http.MethodGet, http.MethodOptions)
	r.HandleFunc("/users", cors(s.user)).Methods(http.MethodPut, http.MethodOptions)
	r.HandleFunc("/rooms", cors(s.createRoom)).Methods(http.MethodPut, http.MethodOptions)
	r.HandleFunc("/rooms/{code}", cors(s.roomSocket)).Methods(http.MethodGet, http.MethodPost, http.MethodOptions)
	r.Use(mux.CORSMethodMiddleware(r))

	return r
}

func (s *server) index(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/game/index.html", http.StatusFound)
}

func (s *server) check(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("OK"))
}

func (s *server) user(w http.ResponseWriter, r *http.Request) {
	user, ok := userOf(r)

	if !ok {
		user = newUser(w)
	}

	writeID(w, user)
}

func (s *server) createRoom(w http.ResponseWriter, r *http.Request) {
	writeID(w, s.store.CreateRoom().Code())
}

func writeID(w http.ResponseWriter, id app.ID) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]app.ID{"id": id})
}
