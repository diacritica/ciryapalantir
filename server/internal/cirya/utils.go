package cirya

import (
	"fmt"
)

func idx(v string, s []string) int {
	for i, c := range s {
		if c == v {
			return i
		}
	}
	return -1
}

func checkBound(idx int, size int) (int, error) {
	if idx > size {
		return 0, fmt.Errorf("Out of bounds %d > %d", idx, size)
	}
	if idx < 0 {
		return 0, fmt.Errorf("Out of bounds %d < 0", idx)
	}
	return idx, nil
}

func reverse(s []string) []string {
    a := make([]string, len(s))
    copy(a, s)

    for i := len(a)/2 - 1; i >= 0; i-- {
        opp := len(a) - 1 - i
        a[i], a[opp] = a[opp], a[i]
    }

    return a
}

func parsePosition(position string) (string, string) {
	rank := string(position[0])
	file := string(position[1])
	return rank, file
}

func next(rank string, file string, size int, direction MoveDirection) (string, string, error){
	switch direction {
	case UP:
		next, err := checkBound(idx(rank, ranks[:size]) + 1, size)

		if err != nil {
			return rank, file, err
		}
		
		return ranks[next], file, nil
		
	case RIGHT:
		next, err := checkBound(idx(file, files[:size]) + 1, size)


		if err != nil {
			return rank, file, err
		}
		
		return rank, files[next], nil
		
	case DOWN:
		next, err := checkBound(idx(rank, ranks[:size]) - 1, size)

		if err != nil {
			return rank, file, err
		}
		
		return ranks[next], file, nil
		
	case LEFT:
		next, err := checkBound(idx(file, files[:size]) - 1, size)

		if err != nil {
			return rank, file, err
		}
		
		return rank, files[next], nil
	}

	return rank, file, nil
}
