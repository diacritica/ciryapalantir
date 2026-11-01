package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	"cirya.me/server/api"
	"cirya.me/server/internal/app"
)

var port = flag.Int("p", 3333, "port to listen on")

func main() {
	flag.Parse()
	addr := fmt.Sprintf("0.0.0.0:%d", *port)

	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, api.New(app.NewStore())))
}
