package app

import (
	"log"
	"runtime/debug"
)

// Messages waiting for a client before it is considered too slow and dropped
const sendBuffer = 256

// A websocket connection. A user can have several (two tabs, a reconnection)
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

// A room owns its clients and its game. Everything that touches them runs in
// the room goroutine, one message after the other, so no locks are needed.
// Rooms live as long as the server: nothing removes them yet
type Room struct {
	code    ID
	game    *Game
	clients map[*Client]bool

	register   chan *Client
	unregister chan *Client
	inbox      chan envelope
}

func NewRoom(code ID) *Room {
	r := &Room{
		code:       code,
		game:       NewGame(),
		clients:    make(map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		inbox:      make(chan envelope, sendBuffer),
	}

	go r.run()

	return r
}

func (r *Room) Code() ID {
	return r.code
}

func (r *Room) Join(c *Client) {
	r.register <- c
}

func (r *Room) Leave(c *Client) {
	r.unregister <- c
}

func (r *Room) Receive(c *Client, m *Message) {
	r.inbox <- envelope{client: c, message: m}
}

func (r *Room) run() {
	for {
		select {
		case c := <-r.register:
			r.clients[c] = true
			r.safely("connect", func() { r.onConnect(c) })

		case c := <-r.unregister:
			if r.clients[c] {
				r.drop(c)
				r.safely("disconnect", func() { r.onDisconnect(c) })
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

func (r *Room) drop(c *Client) {
	delete(r.clients, c)
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

	data, err := m.Format()

	if err != nil {
		log.Printf("room %s: %v", r.code, err)
		return
	}

	r.deliver(c, data)
}

// Sends a message to every client in the room except the given one, which can be nil
func (r *Room) broadcastExcept(except *Client, m *Message) {
	data, err := m.Format()

	if err != nil {
		log.Printf("room %s: %v", r.code, err)
		return
	}

	for c := range r.clients {
		if c != except {
			r.deliver(c, data)
		}
	}
}

func (r *Room) broadcast(m *Message) {
	r.broadcastExcept(nil, m)
}
