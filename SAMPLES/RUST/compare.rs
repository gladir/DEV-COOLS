// compare.rs - Comparaisons et tri de 3 valeurs
fn cmp_i32(a: i32, b: i32) -> i32 {
    if a < b { return 0 - 1; }
    if a > b { return 1; }
    return 0;
}

fn sort3_median(a: i32, b: i32, c: i32) -> i32 {
    let mut x: i32 = 0;
    let mut y: i32 = 0;
    let mut z: i32 = 0;
    let mut tmp: i32 = 0;
    x = a; y = b; z = c;
    if x > y { tmp = x; x = y; y = tmp; }
    if y > z { tmp = y; y = z; z = tmp; }
    if x > y { tmp = x; x = y; y = tmp; }
    return y;
}

fn sort3_min(a: i32, b: i32, c: i32) -> i32 {
    let mut x: i32 = 0;
    x = a;
    if b < x { x = b; }
    if c < x { x = c; }
    return x;
}

pub fn main() {
    let mut r: i32 = 0;
    r = cmp_i32(5, 10);
    println!("cmp(5, 10) = {}", r);
    r = cmp_i32(10, 5);
    println!("cmp(10, 5) = {}", r);
    r = cmp_i32(7, 7);
    println!("cmp(7, 7) = {}", r);
    r = sort3_median(9, 3, 6);
    println!("median(9, 3, 6) = {}", r);
    r = sort3_min(9, 3, 6);
    println!("min(9, 3, 6) = {}", r);
    r = r + 1;
    debug_assert!(r);
}
