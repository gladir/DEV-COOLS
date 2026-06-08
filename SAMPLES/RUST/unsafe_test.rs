// unsafe_test.rs - Operations bas-niveau: bits, poids, inversion
fn sum_of_four(a: i32, b: i32, c: i32, d: i32) -> i32 {
    return a + b + c + d;
}

fn max_of_four(a: i32, b: i32, c: i32, d: i32) -> i32 {
    let mut m: i32 = 0;
    m = a;
    if b > m { m = b; }
    if c > m { m = c; }
    if d > m { m = d; }
    return m;
}

fn reverse_bits4(n: i32) -> i32 {
    let mut r: i32 = 0;
    let mut x: i32 = 0;
    let mut bit: i32 = 0;
    let mut i: i32 = 0;
    x = n;
    while i < 4 {
        bit = x & 1;
        r = r * 2 + bit;
        x = x / 2;
        i = i + 1;
    }
    return r;
}

pub fn main() {
    let mut r: i32 = 0;
    r = sum_of_four(1, 2, 3, 4);
    println!("sum(1,2,3,4) = {}", r);
    r = max_of_four(3, 7, 2, 9);
    println!("max(3,7,2,9) = {}", r);
    r = reverse_bits4(3);
    println!("reverse_bits4(3) = {}", r);
    debug_assert!(r);
}
