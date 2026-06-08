// recursion.rs - Algorithmes recursifs classiques
fn sum_digits(n: i32) -> i32 {
    if n < 0 { return sum_digits(0 - n); }
    if n < 10 { return n; }
    let mut d: i32 = 0;
    let mut rest: i32 = 0;
    d = n % 10;
    rest = sum_digits(n / 10);
    return d + rest;
}

fn power10(e: i32) -> i32 {
    if e <= 0 { return 1; }
    let mut sub: i32 = 0;
    sub = power10(e - 1);
    return 10 * sub;
}

fn count_digits(n: i32) -> i32 {
    if n < 0 { return count_digits(0 - n); }
    if n < 10 { return 1; }
    let mut sub: i32 = 0;
    sub = count_digits(n / 10);
    return 1 + sub;
}

fn ackermann(m: i32, n: i32) -> i32 {
    if m == 0 { return n + 1; }
    if n == 0 {
        let mut m1: i32 = 0;
        m1 = m - 1;
        return ackermann(m1, 1);
    }
    let mut inner: i32 = 0;
    let mut m1: i32 = 0;
    inner = ackermann(m, n - 1);
    m1 = m - 1;
    return ackermann(m1, inner);
}

pub fn main() {
    let mut r: i32 = 0;
    r = sum_digits(12345);
    println!("sum_digits(12345) = {}", r);
    r = count_digits(9999);
    println!("count_digits(9999) = {}", r);
    r = power10(3);
    println!("power10(3) = {}", r);
    r = ackermann(2, 3);
    println!("ackermann(2, 3) = {}", r);
    r = ackermann(3, 2);
    println!("ackermann(3, 2) = {}", r);
    debug_assert!(r);
}
