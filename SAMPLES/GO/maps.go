package main

func CountWords(words []string) map[string]int {
	counts := make(map[string]int)
	for _, w := range words {
		counts[w] = counts[w] + 1
	}
	return counts
}

func main() {
	ages := map[string]int{"Alice": 30, "Bob": 25}
	ages["Carol"] = 40

	n := ages["Alice"]
	_ = n

	v, ok := ages["Dave"]
	_ = v
	_ = ok

	delete(ages, "Bob")

	total := 0
	for _, age := range ages {
		total = total + age
	}
	_ = total

	words := []string{"a", "b", "a"}
	counts := CountWords(words)
	_ = counts
}
