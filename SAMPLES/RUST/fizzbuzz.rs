// fizzbuzz.rs - Variante numerique de FizzBuzz
// Demontre : modulo, conditions imbriquees, accumulation

fn fizzbuzz_value(n: i32) -> i32 {
    if n % 15 == 0 {
        return 3;   // FizzBuzz
    }
    if n % 3 == 0 {
        return 1;   // Fizz
    }
    if n % 5 == 0 {
        return 2;   // Buzz
    }
    return 0;
}

fn count_fizz(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        let mut v: i32 = 0;
        v = fizzbuzz_value(i);
        if v == 1 {
            count = count + 1;
        }
        i = i + 1;
    }
    return count;
}

fn count_buzz(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        let mut v: i32 = 0;
        v = fizzbuzz_value(i);
        if v == 2 {
            count = count + 1;
        }
        i = i + 1;
    }
    return count;
}

pub fn main() {
    let mut r: i32 = 0;
    r = fizzbuzz_value(15);  // 3
    r = fizzbuzz_value(9);   // 1
    r = fizzbuzz_value(10);  // 2
    r = fizzbuzz_value(7);   // 0
    r = count_fizz(30);      // 8
    r = count_buzz(30);      // 4
    r = r + 1;
    debug_assert!(r);
}
