package main

const (
	A = iota
	B
	C
)

func main() {
	x := 42
	hex := 0x2A
	oct := 0o52
	legacy := 052
	bin := 0b101010
	big := 1_000_000
	f := 3.14
	e := 1.5e-3
	dot := .5
	r := 'a'
	nl := '\n'
	s := "hello\tworld"
	raw := `C:\path\no\escapes`
	if x > 0 {
		x++
	} else {
		x--
	}
	ch := make(chan int)
	go func() { ch <- 1 }()
	v := <-ch
	_ = v
	_ = hex
	_ = oct
	_ = legacy
	_ = bin
	_ = big
	_ = f
	_ = e
	_ = dot
	_ = r
	_ = nl
	_ = s
	_ = raw
}
