package main

import "fmt"

type Shape interface {
	Area() int
}

type Square struct {
	Side int
}

func (s Square) Area() int {
	return s.Side * s.Side
}

// "main" reference Describe et Parse AVANT leur declaration textuelle -
// illegal en Pascal (ordre textuel obligatoire), legal en Go entre
// declarations de haut niveau (TODO 19 : passe prealable de signatures).
func main() {
	n, err := Parse("42")
	if err != nil {
		fmt.Println("erreur")
	}
	_ = n

	var sh Shape
	sh = Square{Side: 4}
	fmt.Println(Describe(sh))
}

func Describe(s Shape) string {
	if s.Area() > 0 {
		return "forme non vide"
	}
	return "forme vide"
}

func Parse(s string) (int, error) {
	return 42, nil
}
