package app

import (
	"log"
	"runtime/debug"
	"time"
)

const (
	// Messages waiting for a client before it is considered too slow and dropped
	sendBuffer = 256

	// Messages from the clients waiting for the room
	inboxSize = 256
)

// Client is a websocket connection. A user can have several (two tabs, a reconnection)
type Client struct {
	user ID
	send chan []byte
}

func NewClient(user ID) *Client {
	return &Client{user: user, send: make(chan []byte, sendBuffer)}
}

// Send gives the formatted messages for this client. It is closed when the
// room drops the client
func (c *Client) Send() <-chan []byte {
	return c.send
}

type envelope struct {
	client  *Client
	message *Message
}

// Room owns its clients and its game. Everything that touches them runs in
// the room goroutine, one message after the other, so no locks are needed.
// The room ends when the store finds it without clients for too long
type Room struct {
	code ID
	game *Game
	// False once the room has dropped the client, until it leaves
	clients map[*Client]bool
	// When the last client left, or when the room was made
	emptySince time.Time

	register   chan *Client
	unregister chan *Client
	inbox      chan envelope
	idle       chan idleQuery
	// Closed when the room ends
	done chan struct{}
}

type idleQuery struct {
	since  time.Time
	answer chan bool
}

func NewRoom(code ID) *Room {
	r := &Room{
		code:       code,
		game:       NewGame(),
		clients:    make(map[*Client]bool),
		emptySince: time.Now(),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		inbox:      make(chan envelope, inboxSize),
		idle:       make(chan idleQuery),
		done:       make(chan struct{}),
	}

	go r.run()

	return r
}

func (r *Room) Code() ID {
	return r.code
}

// Join adds the client to the room, which answers with the status. Every
// Join needs a Leave when the connection ends. Join, Leave and Receive
// wait for the room to take them. False when the room has ended
func (r *Room) Join(c *Client) bool {
	select {
	case r.register <- c:
		return true
	case <-r.done:
		return false
	}
}

// Leave takes the client out of the room and closes it. Leaving twice is harmless
func (r *Room) Leave(c *Client) {
	select {
	case r.unregister <- c:
	case <-r.done:
	}
}

// Receive hands an action of the client to the room
func (r *Room) Receive(c *Client, m *Message) {
	select {
	case r.inbox <- envelope{client: c, message: m}:
	case <-r.done:
	}
}

// EndIfEmptySince ends the room when it has had no clients since then, and
// tells whether it did
func (r *Room) EndIfEmptySince(since time.Time) bool {
	q := idleQuery{since: since, answer: make(chan bool, 1)}

	select {
	case r.idle <- q:
		return <-q.answer
	case <-r.done:
		return true
	}
}

func (r *Room) run() {
	for {
		select {
		case c := <-r.register:
			r.clients[c] = true
			r.safely("connect", func() { r.onConnect(c) })

		case q := <-r.idle:
			if len(r.clients) == 0 && !r.emptySince.After(q.since) {
				close(r.done)
				q.answer <- true
				return
			}

			q.answer <- false

		case c := <-r.unregister:
			active, known := r.clients[c]

			if known {
				if active {
					close(c.send)
				}

				delete(r.clients, c)
				r.safely("disconnect", func() { r.onDisconnect(c) })

				if len(r.clients) == 0 {
					r.emptySince = time.Now()
				}
			}

		case e := <-r.inbox:
			r.safely(string(e.message.Type), func() { r.dispatch(e.message, e.client) })
		}
	}
}

// A bug in a handler must not take the room, or the server, down
func (r *Room) safely(what string, handle func()) {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("room %s: panic handling %s: %v\n%s", r.code, what, err, debug.Stack())
		}
	}()

	handle()
}

// Stops sending to a client that cannot keep up. Its connection then ends
// and it leaves the room as any other client
func (r *Room) drop(c *Client) {
	r.clients[c] = false
	close(c.send)
}

func (r *Room) deliver(c *Client, data []byte) {
	select {
	case c.send <- data:
	default:
		log.Printf("room %s: dropping a client of user %s, too slow", r.code, c.user)
		r.drop(c)
	}
}

// Sends a message only to the given client
func (r *Room) reply(c *Client, m *Message) {
	if !r.clients[c] {
		return
	}

	data, err := m.format()

	if err != nil {
		log.Printf("room %s: %v", r.code, err)
		return
	}

	r.deliver(c, data)
}

// Sends a message to every client in the room except the given one, which can be nil
func (r *Room) broadcastExcept(except *Client, m *Message) {
	data, err := m.format()

	if err != nil {
		log.Printf("room %s: %v", r.code, err)
		return
	}

	for c, active := range r.clients {
		if active && c != except {
			r.deliver(c, data)
		}
	}
}

func (r *Room) broadcast(m *Message) {
	r.broadcastExcept(nil, m)
}
