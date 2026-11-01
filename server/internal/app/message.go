package app

import (
	"encoding/json"
	"fmt"
)

// Message is what travels on the websocket, in both directions, as JSON.
// doc/Protocol.md describes every type and its params
type Message struct {
	Type   MessageType `json:"type,omitempty"`
	Params Params      `json:"params,omitempty"`
	Status *GameStatus `json:"status,omitempty"`
}

type Params map[string]any

type MessageType string

// Actions, sent by the clients
const (
	GetStatus    MessageType = "GetStatus"
	ChangeConfig MessageType = "ChangeConfig"
	JoinGame     MessageType = "JoinGame"
	LeaveGame    MessageType = "LeaveGame"
	SetReady     MessageType = "SetReady"
	SubmitTurn   MessageType = "SubmitTurn"
)

// Notifications, sent by the server
const (
	StatusResponse MessageType = "StatusResponse"
	UserJoined     MessageType = "UserJoined"
	UserLeft       MessageType = "UserLeft"
	PlayerJoined   MessageType = "PlayerJoined"
	PlayerLeft     MessageType = "PlayerLeft"
	ReadyChanged   MessageType = "ReadyChanged"
	StartGame      MessageType = "StartGame"
	Turn           MessageType = "Turn"
	GameFinished   MessageType = "GameFinished"
	InvalidTurn    MessageType = "InvalidTurn"
	Error          MessageType = "Error"
)

var actions = map[MessageType]bool{
	GetStatus: true, ChangeConfig: true, JoinGame: true, LeaveGame: true, SetReady: true, SubmitTurn: true,
}

// ParseMessage reads an action sent by a client
func ParseMessage(data []byte) (*Message, error) {
	var m Message

	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}

	if !actions[m.Type] {
		return nil, fmt.Errorf("%q is not an action", m.Type)
	}

	return &m, nil
}

func (m *Message) Format() ([]byte, error) {
	return json.MarshalIndent(m, "", "  ")
}

func (m *Message) String() string {
	data, err := m.Format()

	if err != nil {
		return "cannot format message: " + err.Error()
	}

	return string(data)
}

func (m *Message) stringParam(name string) (string, error) {
	value, ok := m.Params[name].(string)

	if !ok {
		return "", fmt.Errorf("param %s has to be a string", name)
	}

	return value, nil
}

// JSON numbers arrive as float64
func (m *Message) intParam(name string) (int, error) {
	value, ok := m.Params[name].(float64)

	if !ok {
		return 0, fmt.Errorf("param %s has to be a number", name)
	}

	return int(value), nil
}

func (m *Message) boolParam(name string) (bool, error) {
	value, ok := m.Params[name].(bool)

	if !ok {
		return false, fmt.Errorf("param %s has to be a boolean", name)
	}

	return value, nil
}
