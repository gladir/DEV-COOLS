// digits.rs - Extraction et manipulation de chiffres
// Demontre : division entiere, modulo, reconstruction de nombres

fn digit_at(n: i32, pos: i32) -> i32 {
    // pos 0 = chiffre des unites
    let mut x: i32 = 0;
    x = n;
    if x < 0 {
        x = 0 - x;
    }
    let mut i: i32 = 0;
    while i < pos {
        x = x / 10;
        i = i + 1;
    }
    return x % 10;
}

fn is_palindrome(n: i32) -> bool {
    let mut x: i32 = 0;
    x = n;
    if x < 0 {
        x = 0 - x;
    }
    let mut rev: i32 = 0;
    let mut tmp: i32 = 0;
    tmp = x;
    while tmp > 0 {
        rev = rev * 10 + tmp % 10;
        tmp = tmp / 10;
    }
    return x == rev;
}

fn sum_of_digits(n: i32) -> i32 {
    let mut x: i32 = 0;
    x = n;
    if x < 0 {
        x = 0 - x;
    }
    let mut s: i32 = 0;
    while x > 0 {
        s = s + x % 10;
        x = x / 10;
    }
    return s;
}

fn digital_root(n: i32) -> i32 {
    let mut x: i32 = 0;
    x = n;
    while x >= 10 {
        x = sum_of_digits(x);
    }
    return x;
}

pub fn main() {
    let mut r: i32 = 0;
    r = digit_at(12345, 0);    // 5
    r = digit_at(12345, 2);    // 3
    r = sum_of_digits(12345);  // 15
    r = digital_root(9999);    // 9
    r = digital_root(493);     // 7
    let mut b: bool = false;
    b = is_palindrome(121);    // true
    b = is_palindrome(123);    // false
    b = is_palindrome(12321);  // true
    debug_assert!(r);
}
