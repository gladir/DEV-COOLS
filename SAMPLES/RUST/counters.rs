// counters.rs - Compteurs et accumulateurs statiques
static mut CALL_COUNT: i32 = 0;
static mut TOTAL_SUM: i32 = 0;

fn increment() { unsafe { CALL_COUNT = CALL_COUNT + 1; } }
fn add(v: i32) { unsafe { TOTAL_SUM = TOTAL_SUM + v; } }
fn get_count() -> i32 { unsafe { return CALL_COUNT; } }
fn get_total() -> i32 { unsafe { return TOTAL_SUM; } }

fn sum_range(from: i32, to: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 0;
    i = from;
    while i <= to { s = s + i; i = i + 1; }
    return s;
}

pub fn main() {
    increment();
    increment();
    increment();
    add(10);
    add(20);
    add(30);
    let mut r: i32 = 0;
    r = get_count();
    println!("appels increment = {}", r);
    r = get_total();
    println!("total ajoute = {}", r);
    r = sum_range(1, 100);
    println!("somme 1..100 = {}", r);
    r = sum_range(1, 10);
    println!("somme 1..10 = {}", r);
    debug_assert!(r);
}
