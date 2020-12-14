package store

import (
	"fmt"
)

type ID string

type Data interface {}

type MemoryStore {
	data map[ID]Data
}

type Store interface {
	Save(i ID, d Data) Error
	Get(i ID) (Data, Error)
}

func New() Store {
	return &MemoryStore {}
}

func (s *MemoryStore) Save(i ID, d Data) Error {
	s.data[i] = Data
	return nil
}

func (s *MemoryStore) Get(i ID) (Data, Error){
	value, ok := s.data[i]

	if !ok {
		return nil, fmt.Errorf("Key not found")
	}

	return (value, nil)
}
