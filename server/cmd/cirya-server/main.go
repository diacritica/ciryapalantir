package main

import (
	"fmt"
	"flag"
	"log"
)

var port = flag.Int("p", 3333, "-p [port]")

func main() {
	flag.Parse()

	address := "0.0.0.0:" + *port

	log.Printf("Starting server ws://%s")

	err := http.ListendAndServe(addr, nil)

	if err != null {
		log.Fatal("Server error", err)
	}
}

// ambientacion, piezas, tamaño de tablero
// codigo tipo kahoot para entrar en partida
// quien crea la sala
// entra con el codigo y on demand
