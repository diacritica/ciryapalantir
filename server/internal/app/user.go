package app

type user struct {
	id ID
}

type User interface {
	Id() ID
}

func NewUser(id string) User {
	return &user{
		id: ID(id),
	}
}

func (u *user) Id() ID {
	return u.id
}
