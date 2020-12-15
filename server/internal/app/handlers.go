package app

import (
	"log"
)

func HandleMessage(m Message, r Room, g Game) {
	switch m.Type() {
	case Connect:
		go DoConnect(m, r, g)
		
	case Disconnect:
		go DoDisconnect(m, r, g)
		
	case GetStatus:
		go DoGetStatus(m, r, g)
		
	case ChangeConfig:
		go DoChangeConfig(m, r, g)
		
	case JoinGame:
		go DoJoinGame(m, r, g)

	case LeaveGame:
		go DoLeaveGame(m, r, g)

	case SetReady:
		go DoSetReady(m, r, g)
		
	case SubmitTurn:
		go DoSubmitTurn(m, r, g)

	default:
		log.Printf("Cannot handle message %s", m.Type())
	}
}

func DoConnect(m Message, r Room, g Game) {
	user := m.User()
	r.AddUser(user)

	msg := UserJoinedMessage(user)
	r.Broadcast(msg)
}

func DoDisconnect(m Message, r Room, g Game) {
	user := m.User()
	r.RemoveUser(user)

	msg := UserLeftMessage(user)
	r.Broadcast(msg)
}

func DoGetStatus(m Message, r Room, g Game) {
	user := m.User()
	r.UserMessage(user) <- StatusResponseMessage(g)
}

func DoChangeConfig(m Message, r Room, g Game) {
	log.Print("DoChangeConfig")
}

func DoJoinGame(m Message, r Room, g Game) {
	log.Print("DoJoinGame")
}

func DoLeaveGame(m Message, r Room, g Game) {
	log.Print("DoLeaveGame")
}

func DoSetReady(m Message, r Room, g Game) {
	log.Print("DoSetReady")
}

func DoSubmitTurn(m Message, r Room, g Game) {
	log.Print("DoSubmitTurn")
}
