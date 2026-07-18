package main

func CountRunes(s string) int {
	n := 0
	for range s {
		n = n + 1
	}
	return n
}

func main() {
	s := "hello"
	t := s + " world"
	n := len(t)
	eq := s == "hello"

	var r rune = 'e'
	accent := 'é'
	kanji := '日'

	bs := []byte(s)
	rs := []rune(s)
	back := string(bs)
	back2 := string(rs)

	raw := `C:\path\to\file`

	x := 3.14
	i := int(x)
	f := float64(i)

	count := CountRunes(s)

	_ = n
	_ = eq
	_ = r
	_ = accent
	_ = kanji
	_ = back
	_ = back2
	_ = raw
	_ = f
	_ = count
}
