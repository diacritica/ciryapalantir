package api

import (
	"net/http"
	"time"

	"cirya.me/server/internal/app"
)

const userCookie = "cirya-user"

// Gives the browser a new user, kept in a cookie for a year
func newUser(w http.ResponseWriter) app.ID {
	user := app.NewUserID()

	http.SetCookie(w, &http.Cookie{
		Name:    userCookie,
		Value:   string(user),
		Path:    "/",
		Expires: time.Now().AddDate(1, 0, 0),
	})

	return user
}

func userOf(r *http.Request) (app.ID, bool) {
	cookie, err := r.Cookie(userCookie)

	if err != nil {
		return "", false
	}

	return app.ID(cookie.Value), true
}

// The browser gets a user before loading the game
func withUser(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := userOf(r); !ok {
			newUser(w)
		}

		h.ServeHTTP(w, r)
	})
}
