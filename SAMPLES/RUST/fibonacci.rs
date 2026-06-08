// fibonacci.rs - Suite de Fibonacci iterative
fn fibonacci(n: i32) -> i32 {
    if n <= 0 { return 0; }
    if n == 1 { return 1; }
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
    println!("fibonacci(0) = {}", r);
    r = fibonacci(1);
    println!("fibonacci(1) = {}", r);
    r = fibonacci(2);
    println!("fibonacci(2) = {}", r);    
    r = fibonacci(3);
    println!("fibonacci(3) = {}", r);    
    r = fibonacci(6);
    println!("fibonacci(6) = {}", r);
    r = fibonacci(10);
    println!("fibonacci(10) = {}", r);
    debug_assert!(r);
}
