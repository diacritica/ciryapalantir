package app

import (
	"log"
	"runtime/debug"
)

// Messages waiting for a client before it is considered too slow and dropped
const sendBuffer = 256

// A websocket connection. A user can have several (two tabs, a reconnection)
type Client struct {
	user User
	send chan []byte
}

func NewClient(u User) *Client {
	return &Client{
		user: u,
		send: make(chan []byte, sendBuffer),
	}
}

func (c *Client) User() User {
	return c.user
}

// Formatted messages for this client. Closed when the room drops the client
func (c *Client) Send() <-chan []byte {
	return c.send
}

type envelope struct {
	client  *Client
	message Message
}

// A room owns its clients and its game. Everything that touches them runs
// in the room goroutine, one message after the other, so no locks are needed.
type room struct {
	id      ID
	game    Game
	clients map[*Client]bool

	register   chan *Client
	unregister chan *Client
	inbox      chan envelope
}

type Room interface {
	Id() ID
	Join(c *Client)
	Leave(c *Client)
	Receive(c *Client, m Message)
}

func NewRoom(id ID) Room {
	r := &room{
		id:         id,
		game:       NewGame(RandomCode(8)),
		clients:    make(map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		inbox:      make(chan envelope, 256),
	}

	go r.run()

	return r
}

func (r *room) Id() ID {
	return r.id
}

func (r *room) Join(c *Client) {
	r.register <- c
}

func (r *room) Leave(c *Client) {
	r.unregister <- c
}

func (r *room) Receive(c *Client, m Message) {
	r.inbox <- envelope{client: c, message: m}
}

func (r *room) run() {
	for {
		select {
		case c := <-r.register:
			r.clients[c] = true
			r.handle(ConnectMessage(c.user), c)

		case c := <-r.unregister:
			if r.clients[c] {
				r.drop(c)
				r.handle(DisconnectMessage(c.user), c)
			}

		case e := <-r.inbox:
			r.handle(e.message, e.client)
		}
	}
}

// A bug in a handler must not take the room, or the server, down
func (r *room) handle(m Message, c *Client) {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Room %s: panic handling %s: %v\n%s", r.id, m.Type(), err, debug.Stack())
		}
	}()

	HandleMessage(m, r, c)
}

func (r *room) drop(c *Client) {
	delete(r.clients, c)
	close(c.send)
}

func (r *room) deliver(c *Client, data []byte) {
	select {
	case c.send <- data:
	default:
		log.Printf("Room %s: dropping client of user %s, too slow", r.id, c.user.Id())
		r.drop(c)
	}
}

// Sends a message only to the given client
func (r *room) Reply(c *Client, m Message) {
	if !r.clients[c] {
		return
	}

	data, err := m.Format()

	if err != nil {
		log.Print("Error:", err)
		return
	}

	r.deliver(c, data)
}

// Sends a message to every client in the room except the given one (can be nil)
func (r *room) BroadcastExcept(except *Client, m Message) {
	data, err := m.Format()

	if err != nil {
		log.Print("Error:", err)
		return
	}

	for c := range r.clients {
		if c != except {
			r.deliver(c, data)
		}
	}
}

func (r *room) Broadcast(m Message) {
	r.BroadcastExcept(nil, m)
}
