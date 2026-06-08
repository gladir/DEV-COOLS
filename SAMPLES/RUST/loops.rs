// loops.rs - Variantes de boucles
// Demontre : while, boucle infinie avec break (via compteur), for implicite

fn sum_while(n: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 1;
    while i <= n {
        s = s + i;
        i = i + 1;
    }
    return s;
}

fn sum_even(n: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 0;
    while i <= n {
        if i % 2 == 0 {
            s = s + i;
        }
        i = i + 1;
    }
    return s;
}

fn product_until_overflow(limit: i32) -> i32 {
    let mut p: i32 = 1;
    let mut i: i32 = 1;
    while i <= limit {
        if p > 1000000 {
            return p;
        }
        p = p * i;
        i = i + 1;
    }
    return p;
}

fn nested_sum(rows: i32, cols: i32) -> i32 {
    let mut total: i32 = 0;
    let mut i: i32 = 1;
    while i <= rows {
        let mut j: i32 = 1;
        while j <= cols {
            total = total + i * j;
            j = j + 1;
        }
        i = i + 1;
    }
    return total;
}

pub fn main() {
    let mut r: i32 = 0;
    r = sum_while(10);          // 55
    r = sum_even(10);           // 30
    r = product_until_overflow(20); // depends on overflow guard
    r = nested_sum(3, 3);       // 36
    debug_assert!(r);
}
