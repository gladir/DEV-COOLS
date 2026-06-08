// factorial.rs - Factorielle iterative et recursive
fn factorial_iter(n: i32) -> i32 {
    if n <= 1 { return 1; }
    let mut result: i32 = 1;
    let mut i: i32 = 2;
    while i <= n {
        result = result * i;
        i = i + 1;
    }
    return result;
}

fn factorial_rec(n: i32) -> i32 {
    if n <= 1 { return 1; }
    let mut sub: i32 = 0;
    sub = factorial_rec(n - 1);
    return n * sub;
}

pub fn main() {
    let mut r: i32 = 0;
    r = factorial_iter(5);
    println!("factorial_iter(5) = {}", r);
    r = factorial_rec(5);
    println!("factorial_rec(5) = {}", r);
    r = factorial_iter(7);
    println!("factorial_iter(7) = {}", r);
    r = factorial_rec(10);
    println!("factorial_rec(10) = {}", r);
    debug_assert!(r);
}
