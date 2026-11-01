package api

import (
	"cirya.me/server/internal/app"
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
	"time"
)

type Api struct {
	router http.Handler
}

type Server interface {
	Router() http.Handler
}

// Creates a new user and returns its id
func WriteUserCookie(w http.ResponseWriter) string {
	userId := app.NewUserId()
	cookie := http.Cookie{
		Name:    "cirya-user",
		Value:   string(userId),
		Path:    "/",
		Expires: time.Now().AddDate(1, 0, 0),
	}
	http.SetCookie(w, &cookie)
	return string(userId)
}

func GetUserCookieValue(r *http.Request) (string, error) {
	cookie, err := r.Cookie("cirya-user")

	if err != nil {
		return "", err
	}

	return cookie.Value, nil
}

func UserCookieWrapper(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, err := GetUserCookieValue(r)

		if err != nil {
			WriteUserCookie(w)
		}

		h.ServeHTTP(w, r)
	})
}

func New() Server {
	r := mux.NewRouter()

	api := &Api{}
	fs := http.FileServer(http.Dir("./static"))

	r.HandleFunc("/", api.Index).Methods(http.MethodGet)
	r.PathPrefix("/game").Handler(UserCookieWrapper(http.StripPrefix("/game", fs)))
	r.HandleFunc("/check", api.GetCheck).Methods(http.MethodGet, http.MethodOptions)
	r.HandleFunc("/users", api.SetUser).Methods(http.MethodPut, http.MethodOptions)
	r.HandleFunc("/rooms", api.CreateRoom).Methods(http.MethodPut, http.MethodOptions)
	r.HandleFunc("/rooms/{room}", api.GetRoomSocket).Methods(http.MethodGet, http.MethodPost, http.MethodOptions)
	r.Use(mux.CORSMethodMiddleware(r))

	api.router = r

	return api
}

func (a *Api) Router() http.Handler {
	return a.router
}

func (a *Api) Index(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/game/index.html", http.StatusFound)
}

func (a *Api) CorsHeaders(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cookie")
}

func (a *Api) GetCheck(w http.ResponseWriter, r *http.Request) {
	a.CorsHeaders(w)
	if r.Method == http.MethodOptions {
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("OK: %s", app.RandomCode(6))))
}

func (a *Api) SetUser(w http.ResponseWriter, r *http.Request) {
	a.CorsHeaders(w)
	if r.Method == http.MethodOptions {
		return
	}

	userId, err := GetUserCookieValue(r)

	if err != nil {
		userId = WriteUserCookie(w)
	}

	w.Header().Add("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{ "id": "%s"}`, userId)))
}

func (a *Api) CreateRoom(w http.ResponseWriter, r *http.Request) {
	a.CorsHeaders(w)
	if r.Method == http.MethodOptions {
		return
	}
	w.Header().Add("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	room := app.GetStore().CreateRoom()
	w.Write([]byte(fmt.Sprintf(`{ "id": "%s"}`, room.Id())))
}
