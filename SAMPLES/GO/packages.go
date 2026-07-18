package main

import (
	"fmt"
	"strings"
	"strconv"
	"os"
	"math"
	"errors"
)

func Compute(x float64) float64 {
	return math.Sqrt(x)
}

func Parse(s string) (int, error) {
	if strings.TrimSpace(s) == "" {
		return 0, errors.New("empty input")
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return 0, err
	}
	return n, nil
}

func main() {
	fmt.Println("start")

	r := Compute(4.0)
	_ = r

	n, err := Parse("42")
	if err != nil {
		os.Exit(1)
	}
	_ = n
}
