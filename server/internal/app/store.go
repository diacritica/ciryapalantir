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
