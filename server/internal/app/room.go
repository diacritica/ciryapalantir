package app

type room struct {
	id ID
	game ID
	channels map[ID]chan Message
}

type Room interface {
	CurrentGame() ID

	// Users
	AddUser(u User)
	RemoveUser(u User)

	// Messaging
	UserMessage(u User) chan Message
	Broadcast(m Message)
}

func NewRoom() Room {
	return &room {
		id: "ROOM",
		game: "GAME",
		channels: make(map[ID]chan Message),
	}
}

func (r *room) AddUser(u User) {
	ch := make(chan Message)
	r.channels[u.Id()] = ch
}

func (r *room) RemoveUser(u User) {
	// TODO: Send a `FINISH` signal?
	delete(r.channels, u.Id())
}

func (r *room) UserMessage(u User) chan Message {
	return r.channels[u.Id()]
}

func (r *room) Broadcast(m Message) {
	for _, ch := range r.channels {
		ch <- m
	}
}

func (r *room) CurrentGame() ID {
	return r.game
}
