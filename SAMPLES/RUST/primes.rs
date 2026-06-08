// primes.rs - Test de primalite et comptage de nombres premiers
fn is_prime(n: i32) -> bool {
    if n < 2 { return false; }
    if n == 2 { return true; }
    if n % 2 == 0 { return false; }
    let mut d: i32 = 3;
    while d * d <= n {
        if n % d == 0 { return false; }
        d = d + 2;
    }
    return true;
}

fn count_primes(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 2;
    while i <= limit {
        if is_prime(i) { count = count + 1; }
        i = i + 1;
    }
    return count;
}

pub fn main() {
    let mut r: i32 = 0;
    r = count_primes(10);
    println!("premiers <= 10 = {}", r);
    r = count_primes(20);
    println!("premiers <= 20 = {}", r);
    r = count_primes(50);
    println!("premiers <= 50 = {}", r);
    r = count_primes(100);
    println!("premiers <= 100 = {}", r);
    debug_assert!(r);
}
