package api_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"cirya.me/server/api"
	"cirya.me/server/internal/app"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// How the server behaves with several real websocket clients, speaking
// the protocol of doc/Protocol.md

const waitTimeout = 2 * time.Second

type testClient struct {
	t        *testing.T
	user     string
	conn     *websocket.Conn
	messages chan map[string]interface{}
	// The status the server sends when the client connects
	status map[string]interface{}
}

func newServer(t *testing.T) *httptest.Server {
	s := httptest.NewServer(api.New(app.NewStore()))
	t.Cleanup(s.Close)
	return s
}

// Every server has its own store, so the name of the test is enough
func roomCode(t *testing.T) string {
	return strings.NewReplacer("/", "-", " ", "-").Replace(t.Name())
}

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

	select {
	case msg := <-c.messages:
		if msg["type"] != "StatusResponse" {
			return nil, fmt.Errorf("%s: the first message is %v, not the status", user, msg["type"])
		}
		c.status = msg["status"].(map[string]interface{})
	case <-time.After(waitTimeout):
		return nil, fmt.Errorf("%s: no status after connecting", user)
	}

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

// The messages that arrive before the answer to a GetStatus sent now. The
// room handles the messages of a client in order, so they are all the
// effects of what this client sent before
func (c *testClient) sync() []map[string]interface{} {
	c.t.Helper()
	c.send("GetStatus", nil)

	var before []map[string]interface{}
	timeout := time.After(waitTimeout)

	for {
		select {
		case msg, ok := <-c.messages:
			if !ok {
				c.t.Fatalf("%s: connection closed while syncing", c.user)
			}

			if msg["type"] == "StatusResponse" {
				return before
			}

			before = append(before, msg)

		case <-timeout:
			c.t.Fatalf("%s: timeout while syncing", c.user)
		}
	}
}

func count(messages []map[string]interface{}, kind string) int {
	n := 0

	for _, msg := range messages {
		if msg["type"] == kind {
			n++
		}
	}

	return n
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

func expectError(t *testing.T, c *testClient, code string) {
	t.Helper()
	msg := c.expect("Error")
	assert.Equal(t, code, msg["params"].(map[string]interface{})["code"])
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

// The server answers a connection with the room status
func TestConnectReceivesStatus(t *testing.T) {
	s := newServer(t)
	c := connect(t, s, roomCode(t), "alan")

	assert.Equal(t, "NOT_STARTED", c.status["state"])
}

// Both players getting ready at the same time start the game once
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

		// Once both readies are handled every StartGame has been sent
		black.sync()
		assert.Equal(t, 1, count(white.sync(), "StartGame"), "room %s", room)
	}
}

// Clients connecting at the same time to a new code share one room
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

	join(clients[0], 1, "white")

	for _, c := range clients {
		c.expect("PlayerJoined")
	}
}

// A client that stops reading does not freeze the room for the rest
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

// After clients disconnect the room keeps working for the others
func TestDisconnectedClientDoesNotBreakRoom(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	for i := 0; i < 20; i++ {
		gone := connect(t, s, room, fmt.Sprintf("gone-%d", i))
		gone.conn.Close()
	}

	white := connect(t, s, room, "white")
	black := connect(t, s, room, "black")

	join(white, 1, "white")
	black.expect("PlayerJoined")
}

// A player cannot move for the other one
func TestCannotSubmitTurnForOtherPlayer(t *testing.T) {
	s := newServer(t)
	white, black := startGame(t, s)

	submit(black, 1, 1, "a1")

	expectError(t, black, "NOT_YOUR_SEAT")
	assert.Equal(t, 0, count(white.sync(), "Turn"))
}

// A seat taken by one user cannot be taken by another
func TestCannotTakeOccupiedSeat(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)

	white := connect(t, s, room, "white")
	intruder := connect(t, s, room, "intruder")

	join(white, 1, "white")
	intruder.expect("PlayerJoined")

	join(intruder, 1, "white")
	expectError(t, intruder, "SEAT_TAKEN")
}

// A turn out of order is answered with an error, not ignored
func TestOutOfTurnIsAnswered(t *testing.T) {
	s := newServer(t)
	_, black := startGame(t, s)

	submit(black, 2, 1, "a1")

	expectError(t, black, "NOT_YOUR_TURN")
}

// A malformed move is rejected and the room keeps working
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

	board := black.status["board"].(map[string]interface{})

	// The first move places a cirya of the opponent
	assert.Equal(t, []interface{}{"C2"}, board["1"].(map[string]interface{})["a"])
}

// Two users logging in during the same second get different ids
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

// Rooms created during the same second get different codes
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

// The id in the response is the one stored in the cookie
func TestUserIdMatchesCookie(t *testing.T) {
	s := newServer(t)

	req, _ := http.NewRequest(http.MethodPut, s.URL+"/users", nil)
	res, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer res.Body.Close()

	var body map[string]string
	require.NoError(t, json.NewDecoder(res.Body).Decode(&body))

	cookies := res.Cookies()
	require.Len(t, cookies, 1)
	assert.Equal(t, body["id"], cookies[0].Value)
	assert.Equal(t, "/", cookies[0].Path)
}

// A player who reconnects to a started game keeps the seat and can keep playing
func TestSeatOwnerCanRejoin(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)
	white, black := startGame(t, s)

	white.conn.Close()
	white = connect(t, s, room, white.user)

	join(white, 1, "white")
	white.expect("StatusResponse")

	submit(white, 1, 1, "a1")
	black.expect("Turn")
}

// Nobody can leave a started game, so a seat cannot be freed and stolen
func TestCannotLeaveStartedGame(t *testing.T) {
	s := newServer(t)
	white, _ := startGame(t, s)

	white.send("LeaveGame", map[string]interface{}{"player": 1})
	expectError(t, white, "GAME_STARTED")
}

// Someone without a seat can watch but not play
func TestSpectatorCannotPlay(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)
	white, _ := startGame(t, s)

	spectator := connect(t, s, room, "spectator")

	submit(spectator, 1, 1, "a1")
	expectError(t, spectator, "NOT_YOUR_SEAT")

	join(spectator, 2, "black")
	expectError(t, spectator, "SEAT_TAKEN")

	submit(white, 1, 1, "a1")
	spectator.expect("Turn")
}

// Players have to sit before getting ready, and only in seats 1 and 2
func TestReadyNeedsASeat(t *testing.T) {
	s := newServer(t)
	c := connect(t, s, roomCode(t), "alan")

	ready(c, 1, true)
	expectError(t, c, "NOT_YOUR_SEAT")

	join(c, 3, "white")
	expectError(t, c, "BAD_MESSAGE")
}

// Room codes are short, easy to read and dictate
func TestRoomCodeFormat(t *testing.T) {
	s := newServer(t)

	req, _ := http.NewRequest(http.MethodPut, s.URL+"/rooms", nil)
	res, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer res.Body.Close()

	var body map[string]string
	require.NoError(t, json.NewDecoder(res.Body).Decode(&body))

	assert.Regexp(t, `^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$`, body["id"])
}

// A whole game until white completes a londë along rank 2
func TestFullGameToLonde(t *testing.T) {
	s := newServer(t)
	room := roomCode(t)
	white, black := startGame(t, s)
	spectator := connect(t, s, room, "spectator")

	moves := []string{
		"a5", "e5", // openings: a cirya of the opponent
		"a2", "a4",
		"b2", "b4",
		"c2", "c4",
		"d2", "d4",
	}

	clients := []*testClient{white, black}

	for i, move := range moves {
		player := i%2 + 1
		submit(clients[i%2], player, i+1, move)

		// Every client gets every turn in order, also its own ones
		msg := spectator.expect("Turn")
		assert.Equal(t, float64(i+2), msg["params"].(map[string]interface{})["nextTurn"])
	}

	submit(white, 1, 11, "e2")

	var finished map[string]interface{}

	for _, c := range []*testClient{white, black, spectator} {
		finished = c.expect("GameFinished")
		params := finished["params"].(map[string]interface{})

		assert.Equal(t, "WIN_1", params["result"])
		assert.Equal(t, "LONDI", params["winCondition"])
	}

	// White placed 5 ciryar and black one of white's in the opening; black 4 and white one
	fleets := finished["status"].(map[string]interface{})["fleets"].(map[string]interface{})
	assert.Equal(t, float64(21-6), fleets["1"].(map[string]interface{})["ciryar"])
	assert.Equal(t, float64(21-5), fleets["2"].(map[string]interface{})["ciryar"])

	submit(black, 2, 12, "e4")
	expectError(t, black, "GAME_FINISHED")
}
