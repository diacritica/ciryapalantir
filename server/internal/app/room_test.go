package app

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func parse(t *testing.T, kind string, params map[string]interface{}) Message {
	data, _ := json.Marshal(map[string]interface{}{"type": kind, "params": params})
	m, err := ParseMessage(data)
	require.NoError(t, err)
	return m
}

// S3: a client that does not read its messages is dropped instead of
// blocking the room for everybody else
func TestSlowClientIsDropped(t *testing.T) {
	r := NewRoom("slow")

	frozen := NewClient(NewUser("frozen"))
	healthy := NewClient(NewUser("healthy"))
	r.Join(frozen)
	r.Join(healthy)

	received := make(chan int)

	go func() {
		n := 0
		for data := range healthy.Send() {
			var msg map[string]interface{}
			json.Unmarshal(data, &msg)
			if msg["type"] == ReadyChanged {
				n++
			}
			if n == 2*sendBuffer {
				received <- n
				return
			}
		}
	}()

	for i := 0; i < 2*sendBuffer; i++ {
		r.Receive(healthy, parse(t, SetReady, map[string]interface{}{"player": 1, "ready": i%2 == 0}))
	}

	select {
	case n := <-received:
		assert.Equal(t, 2*sendBuffer, n)
	case <-time.After(2 * time.Second):
		t.Fatal("room blocked by the frozen client")
	}

	// The frozen client gets what fitted in its buffer and then its channel is closed
	count := 0
	for range frozen.Send() {
		count++
	}
	assert.LessOrEqual(t, count, sendBuffer)
}

// Leaving twice, or after being dropped, is harmless
func TestLeaveIsIdempotent(t *testing.T) {
	r := NewRoom("leave")
	c := NewClient(NewUser("user"))

	r.Join(c)
	r.Leave(c)
	r.Leave(c)

	_, open := <-c.Send()
	for open {
		_, open = <-c.Send()
	}
}
