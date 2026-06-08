// bitops.rs - Operations sur les bits
// Demontre : &, |, ^, masques de bits

fn count_bits(n: u32) -> u32 {
    let mut x: u32 = 0;
    let mut count: u32 = 0;
    x = n;
    while x != 0 {
        count = count + (x & 1);
        x = x / 2;
    }
    return count;
}

fn is_power_of_two(n: u32) -> bool {
    if n == 0 {
        return false;
    }
    return (n & (n - 1)) == 0;
}

fn low_nibble(n: u8) -> u8 {
    return n & 15;
}

fn high_nibble(n: u8) -> u8 {
    return (n / 16) & 15;
}

pub fn main() {
    let mut r: u32 = 0;
    r = count_bits(255);       // 8
    r = count_bits(170);       // 4  (10101010)
    let mut b: bool = false;
    b = is_power_of_two(64);   // true
    b = is_power_of_two(63);   // false
    let mut lo: u8 = 0;
    lo = low_nibble(0xAB);     // 0x0B = 11
    let mut hi: u8 = 0;
    hi = high_nibble(0xAB);    // 0x0A = 10
    r = count_bits(0);
    r = count_bits(255) + 1;
    debug_assert!(r);
}
