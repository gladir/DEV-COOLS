// collatz.rs - Conjecture de Collatz (suite de Syracuse)
fn collatz_steps(n: i32) -> i32 {
    let mut x: i32 = 0;
    let mut steps: i32 = 0;
    x = n;
    while x != 1 {
        if x % 2 == 0 { x = x / 2; } else { x = 3 * x + 1; }
        steps = steps + 1;
    }
    return steps;
}

fn collatz_max_n(limit: i32) -> i32 {
    let mut best: i32 = 0;
    let mut best_n: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        let mut s: i32 = 0;
        s = collatz_steps(i);
        if s > best { best = s; best_n = i; }
        i = i + 1;
    }
    return best_n;
}

pub fn main() {
    let mut r: i32 = 0;
    r = collatz_steps(6);
    println!("collatz_steps(6) = {}", r);
    r = collatz_steps(27);
    println!("collatz_steps(27) = {}", r);
    r = collatz_max_n(20);
    println!("plus long <= 20 : n = {}", r);
    r = collatz_max_n(100);
    println!("plus long <= 100 : n = {}", r);
    debug_assert!(r);
}
