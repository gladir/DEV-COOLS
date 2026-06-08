// power.rs - Exponentiation entiere
fn power(base: i32, exp: i32) -> i32 {
    if exp == 0 { return 1; }
    let mut result: i32 = 1;
    let mut e: i32 = 0;
    e = exp;
    while e > 0 {
        result = result * base;
        e = e - 1;
    }
    return result;
}

pub fn main() {
    let mut r: i32 = 0;
    r = power(2, 10);
    println!("power(2, 10) = {}", r);
    r = power(3, 5);
    println!("power(3, 5) = {}", r);
    r = power(7, 3);
    println!("power(7, 3) = {}", r);
    r = power(10, 4);
    println!("power(10, 4) = {}", r);
    debug_assert!(r);
}
