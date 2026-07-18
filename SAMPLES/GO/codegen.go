package main

import "fmt"

// Portee couverte par le generateur de code (TODO 21) : arithmetique/
// comparaisons entieres, if/for classiques, appel direct a une fonction
// utilisateur a un seul resultat, fmt.Println avec un seul argument
// chaine. Volontairement sans retours multiples/structs/slices/maps/
// interfaces/fermetures/switch/for-range/defer (voir TODO 22/23).

func Add(a, b int) int {
	return a + b
}

func Factorial(n int) int {
	result := 1
	for i := 1; i <= n; i++ {
		result = result * i
	}
	return result
}

func Max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	sum := Add(3, 4)
	_ = sum

	fact := Factorial(5)
	_ = fact

	m := Max(10, 20)
	_ = m

	count := 0
	for count < 3 {
		count++
	}
	_ = count

	if m > fact {
		fmt.Println("m plus grand")
	} else {
		fmt.Println("fact plus grand ou egal")
	}
}
