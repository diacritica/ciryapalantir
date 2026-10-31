package api_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"cirya.me/server/api"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// These tests describe how the server must behave with several real
// websocket clients. Each one reproduces a bug found while reviewing
// the server (see HACKATHON.md, S1-S9).

const waitTimeout = 2 * time.Second

type testClient struct {
	t        *testing.T
	user     string
	conn     *websocket.Conn
	messages chan map[string]interface{}
}

func newServer(t *testing.T) *httptest.Server {
	s := httptest.NewServer(api.New().Router())
	t.Cleanup(s.Close)
	return s
}

var rooms int64

// Every test uses its own room code because the store is global,
// also when running the tests several times (-count)
func roomCode(t *testing.T) string {
	if code, ok := codes[t]; ok {
		return code
	}

	name := strings.NewReplacer("/", "-", " ", "-").Replace(t.Name())
	codes[t] = fmt.Sprintf("%s-%d", name, atomic.AddInt64(&rooms, 1))

	return codes[t]
}

var codes = make(map[*testing.T]string)

func connect(t *testing.T, s *httptest.Server, room string, user string) *testClient {
	c, err := dial(t, s, room, user)
	require.NoError(t, err)
	return c
}

// Safe to call from other goroutines: returns the error instead of failing
func dial(t *testing.T, s *httptest.Server, room string, user string) (*testClient, error) {
	url := "ws" + strings.TrimPrefix(s.URL, "http") + "/rooms/" + room

	header := make(http.Header)
	header.Set("Cookie", "cirya-user="+user)

	conn, _, err := websocket.DefaultDialer.Dial(url, header)

	if err != nil {
		return nil, err
	}

	c := &testClient{
		t:        t,
		user:     user,
		conn:     conn,
		messages: make(chan map[string]interface{}, 100000),
	}

	go func() {
		for {
			_, data, err := conn.ReadMessage()

			if err != nil {
				close(c.messages)
				return
			}

			var msg map[string]interface{}

			if json.Unmarshal(data, &msg) == nil {
				c.messages <- msg
			}
		}
	}()

	t.Cleanup(func() { conn.Close() })

	return c, nil
}

func (c *testClient) send(kind string, params map[string]interface{}) {
	msg := map[string]interface{}{"type": kind}

	if params != nil {
		msg["params"] = params
	}

	data, _ := json.Marshal(msg)
	require.NoError(c.t, c.conn.WriteMessage(websocket.TextMessage, data))
}

// Waits for a message of the given type, skipping any other
func (c *testClient) expect(kind string) map[string]interface{} {
	c.t.Helper()
	timeout := time.After(waitTimeout)

	for {
		select {
		case msg, ok := <-c.messages:
			if !ok {
				c.t.Fatalf("%s: connection closed waiting for %s", c.user, kind)
			}

			if msg["type"] == kind {
				return msg
			}

		case <-timeout:
			c.t.Fatalf("%s: timeout waiting for %s", c.user, kind)
		}
	}
}

// Counts the messages of the given type received during the given time
func (c *testClient) count(kind string, during time.Duration) int {
	n := 0
	timeout := time.After(during)

	for {
		select {
		case msg, ok := <-c.messages:
			if !ok {
				return n
			}

			if msg["type"] == kind {
				n++
			}

		case <-timeout:
			return n
		}
	}
}

func join(c *testClient, player int, color string) {
	c.send("JoinGame", map[string]interface{}{
		"player": player,
		"color":  color,
		"name":   c.user,
	})
}

func ready(c *testClient, player int, isReady bool) {
	c.send("SetReady", map[string]interface{}{
		"player": player,
		"ready":  isReady,
	})
}

func submit(c *testClient, player int, turn int, move string) {
	c.send("SubmitTurn", map[string]interface{}{
		"player": player,
		"turn":   turn,
		"move":   move,
	})
}

// Two players seated and ready, game started
func startGame(t *testing.T, s *httptest.Server) (*testClient, *testClient) {
	room := roomCode(t)
	white := connect(t, s, room, "white-"+room)
	black := connect(t, s, room, "black-"+room)

	join(white, 1, "white")
	black.expect("PlayerJoined")
	join(black, 2, "black")
	white.expect("PlayerJoined")

	ready(white, 1, true)
	black.expect("ReadyChanged")
	ready(black, 2, true)

	white.expect("StartGame")
	black.expect("StartGame")

	return white, black
}

// S9: Protocol.md says the server answers a connection with the room status
func TestConnectReceivesStatus(t *testing.T) {
	s := newServer(t)
	c := connect(t, s, roomCode(t), "alan")

	c.expect("StatusResponse")
}

// S1: both players getting ready at the same time must start the game once
func TestSimultaneousReadyStartsGameOnce(t *testing.T) {
	s := newServer(t)

	for i := 0; i < 20; i++ {
		room := fmt.Sprintf("%s-%d", roomCode(t), i)
		white := connect(t, s, room, "white-"+room)
		black := connect(t, s, room, "black-"+room)

		join(white, 1, "white")
		join(black, 2, "black")
		white.expect("PlayerJoined")
		white.expect("PlayerJoined")

		var wg sync.WaitGroup
		wg.Add(2)
		go func() { defer wg.Done(); ready(white, 1, true) }()
		go func() { defer wg.Done(); ready(black, 2, true) }()
		wg.Wait()

		assert.Equal(t, 1, white.count("StartGame", 300*time.Millisecond), "room %s", room)
	}
}

// S4 and S2: clients connecting at the same time to a new code share one room
func TestConcurrentConnectionsShareRoom(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	clients := make([]*testClient, 50)
	errs := make([]error, 50)
	var wg sync.WaitGroup

	for i := range clients {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			clients[i], errs[i] = dial(t, s, room, fmt.Sprintf("user-%d", i))
		}(i)
	}

	wg.Wait()

	for _, err := range errs {
		require.NoError(t, err)
	}

	time.Sleep(200 * time.Millisecond)

	join(clients[0], 1, "white")

	for _, c := range clients {
		c.expect("PlayerJoined")
	}
}

// S3: a client that stops reading must not freeze the room for the rest
func TestSlowClientDoesNotFreezeRoom(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	white := connect(t, s, room, "white")
	black := connect(t, s, room, "black")

	// Connects but never reads anything
	url := "ws" + strings.TrimPrefix(s.URL, "http") + "/rooms/" + room
	header := make(http.Header)
	header.Set("Cookie", "cirya-user=frozen")
	frozen, _, err := websocket.DefaultDialer.Dial(url, header)
	require.NoError(t, err)
	defer frozen.Close()

	join(white, 1, "white")
	black.expect("PlayerJoined")

	// Enough broadcasts to fill the TCP buffers of the frozen client
	const total = 20000
	go func() {
		for i := 0; i < total; i++ {
			ready(white, 1, i%2 == 0)

			// A short pause now and then so healthy clients can keep up
			if i%200 == 0 {
				time.Sleep(time.Millisecond)
			}
		}
	}()

	received := 0
	timeout := time.After(10 * time.Second)

	for received < total {
		select {
		case msg, ok := <-black.messages:
			require.True(t, ok, "connection closed")
			if msg["type"] == "ReadyChanged" {
				received++
			}
		case <-timeout:
			t.Fatalf("room frozen: black received %d of %d messages", received, total)
		}
	}
}

// S2: after a client disconnects the room keeps working for the others
func TestDisconnectedClientDoesNotBreakRoom(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	for i := 0; i < 20; i++ {
		gone := connect(t, s, room, fmt.Sprintf("gone-%d", i))
		gone.conn.Close()
	}

	white := connect(t, s, room, "white")
	black := connect(t, s, room, "black")
	time.Sleep(100 * time.Millisecond)

	join(white, 1, "white")
	black.expect("PlayerJoined")
}

// S7: a player cannot move for the other one
func TestCannotSubmitTurnForOtherPlayer(t *testing.T) {
	s := newServer(t)
	white, black := startGame(t, s)

	submit(black, 1, 1, "a1")

	black.expect("Error")
	assert.Equal(t, 0, white.count("Turn", 300*time.Millisecond))
}

// S7: a seat taken by one user cannot be taken by another
func TestCannotTakeOccupiedSeat(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	white := connect(t, s, room, "white")
	intruder := connect(t, s, room, "intruder")

	join(white, 1, "white")
	intruder.expect("PlayerJoined")

	join(intruder, 1, "white")
	intruder.expect("Error")
}

// S9: a turn out of order is answered with an error, not ignored
func TestOutOfTurnIsAnswered(t *testing.T) {
	s := newServer(t)
	_, black := startGame(t, s)

	submit(black, 2, 1, "a1")

	black.expect("Error")
}

// S6: a malformed move is rejected and the room keeps working
func TestMalformedMoveKeepsServerAlive(t *testing.T) {
	s := newServer(t)
	white, black := startGame(t, s)

	submit(white, 1, 1, "a1")
	black.expect("Turn")
	submit(black, 2, 2, "e5")
	white.expect("Turn")

	// One stone in a1 but asks to drop 9
	submit(white, 1, 3, "a1+9")
	white.expect("InvalidTurn")

	submit(white, 1, 3, "b2")
	black.expect("Turn")
}

// A player who reconnects gets the whole board back
func TestReconnectRestoresBoard(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)
	white, black := startGame(t, s)

	submit(white, 1, 1, "a1")
	black.expect("Turn")

	black.conn.Close()
	black = connect(t, s, room, black.user)

	msg := black.expect("StatusResponse")
	status := msg["status"].(map[string]interface{})
	board := status["board"].(map[string]interface{})

	assert.Equal(t, []interface{}{"C1"}, board["1"].(map[string]interface{})["a"])
}

// S5: two users logging in during the same second get different ids
func TestUsersGetDistinctIds(t *testing.T) {
	s := newServer(t)
	ids := make(map[string]bool)

	for i := 0; i < 10; i++ {
		req, _ := http.NewRequest(http.MethodPut, s.URL+"/users", nil)
		res, err := http.DefaultClient.Do(req)
		require.NoError(t, err)

		var body map[string]string
		require.NoError(t, json.NewDecoder(res.Body).Decode(&body))
		res.Body.Close()

		assert.False(t, ids[body["id"]], "repeated id %s", body["id"])
		ids[body["id"]] = true
	}
}

// S5: rooms created during the same second get different codes
func TestRoomsGetDistinctCodes(t *testing.T) {
	s := newServer(t)
	codes := make(map[string]bool)

	for i := 0; i < 10; i++ {
		req, _ := http.NewRequest(http.MethodPut, s.URL+"/rooms", nil)
		res, err := http.DefaultClient.Do(req)
		require.NoError(t, err)

		var body map[string]string
		require.NoError(t, json.NewDecoder(res.Body).Decode(&body))
		res.Body.Close()

		assert.False(t, codes[body["id"]], "repeated code %s", body["id"])
		codes[body["id"]] = true
	}
}
