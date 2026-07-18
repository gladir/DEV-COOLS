package main

const Pi = 3.14159

const (
	Sunday = iota
	Monday
	Tuesday
)

var count int
var name string
var ok bool = true
var ptr *int
var ratio float64

func main() {
	var b byte
	var r rune
	var u uint32
	var e error
	var x any
	n := len(name)
	s := make([]int, 0)
	if ok == true {
		count = n
	}
	_ = b
	_ = r
	_ = u
	_ = e
	_ = x
	_ = s
	_ = ptr
	_ = ratio
	_ = nil
}
