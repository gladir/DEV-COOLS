// bitops.rs - Operations sur les bits (&, |, ^)
fn count_bits(n: i32) -> i32 {
    let mut x: i32 = 0;
    let mut count: i32 = 0;
    x = n;
    while x != 0 {
        count = (x & 1) + count;
        x = x / 2;
    }
    return count;
}

fn low_nibble(n: i32) -> i32 {
    return n & 15;
}

fn high_nibble(n: i32) -> i32 {
    let mut tmp: i32 = 0;
    tmp = n / 16;
    return tmp & 15;
}

fn toggle_bit(n: i32, pos: i32) -> i32 {
    let mut mask: i32 = 1;
    let mut i: i32 = 0;
    while i < pos { mask = mask * 2; i = i + 1; }
    return n ^ mask;
}

pub fn main() {
    let mut r: i32 = 0;
    r = count_bits(255);
    println!("count_bits(255) = {}", r);
    r = count_bits(170);
    println!("count_bits(170) = {}", r);
    r = low_nibble(171);
    println!("low_nibble(0xAB) = {}", r);
    r = high_nibble(171);
    println!("high_nibble(0xAB) = {}", r);
    r = toggle_bit(0, 3);
    println!("toggle_bit(0, 3) = {}", r);
    debug_assert!(r);
}
