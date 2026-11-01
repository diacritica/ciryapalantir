package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestFirstEmpty(t *testing.T) {
	s := status{Board: map[string]map[string][]string{"1": {"a": {"C1"}, "b": {"T2"}}}}
	s.Config.Size = 5

	assert.Equal(t, "c1", firstEmpty(s))

	s.Board["1"] = map[string][]string{"a": {"C1"}, "b": {"C1"}, "c": {"C1"}, "d": {"C1"}, "e": {"C1"}}
	assert.Equal(t, "a2", firstEmpty(s), "the next rank when the first is full")
}
