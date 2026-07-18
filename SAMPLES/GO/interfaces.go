package main

type Shape interface {
	Area() float64
	Perimeter() float64
}

type Rectangle struct {
	Width, Height float64
}

func (r Rectangle) Area() float64 {
	return r.Width * r.Height
}

func (r Rectangle) Perimeter() float64 {
	return 2 * (r.Width + r.Height)
}

func Describe(s Shape) float64 {
	return s.Area()
}

func Classify(x any) string {
	switch v := x.(type) {
	case int:
		_ = v
		return "int"
	case string:
		_ = v
		return "string"
	default:
		return "autre"
	}
}

func main() {
	r := Rectangle{Width: 3, Height: 4}
	var s Shape
	s = r
	_ = Describe(s)

	var x any
	x = 42
	v, ok := x.(int)
	_ = v
	_ = ok

	_ = Classify(x)
}
