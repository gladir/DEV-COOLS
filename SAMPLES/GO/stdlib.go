package main

import (
	"fmt"
	"strings"
	"strconv"
	"os"
	"math"
	"errors"
)

func Analyze(raw string) (int, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return 0, errors.New("empty input")
	}
	upper := strings.ToUpper(trimmed)
	_ = upper

	n, err := strconv.Atoi(trimmed)
	if err != nil {
		return 0, fmt.Errorf("not a number: %s", trimmed)
	}
	return n, nil
}

func main() {
	fmt.Println("start")

	parts := strings.Split("a,b,c", ",")
	_ = parts
	joined := strings.Join(parts, "-")
	_ = joined

	msg := fmt.Sprintf("joined=%s", joined)
	fmt.Fprintln(os.Stdout, msg)

	r := math.Sqrt(16.0)
	area := math.Pow(r, 2)
	_ = area

	n, err := Analyze(" 42 ")
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
	_ = n

	big := strconv.Itoa(math.MaxInt32)
	_ = big

	args := os.Args
	_ = args

	if math.IsNaN(math.NaN()) {
		fmt.Println("nan")
	}
}
