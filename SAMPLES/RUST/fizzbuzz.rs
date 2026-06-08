// fizzbuzz.rs - Variante numerique de FizzBuzz (0=normal, 1=Fizz, 2=Buzz, 3=FizzBuzz)
fn fizzbuzz_value(n: i32) -> i32 {
    if n % 15 == 0 { return 3; }
    if n % 3 == 0 { return 1; }
    if n % 5 == 0 { return 2; }
    return 0;
}

fn count_fizz(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        if fizzbuzz_value(i) == 1 { count = count + 1; }
        i = i + 1;
    }
    return count;
}

fn count_buzz(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        if fizzbuzz_value(i) == 2 { count = count + 1; }
        i = i + 1;
    }
    return count;
}

fn count_fizzbuzz(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        if fizzbuzz_value(i) == 3 { count = count + 1; }
        i = i + 1;
    }
    return count;
}

pub fn main() {
    let mut r: i32 = 0;
    r = count_fizz(30);
    println!("Fizz <= 30 = {}", r);
    r = count_buzz(30);
    println!("Buzz <= 30 = {}", r);
    r = count_fizzbuzz(30);
    println!("FizzBuzz <= 30 = {}", r);
    r = fizzbuzz_value(15);
    println!("fizzbuzz_value(15) = {}", r);
    debug_assert!(r);
}
