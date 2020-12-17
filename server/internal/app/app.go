package app

import (
	"time"
	"github.com/speps/go-hashids"
)

type ID string

func GenerateCode() ID {
	t := time.Now().Unix()

	hd := hashids.NewData()
	hd.Alphabet = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789"
	hd.MinLength = 5
	hd.Salt = "cirya"
	
	h, _ := hashids.NewWithData(hd)

	result, _ := h.EncodeInt64([]int64 { t })

	return ID(result)
}
