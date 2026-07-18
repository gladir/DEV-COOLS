package main

func Worker(ch chan int, done chan bool) {
	ch <- 42
	done <- true
}

func main() {
	ch := make(chan int, 1)
	done := make(chan bool)

	go Worker(ch, done)

	v := <-ch
	_ = v

	v2, ok := <-ch
	_ = v2
	_ = ok

	select {
	case r := <-done:
		_ = r
	case ch <- 1:
	default:
	}

	close(ch)
	close(done)
}
