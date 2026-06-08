// control.rs - Structures de controle: if/else, while, match
fn classify(x: i32) -> i32 {
    if x < 0 { return 0; }
    else if x == 0 { return 1; }
    else { return 2; }
}

fn sum_to(n: i32) -> i32 {
    let mut acc: i32 = 0;
    let mut i: i32 = 0;
    while i < n { acc = acc + i; i = i + 1; }
    return acc;
}

fn label_of(code: i32) -> i32 {
    match code {
        0 => { return 10; }
        1 => { return 20; }
        _ => { return 99; }
    }
    return 0;
}

pub fn main() {
    let mut r: i32 = 0;
    r = classify(0 - 5);
    println!("classify(-5) = {}", r);
    r = classify(0);
    println!("classify(0) = {}", r);
    r = classify(42);
    println!("classify(42) = {}", r);
    r = sum_to(10);
    println!("sum_to(10) = {}", r);
    r = label_of(0);
    println!("label_of(0) = {}", r);
    r = label_of(1);
    println!("label_of(1) = {}", r);
    r = label_of(5);
    println!("label_of(5) = {}", r);
    debug_assert!(r);
}
