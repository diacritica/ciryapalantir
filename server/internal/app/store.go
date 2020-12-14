package app

type Data interface {}

type MemoryStore struct {
	data map[ID]Data
}

type Store interface {
	Save(i ID, d Data) error
	Get(i ID) (Data, error)
}

var store = NewStore()

func GetStore() Store {
	return store
}

func NewStore() Store {
	return &MemoryStore {
		data: make(map[ID]Data),
	}
}

func (s *MemoryStore) Save(i ID, d Data) error {
	s.data[i] = d
	return nil
}

func (s *MemoryStore) Get(i ID) (Data, error){
	value, _ := s.data[i]
	return value, nil
}
