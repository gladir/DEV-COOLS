// control.rs - Structures de controle compilees par RUST86
// Demontre : if/else, while, for..in, loop, break, match

fn classify(x: i16) -> i16 {
    if x < 0 {
        return 0;
    } else if x == 0 {
        return 1;
    } else {
        return 2;
    }
}

fn sum_to(n: i16) -> i16 {
    let mut acc: i16 = 0;
    let mut i: i16 = 0;
    while i < n {
        acc = acc + i;
        i = i + 1;
    }
    return acc;
}

fn label_of(code: i16) -> i16 {
    match code {
        0 => { return 10; }
        1 => { return 20; }
        _ => { return 99; }
    }
    return 0;
}

pub fn main() {
    let mut x: i16 = 0;
    x = classify(42);
    x = sum_to(10);
    x = label_of(1);
    for i in 0..5 {
        x = x + 1;
    }
    loop {
        x = x - 1;
        if x < 0 {
            break;
        }
    }
    debug_assert!(x);
}
