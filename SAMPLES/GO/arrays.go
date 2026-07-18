package main

func Sum(nums []int) int {
	total := 0
	for _, v := range nums {
		total = total + v
	}
	return total
}

func main() {
	var fixed [5]int
	fixed[0] = 1
	fixed[1] = 2

	s := make([]int, 3, 10)
	s[0] = 10
	s = append(s, 42)

	lit := []int{1, 2, 3}
	grid := [2][2]int{}

	n := len(s)
	c := cap(s)
	total := Sum(lit)

	_ = fixed
	_ = grid
	_ = n
	_ = c
	_ = total
}
