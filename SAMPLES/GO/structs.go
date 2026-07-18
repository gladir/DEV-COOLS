package main

type Point struct {
	X, Y int
}

type Animal struct {
	Nom string
}

func (a *Animal) Parler() string {
	return a.Nom
}

type Chien struct {
	Animal
	Race string
}

func (c Chien) Race2() string {
	return c.Race
}

func Distance(p1, p2 *Point) int {
	dx := p2.X - p1.X
	dy := p2.Y - p1.Y
	return dx*dx + dy*dy
}

func main() {
	p := Point{X: 1, Y: 2}
	c := Chien{Race: "Labrador"}
	c.Nom = "Rex"
	_ = p
	_ = c
	_ = c.Parler()
	_ = c.Race2()
	_ = Distance(&p, &p)
}
