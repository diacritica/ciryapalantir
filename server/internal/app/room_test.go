package app

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const waitTimeout = 2 * time.Second

func parse(t *testing.T, kind MessageType, params Params) *Message {
	data, _ := json.Marshal(map[string]any{"type": kind, "params": params})
	m, err := ParseMessage(data)
	require.NoError(t, err)
	return m
}

// The next message of the given type for the client, skipping the others
func expect(t *testing.T, c *Client, kind MessageType) map[string]any {
	t.Helper()
	timeout := time.After(waitTimeout)

	for {
		select {
		case data, ok := <-c.Send():
			require.True(t, ok, "the client was closed waiting for %s", kind)

			var msg map[string]any
			require.NoError(t, json.Unmarshal(data, &msg))

			if msg["type"] == string(kind) {
				return msg
			}

		case <-timeout:
			t.Fatalf("timeout waiting for %s", kind)
		}
	}
}

// How many messages the client still had before the room closed it
func drain(t *testing.T, c *Client) int {
	t.Helper()
	count := 0
	timeout := time.After(waitTimeout)

	for {
		select {
		case _, ok := <-c.Send():
			if !ok {
				return count
			}
			count++

		case <-timeout:
			t.Fatal("the client was never closed")
		}
	}
}

func TestUsersJoinAndLeave(t *testing.T) {
	r := NewRoom("users")
	alice, bob := NewClient("alice"), NewClient("bob")

	r.Join(alice)
	expect(t, alice, StatusResponse)
	r.Join(bob)

	assert.Equal(t, "bob", expect(t, alice, UserJoined)["params"].(map[string]any)["username"])

	r.Leave(bob)
	assert.Equal(t, "bob", expect(t, alice, UserLeft)["params"].(map[string]any)["username"])
}

// A client that does not read its messages is dropped instead of blocking
// the room, and the others hear it left when its connection ends
func TestSlowClientIsDropped(t *testing.T) {
	r := NewRoom("slow")
	frozen, healthy := NewClient("frozen"), NewClient("healthy")

	r.Join(frozen)
	r.Join(healthy)
	r.Receive(healthy, parse(t, JoinGame, Params{"player": 1, "color": "white", "name": "healthy"}))

	// More broadcasts than fit in a client buffer, read by the healthy client one by one
	for i := 0; i < sendBuffer+10; i++ {
		r.Receive(healthy, parse(t, SetReady, Params{"player": 1, "ready": i%2 == 0}))
		expect(t, healthy, ReadyChanged)
	}

	assert.LessOrEqual(t, drain(t, frozen), sendBuffer, "the frozen client got what fitted, then it was closed")

	r.Leave(frozen)
	assert.Equal(t, "frozen", expect(t, healthy, UserLeft)["params"].(map[string]any)["username"])
}

// Leaving twice is harmless and the room keeps working
func TestLeaveIsIdempotent(t *testing.T) {
	r := NewRoom("leave")
	c := NewClient("user")

	r.Join(c)
	r.Leave(c)
	r.Leave(c)
	drain(t, c)

	other := NewClient("other")
	r.Join(other)
	expect(t, other, StatusResponse)
}
