package main

import (
	"fmt"
	"flag"
	"log"
	"net/http"

	"cirya.me/server/api"
)

var port = flag.Int("p", 3333, "-p [port]")

func main() {
	flag.Parse()

	addr := fmt.Sprintf("0.0.0.0:%d", *port)

	log.Printf("Starting server %s", addr)

	s := api.New()

	err := http.ListenAndServe(addr, s.Router())

	if err != nil {
		log.Fatal("Server error", err)
	}
}
