package app

import (
	"fmt"
	"encoding/json"
)

type message struct {
	User ID `json:"user"`
	Kind string `json:"type"`
	Status GameStatus `json:"status"`
	Params map[string]interface{} `json:"params"`
}

type Message interface {
	Type() MessageType
	AddUser(u User)
	Format() ([]byte, error)
	Get(param string) (interface{}, error)
	Validate() error
}

func ParseMessage(data []byte) (Message, error) {
	var result message
	err := json.Unmarshal(data, &result)

	if err != nil {
		return nil, err
	}

	err = result.Validate()

	if err != nil {
		return nil, err
	}
	
	return &result, err
}

func (m *message) Type() MessageType {
	return MessageType(m.Kind)
}

func (m *message) Format() ([]byte, error) {
	return json.Marshal(m)
}

func (m *message) AddUser(u User) {
	m.User = u.Id()
}

func (m *message) Get(param string) (interface{}, error) {
	if m.Params == nil {
		return nil, fmt.Errorf("Message doesn't have parameters")
	}

	result, ok := m.Params[param]

	if !ok {
		return nil, fmt.Errorf("Message have parameters but key not found")
	}

	return result, nil
}

func (m *message) Validate() error {
	if m.Type == nil {
		return fmt.Errorf("No type found in the message")
	}

	// Check that the type is one of the allowed types
	valid := false
	for _, t := range MessageTypes {
		if (t == m.Type()) {
			valid = true
			break
		}
	}

	if !valid {
		return fmt.Errorf("Type %s is not valid type", m.Type())
	}

	return nil
}

func (m *message) String() string {
	ret, err := m.Format()

	if err != nil {
		return "Cannot format object " + err.Error()
	}

	return string(ret)
}

// Types
type MessageType string

const (
	Connect MessageType = "Connect"
	Disconnect = "Disconnect"
	GetStatus = "GetStatus"
	ChangeConfig = "ChangeConfig"
	JoinGame = "JoinGame"
	LeaveGame = "LeaveGame"
	SetReady = "SetReady"
	SubmitTurn = "SubmitTurn"

	// Notifications
	StatusResponse = "StatusResponse"
	ConfigChanged = "ConfigChanged"
	UserJoined = "UserJoined"
	UserLeft = "UserLeft"
	PlayerJoined = "PlayerJoined"
	PlayerLeft = "PlayerLeft"
	ReadyChanged = "ReadyChanged"
	Turn = "Turn"
	GameFinished = "GameFinished"
)

var MessageTypes = []MessageType {
	Connect,
	Disconnect,
	GetStatus,
	ChangeConfig,
	JoinGame,
	LeaveGame,
	SetReady,
	SubmitTurn,
	StatusResponse,
	ConfigChanged,
	UserJoined,
	UserLeft,
	PlayerJoined,
	PlayerLeft,
	ReadyChanged,
	Turn,
	GameFinished,
}


