// digits.rs - Extraction et manipulation de chiffres decimaux
fn digit_at(n: i32, pos: i32) -> i32 {
    let mut x: i32 = 0;
    x = n;
    if x < 0 { x = 0 - x; }
    let mut i: i32 = 0;
    while i < pos { x = x / 10; i = i + 1; }
    return x % 10;
}

fn sum_of_digits(n: i32) -> i32 {
    let mut x: i32 = 0;
    x = n;
    if x < 0 { x = 0 - x; }
    let mut s: i32 = 0;
    while x > 0 { s = x % 10 + s; x = x / 10; }
    return s;
}

fn digital_root(n: i32) -> i32 {
    let mut x: i32 = 0;
    x = n;
    while x >= 10 { x = sum_of_digits(x); }
    return x;
}

pub fn main() {
    let mut r: i32 = 0;
    r = digit_at(12345, 0);
    println!("chiffre 0 de 12345 = {}", r);
    r = digit_at(12345, 2);
    println!("chiffre 2 de 12345 = {}", r);
    r = sum_of_digits(12345);
    println!("somme chiffres 12345 = {}", r);
    r = digital_root(9999);
    println!("racine digitale 9999 = {}", r);
    r = digital_root(493);
    println!("racine digitale 493 = {}", r);
    debug_assert!(r);
}
