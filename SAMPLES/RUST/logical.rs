// logical.rs - Operations logiques booleennes
fn in_range(x: i32, lo: i32, hi: i32) -> bool {
    return x >= lo && x <= hi;
}

fn leap_year(y: i32) -> bool {
    if y % 400 == 0 { return true; }
    if y % 100 == 0 { return false; }
    return y % 4 == 0;
}

fn bool_to_i32(b: bool) -> i32 {
    if b { return 1; }
    return 0;
}

pub fn main() {
    let mut r: i32 = 0;
    r = bool_to_i32(in_range(5, 1, 10));
    println!("in_range(5, 1, 10) = {}", r);
    r = bool_to_i32(in_range(15, 1, 10));
    println!("in_range(15, 1, 10) = {}", r);
    r = bool_to_i32(leap_year(2000));
    println!("leap_year(2000) = {}", r);
    r = bool_to_i32(leap_year(1900));
    println!("leap_year(1900) = {}", r);
    r = bool_to_i32(leap_year(2024));
    println!("leap_year(2024) = {}", r);
    debug_assert!(r);
}
