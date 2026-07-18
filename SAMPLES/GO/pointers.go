package main

type Animal struct {
	Nom string
}

func (a *Animal) Parler() string {
	return a.Nom
}

func Zero() *int {
	return new(int)
}

func SumArrPtr(p *[3]int) int {
	total := 0
	for _, v := range p {
		total = total + v
	}
	return total
}

func main() {
	x := 42
	p := &x
	*p = 100

	pp := &p
	**pp = 200

	a := new(Animal)
	a.Nom = "Rex"
	_ = a.Parler()

	arr := [3]int{1, 2, 3}
	pa := &arr
	_ = pa[0]
	s := pa[1:2]
	_ = s

	total := SumArrPtr(&arr)
	_ = total

	z := Zero()
	if z == nil {
		z = &x
	}
	_ = z
}
