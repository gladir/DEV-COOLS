// logical.rs - Operations logiques booleennes
// Demontre : &&, ||, !, comparaisons composees

fn in_range(x: i32, lo: i32, hi: i32) -> bool {
    return x >= lo && x <= hi;
}

fn is_even(n: i32) -> bool {
    return n % 2 == 0;
}

fn is_divisible(n: i32, d: i32) -> bool {
    return n % d == 0;
}

fn leap_year(y: i32) -> bool {
    if is_divisible(y, 400) {
        return true;
    }
    if is_divisible(y, 100) {
        return false;
    }
    return is_divisible(y, 4);
}

fn any_true(a: bool, b: bool, c: bool) -> bool {
    return a || b || c;
}

fn all_true(a: bool, b: bool, c: bool) -> bool {
    return a && b && c;
}

pub fn main() {
    let mut b: bool = false;
    b = in_range(5, 1, 10);    // true
    b = in_range(15, 1, 10);   // false
    b = is_even(42);           // true
    b = leap_year(2000);       // true
    b = leap_year(1900);       // false
    b = leap_year(2024);       // true
    b = any_true(false, false, true);  // true
    b = all_true(true, true, false);   // false
    let mut r: i32 = 0;
    if b {
        r = 0;
    } else {
        r = 1;
    }
    debug_assert!(r);
}
