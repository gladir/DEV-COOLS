// minmax.rs - Minimum, maximum, mediane
fn min2(a: i32, b: i32) -> i32 { if a < b { return a; } return b; }
fn max2(a: i32, b: i32) -> i32 { if a > b { return a; } return b; }
fn min3(a: i32, b: i32, c: i32) -> i32 { return min2(a, min2(b, c)); }
fn max3(a: i32, b: i32, c: i32) -> i32 { return max2(a, max2(b, c)); }

fn median3(a: i32, b: i32, c: i32) -> i32 {
    let mut mn: i32 = 0;
    let mut mx: i32 = 0;
    mn = min3(a, b, c);
    mx = max3(a, b, c);
    return a + b + c - mn - mx;
}

fn clamp(x: i32, lo: i32, hi: i32) -> i32 {
    return max2(lo, min2(x, hi));
}

pub fn main() {
    let mut r: i32 = 0;
    r = min2(7, 3);
    println!("min2(7, 3) = {}", r);
    r = max2(7, 3);
    println!("max2(7, 3) = {}", r);
    r = median3(5, 2, 8);
    println!("median3(5, 2, 8) = {}", r);
    r = median3(1, 9, 5);
    println!("median3(1, 9, 5) = {}", r);
    r = clamp(15, 0, 10);
    println!("clamp(15, 0, 10) = {}", r);
    r = clamp(7, 0, 10);
    println!("clamp(7, 0, 10) = {}", r);
    debug_assert!(r);
}
