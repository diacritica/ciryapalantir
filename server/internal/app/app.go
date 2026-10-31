package app

import (
	"crypto/rand"
	"math/big"
)

type ID string

// Without characters that are easy to confuse (0/O, 1/I/L)
const codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

const (
	userIdLength   = 16
	roomCodeLength = 6
)

func RandomCode(length int) ID {
	max := big.NewInt(int64(len(codeAlphabet)))
	code := make([]byte, length)

	for i := range code {
		n, err := rand.Int(rand.Reader, max)

		if err != nil {
			panic(err)
		}

		code[i] = codeAlphabet[n.Int64()]
	}

	return ID(code)
}

func NewUserId() ID {
	return RandomCode(userIdLength)
}
