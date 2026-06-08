// math.rs - Fonctions arithmetiques: add, mul, abs, div_mod
fn add(a: i32, b: i32) -> i32 { return a + b; }
fn mul(a: i32, b: i32) -> i32 { return a * b; }
fn abs_val(x: i32) -> i32 { if x < 0 { return 0 - x; } return x; }

fn div_mod(a: i32, b: i32, mode: i32) -> i32 {
    if mode == 0 { return a / b; }
    return a % b;
}

pub fn main() {
    let mut r: i32 = 0;
    r = add(10, 20);
    println!("add(10, 20) = {}", r);
    r = mul(6, 7);
    println!("mul(6, 7) = {}", r);
    r = abs_val(0 - 42);
    println!("abs_val(-42) = {}", r);
    r = div_mod(17, 5, 0);
    println!("17 / 5 = {}", r);
    r = div_mod(17, 5, 1);
    println!("17 % 5 = {}", r);
    debug_assert!(r);
}
