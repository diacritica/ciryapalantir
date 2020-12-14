package app

type room struct {
	id ID
	channels map[ID]chan Message
}

type Room interface {
	AddUser(u User)
	RemoveUser(u User)
	UserMessage(u User) chan Message
	Broadcast(m Message)
	HandleMessage(m Message)
}

func NewRoom() Room {
	return &room {
		id: "ROOM",
		channels: make(map[ID]chan Message),
	}
}

func (r *room) HandleMessage(m Message) {
	r.Broadcast(m)
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
