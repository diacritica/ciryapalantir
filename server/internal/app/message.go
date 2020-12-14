package app

type message struct {
	fromUser ID
	data string
}

type Message interface {
	AddUser(u User)
	Format() []byte
}

func ParseMessage(d []byte) Message {
	return &message{ data: string(d) }
}

func (m message) Format() []byte {
	return []byte(m.data)
}

func (m *message) AddUser(u User) {
	m.fromUser = u.Id()
}
