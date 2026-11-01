package cirya

func (b *Board) empty(rankKey string, fileKey string) bool {
	rank, ok := b.Data[rankKey]

	if !ok {
		return true
	}

	file, ok := rank[fileKey]

	if !ok {
		return true
	}

	return len(file) == 0
}

func (b *Board) get(rankKey string, fileKey string) []string {
	rank, ok := b.Data[rankKey]

	if !ok {
		return make([]string, 0)
	}

	file, ok := rank[fileKey]

	if !ok {
		return make([]string, 0)
	}

	return file
}

func (b *Board) set(rankKey string, fileKey string, value []string) {
	rank, ok := b.Data[rankKey]

	if !ok {
		rank = make(map[string][]string)
		b.Data[rankKey] = rank
	}

	file, ok := rank[fileKey]

	if !ok {
		file = make([]string, 0)
		rank[fileKey] = file
	}

	rank[fileKey] = value
}
