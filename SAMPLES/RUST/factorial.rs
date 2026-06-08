// factorial.rs - Factorielle iterative et recursive
// Demontre : while, multiplication, appels recursifs

fn factorial_iter(n: i32) -> i32 {
    if n <= 1 {
        return 1;
    }
    let mut result: i32 = 1;
    let mut i: i32 = 2;
    while i <= n {
        result = result * i;
        i = i + 1;
    }
    return result;
}

fn factorial_rec(n: i32) -> i32 {
    if n <= 1 {
        return 1;
    }
    return n * factorial_rec(n - 1);
}

pub fn main() {
    let mut r: i32 = 0;
    r = factorial_iter(5);   // 120
    r = factorial_rec(5);    // 120
    r = factorial_iter(7);   // 5040
    debug_assert!(r);
}
