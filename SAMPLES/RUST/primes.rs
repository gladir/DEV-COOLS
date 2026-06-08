// primes.rs - Test de primalite et comptage de premiers
// Demontre : while, modulo, booleen, fonctions imbriquees

fn is_prime(n: i32) -> bool {
    if n < 2 {
        return false;
    }
    if n == 2 {
        return true;
    }
    if n % 2 == 0 {
        return false;
    }
    let mut d: i32 = 3;
    while d * d <= n {
        if n % d == 0 {
            return false;
        }
        d = d + 2;
    }
    return true;
}

fn count_primes(limit: i32) -> i32 {
    let mut count: i32 = 0;
    let mut i: i32 = 2;
    while i <= limit {
        if is_prime(i) {
            count = count + 1;
        }
        i = i + 1;
    }
    return count;
}

pub fn main() {
    let mut r: i32 = 0;
    r = count_primes(10);   // 4  (2,3,5,7)
    r = count_primes(20);   // 8
    r = count_primes(50);   // 15
    let mut b: bool = false;
    b = is_prime(97);       // true
    debug_assert!(r);
}
