package api

import "net/http"

// The game can call the server from any origin: the editor, a native build
// or another host. Preflight requests stop here
func cors(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Cookie")

		if r.Method == http.MethodOptions {
			return
		}

		h(w, r)
	}
}
