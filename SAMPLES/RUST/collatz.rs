// collatz.rs - Conjecture de Collatz (suite de Syracuse)
// Demontre : while, modulo, branchement conditionnel

fn collatz_steps(n: i32) -> i32 {
    let mut x: i32 = 0;
    let mut steps: i32 = 0;
    x = n;
    while x != 1 {
        if x % 2 == 0 {
            x = x / 2;
        } else {
            x = 3 * x + 1;
        }
        steps = steps + 1;
    }
    return steps;
}

fn collatz_max(limit: i32) -> i32 {
    let mut best: i32 = 0;
    let mut best_n: i32 = 0;
    let mut i: i32 = 1;
    while i <= limit {
        let mut s: i32 = 0;
        s = collatz_steps(i);
        if s > best {
            best = s;
            best_n = i;
        }
        i = i + 1;
    }
    return best_n;
}

pub fn main() {
    let mut r: i32 = 0;
    r = collatz_steps(6);    // 8
    r = collatz_steps(27);   // 111
    r = collatz_max(20);     // 18 (97 steps)
    debug_assert!(r);
}
