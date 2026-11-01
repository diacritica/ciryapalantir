package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"

	"cirya.me/server/api"
	"cirya.me/server/internal/app"
)

var (
	port = flag.Int("p", 3333, "port to listen on")
	idle = flag.Duration("idle", time.Hour, "time a room can stay without clients before it ends")
)

func main() {
	flag.Parse()
	addr := fmt.Sprintf("0.0.0.0:%d", *port)

	store := app.NewStore()
	go store.EndIdleRoomsEvery(time.Minute, *idle)

	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, api.New(store)))
}
