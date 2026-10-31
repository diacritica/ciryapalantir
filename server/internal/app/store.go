package app

import (
	"sync"
)

// Rooms by code, kept in memory
type MemoryStore struct {
	mu    sync.Mutex
	rooms map[ID]Room
}

type Store interface {
	// Returns the room with the given code, creating it if needed
	Room(i ID) Room

	// Creates a room with a new code, not used by any other room
	CreateRoom() Room
}

var store = NewStore()

func GetStore() Store {
	return store
}

func NewStore() Store {
	return &MemoryStore{
		rooms: make(map[ID]Room),
	}
}

func (s *MemoryStore) Room(i ID) Room {
	s.mu.Lock()
	defer s.mu.Unlock()

	r, ok := s.rooms[i]

	if !ok {
		r = NewRoom(i)
		s.rooms[i] = r
	}

	return r
}

func (s *MemoryStore) CreateRoom() Room {
	s.mu.Lock()
	defer s.mu.Unlock()

	for {
		code := RandomCode(roomCodeLength)

		if _, taken := s.rooms[code]; !taken {
			r := NewRoom(code)
			s.rooms[code] = r
			return r
		}
	}
}
