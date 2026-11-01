package app

import "sync"

// Store keeps the rooms in memory, by code. A restart loses them
type Store struct {
	mu    sync.Mutex
	rooms map[ID]*Room
}

func NewStore() *Store {
	return &Store{rooms: make(map[ID]*Room)}
}

// Room returns the room with the given code, creating it if needed
func (s *Store) Room(code ID) *Room {
	s.mu.Lock()
	defer s.mu.Unlock()

	r, ok := s.rooms[code]

	if !ok {
		r = NewRoom(code)
		s.rooms[code] = r
	}

	return r
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
