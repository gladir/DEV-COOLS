package main

func CloseResource(name string) {
}

func Divide(a, b int) int {
	return a / b
}

func Safe(a, b int) (result int, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = r.(error)
		}
	}()
	result = Divide(a, b)
	return result, nil
}

func WithCleanup() {
	defer CloseResource("first")
	defer CloseResource("second")
	defer CloseResource("third")
}

func main() {
	WithCleanup()

	r, err := Safe(10, 2)
	_ = r
	_ = err

	r2, err2 := Safe(10, 0)
	_ = r2
	_ = err2
}
