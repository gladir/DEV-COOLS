// power.rs - Exponentiation entiere
// Demontre : while, multiplication, parametres multiples

fn power(base: i32, exp: i32) -> i32 {
    if exp == 0 {
        return 1;
    }
    let mut result: i32 = 1;
    let mut e: i32 = 0;
    e = exp;
    while e > 0 {
        result = result * base;
        e = e - 1;
    }
    return result;
}

fn power_u(base: u32, exp: u32) -> u32 {
    if exp == 0 {
        return 1;
    }
    let mut result: u32 = 1;
    let mut e: u32 = 0;
    e = exp;
    while e > 0 {
        result = result * base;
        e = e - 1;
    }
    return result;
}

pub fn main() {
    let mut r: i32 = 0;
    r = power(2, 10);   // 1024
    r = power(3, 5);    // 243
    r = power(7, 3);    // 343
    let mut ru: u32 = 0;
    ru = power_u(2, 8); // 256
    debug_assert!(r);
}
