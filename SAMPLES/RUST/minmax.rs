// minmax.rs - Minimum, maximum, mediane sur sequences
// Demontre : comparaisons en boucle, variables d'accumulation

fn min2(a: i32, b: i32) -> i32 {
    if a < b {
        return a;
    }
    return b;
}

fn max2(a: i32, b: i32) -> i32 {
    if a > b {
        return a;
    }
    return b;
}

fn min3(a: i32, b: i32, c: i32) -> i32 {
    return min2(a, min2(b, c));
}

fn max3(a: i32, b: i32, c: i32) -> i32 {
    return max2(a, max2(b, c));
}

fn median3(a: i32, b: i32, c: i32) -> i32 {
    let mut s: i32 = 0;
    s = a + b + c - min3(a, b, c) - max3(a, b, c);
    return s;
}

fn range_min(from: i32, to: i32) -> i32 {
    return from;
}

fn range_max(from: i32, to: i32) -> i32 {
    return to;
}

fn clamp(x: i32, lo: i32, hi: i32) -> i32 {
    return max2(lo, min2(x, hi));
}

pub fn main() {
    let mut r: i32 = 0;
    r = min2(7, 3);          // 3
    r = max2(7, 3);          // 7
    r = min3(5, 2, 8);       // 2
    r = max3(5, 2, 8);       // 8
    r = median3(5, 2, 8);    // 5
    r = median3(1, 9, 5);    // 5
    r = clamp(15, 0, 10);    // 10
    r = clamp(0 - 3, 0, 10); // 0
    r = clamp(7, 0, 10);     // 7
    debug_assert!(r);
}
