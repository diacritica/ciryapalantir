package app

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// Rooms are made by the store, and an unknown code is no room
func TestStoreFindsOnlyItsRooms(t *testing.T) {
	s := NewStore()
	r := s.CreateRoom()

	found, ok := s.Room(r.Code())
	assert.True(t, ok)
	assert.Same(t, r, found)

	_, ok = s.Room("NOPE00")
	assert.False(t, ok)
}

// A room ends once it has had no clients for long enough, and not before
func TestIdleRoomsEnd(t *testing.T) {
	s := NewStore()
	busy := s.CreateRoom()
	empty := s.CreateRoom()
	alice := NewClient("alice")
	busy.Join(alice)
	expect(t, alice, StatusResponse)

	assert.Equal(t, 0, s.EndIdleRooms(time.Hour), "nothing has been empty for an hour")
	assert.Equal(t, 1, s.EndIdleRooms(0), "the empty room ends, the one with alice stays")

	_, ok := s.Room(empty.Code())
	assert.False(t, ok)
	_, ok = s.Room(busy.Code())
	assert.True(t, ok)

	// When alice leaves, the room counts its time without clients from then
	beforeLeaving := time.Now()
	busy.Leave(alice)
	assert.False(t, busy.EndIfEmptySince(beforeLeaving))
	assert.Equal(t, 1, s.EndIdleRooms(0))
}

// A client that got the room just before it ended is turned away, and
// nothing waits for the ended room
func TestEndedRoomTurnsClientsAway(t *testing.T) {
	r := NewRoom("ended")
	assert.True(t, r.EndIfEmptySince(time.Now()))

	done := make(chan bool)
	go func() {
		c := NewClient("late")
		joined := r.Join(c)
		r.Receive(c, parse(t, GetStatus, nil))
		r.Leave(c)
		done <- joined
	}()

	select {
	case joined := <-done:
		assert.False(t, joined)
	case <-time.After(waitTimeout):
		t.Fatal("a call to an ended room is blocked")
	}

	assert.True(t, r.EndIfEmptySince(time.Now()), "asking again is harmless")
}
