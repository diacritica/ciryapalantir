package app

import (
	"encoding/json"
	"fmt"
)

type ParamMap map[string]interface{}

type message struct {
	FromUser ID          `json:"user,omitempty"`
	Kind     MessageType `json:"type,omitempty"`
	Params   ParamMap    `json:"params,omitempty"`
	Status   *GameStatus `json:"status,omitempty"`
}

type Message interface {
	Type() MessageType
	User() User
	Format() ([]byte, error)
	Validate() error

	AddUser(u User)
	AddStatus(s GameStatus)

	// Params access
	GetString(param string) (string, error)
	GetInt(param string) (int, error)
	GetBool(param string) (bool, error)
}

// Types
type MessageType string

const (
	Connect      MessageType = "Connect"
	Disconnect               = "Disconnect"
	GetStatus                = "GetStatus"
	ChangeConfig             = "ChangeConfig"
	JoinGame                 = "JoinGame"
	LeaveGame                = "LeaveGame"
	SetReady                 = "SetReady"
	SubmitTurn               = "SubmitTurn"

	// Notifications
	StatusResponse = "StatusResponse"
	ConfigChanged  = "ConfigChanged"
	UserJoined     = "UserJoined"
	UserLeft       = "UserLeft"
	PlayerJoined   = "PlayerJoined"
	PlayerLeft     = "PlayerLeft"
	ReadyChanged   = "ReadyChanged"
	StartGame      = "StartGame"
	Turn           = "Turn"
	GameFinished   = "GameFinished"
	InvalidTurn    = "InvalidTurn"
	Error          = "Error"
)

var MessageTypes = []MessageType{
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
	StartGame,
	Turn,
	GameFinished,
	InvalidTurn,
	Error,
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
	return json.MarshalIndent(m, "", "  ")
}

func (m *message) User() User {
	return &user{
		id: m.FromUser,
	}
}

func (m *message) AddUser(u User) {
	m.FromUser = u.Id()
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
	if m.Kind == "" {
		return fmt.Errorf("No type found in the message")
	}

	// Check that the type is one of the allowed types
	valid := false
	for _, t := range MessageTypes {
		if t == m.Type() {
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

func (m *message) AddStatus(s GameStatus) {
	m.Status = &s
}

func (m *message) GetString(param string) (string, error) {
	val, ok := m.Params[param]

	if !ok {
		return "", fmt.Errorf("Cannot find param %s", param)
	}

	result, ok := val.(string)

	if !ok {
		return "", fmt.Errorf("Parameter %s is not a string", param)
	}

	return result, nil
}

func (m *message) GetInt(param string) (int, error) {
	val, ok := m.Params[param]

	if !ok {
		return 0, fmt.Errorf("Cannot find param %s", param)
	}

	result, ok := val.(float64)

	if !ok {
		return 0, fmt.Errorf("Parameter %s is not a number. Is %s", param, fmt.Sprintf("%T\n", val))
	}

	return int(result), nil
}

func (m *message) GetBool(param string) (bool, error) {
	val, ok := m.Params[param]

	if !ok {
		return false, fmt.Errorf("Cannot find param %s", param)
	}

	result, ok := val.(bool)

	if !ok {
		return false, fmt.Errorf("Parameter %s is not a string", param)
	}

	return result, nil
}
