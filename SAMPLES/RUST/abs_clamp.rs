// abs_clamp.rs - Valeur absolue, ecrêtage, signe
fn abs_i32(x: i32) -> i32 {
    if x < 0 { return 0 - x; }
    return x;
}

fn clamp_i32(x: i32, lo: i32, hi: i32) -> i32 {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

fn sign(x: i32) -> i32 {
    if x > 0 { return 1; }
    if x < 0 { return 0 - 1; }
    return 0;
}

pub fn main() {
    let mut r: i32 = 0;
    r = abs_i32(0 - 42);
    println!("abs(-42) = {}", r);
    r = abs_i32(17);
    println!("abs(17) = {}", r);
    r = clamp_i32(200, 0, 100);
    println!("clamp(200, 0, 100) = {}", r);
    r = clamp_i32(0 - 5, 0, 100);
    println!("clamp(-5, 0, 100) = {}", r);
    r = sign(0 - 7);
    println!("sign(-7) = {}", r);
    r = sign(5);
    println!("sign(5) = {}", r);
    debug_assert!(r);
}
