// fibonacci.rs - Suite de Fibonacci iterative
// Demontre : while, variables locales, retour de valeur i32

fn fibonacci(n: i32) -> i32 {
    if n <= 0 {
        return 0;
    }
    if n == 1 {
        return 1;
    }
    let mut a: i32 = 0;
    let mut b: i32 = 1;
    let mut tmp: i32 = 0;
    let mut i: i32 = 2;
    while i <= n {
        tmp = a + b;
        a = b;
        b = tmp;
        i = i + 1;
    }
    return b;
}

pub fn main() {
    let mut r: i32 = 0;
    r = fibonacci(0);
    r = fibonacci(1);
    r = fibonacci(6);   // 8
    r = fibonacci(10);  // 55
    debug_assert!(r);
}
