// loops.rs - Variantes de boucles et accumulation
fn sum_while(n: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 1;
    while i <= n { s = s + i; i = i + 1; }
    return s;
}

fn sum_even(n: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 0;
    while i <= n {
        if i % 2 == 0 { s = s + i; }
        i = i + 1;
    }
    return s;
}

fn nested_sum(rows: i32, cols: i32) -> i32 {
    let mut total: i32 = 0;
    let mut i: i32 = 1;
    while i <= rows {
        let mut j: i32 = 1;
        while j <= cols { total = i * j + total; j = j + 1; }
        i = i + 1;
    }
    return total;
}

pub fn main() {
    let mut r: i32 = 0;
    r = sum_while(10);
    println!("somme 1..10 = {}", r);
    r = sum_while(100);
    println!("somme 1..100 = {}", r);
    r = sum_even(10);
    println!("somme pairs <= 10 = {}", r);
    r = nested_sum(3, 3);
    println!("nested_sum(3, 3) = {}", r);
    debug_assert!(r);
}
