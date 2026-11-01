package app

import (
	"log"
	"sync"
	"time"
)

// Store keeps the rooms in memory, by code. A restart loses them, and rooms
// left without clients end after a while
type Store struct {
	mu    sync.Mutex
	rooms map[ID]*Room
}

func NewStore() *Store {
	return &Store{rooms: make(map[ID]*Room)}
}

// Room returns the room with the given code, if there is one
func (s *Store) Room(code ID) (*Room, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	r, ok := s.rooms[code]
	return r, ok
}

// CreateRoom makes a room with a code no other room has
func (s *Store) CreateRoom() *Room {
	s.mu.Lock()
	defer s.mu.Unlock()

	for {
		code := randomCode(roomCodeLength)

		if _, taken := s.rooms[code]; !taken {
			r := NewRoom(code)
			s.rooms[code] = r
			return r
		}
	}
}

// EndIdleRooms ends the rooms that have had no clients for that long, and
// tells how many there were
func (s *Store) EndIdleRooms(idle time.Duration) int {
	s.mu.Lock()
	defer s.mu.Unlock()

	since := time.Now().Add(-idle)
	ended := 0

	for code, r := range s.rooms {
		if r.EndIfEmptySince(since) {
			delete(s.rooms, code)
			ended++
		}
	}

	return ended
}

// EndIdleRoomsEvery looks for idle rooms with that period, for as long as
// the server runs
func (s *Store) EndIdleRoomsEvery(period, idle time.Duration) {
	for range time.Tick(period) {
		if ended := s.EndIdleRooms(idle); ended > 0 {
			log.Printf("ended %d rooms without clients for %s", ended, idle)
		}
	}
}
