// counters.rs - Compteurs et accumulateurs
// Demontre : variables globales statiques, mutation, increment

static mut CALL_COUNT: i32 = 0;
static mut TOTAL_SUM: i32 = 0;

fn increment_counter() {
    unsafe {
        CALL_COUNT = CALL_COUNT + 1;
    }
}

fn add_to_total(v: i32) {
    unsafe {
        TOTAL_SUM = TOTAL_SUM + v;
    }
}

fn get_count() -> i32 {
    unsafe {
        return CALL_COUNT;
    }
}

fn get_total() -> i32 {
    unsafe {
        return TOTAL_SUM;
    }
}

fn sum_range(from: i32, to: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 0;
    i = from;
    while i <= to {
        s = s + i;
        i = i + 1;
    }
    return s;
}

pub fn main() {
    increment_counter();
    increment_counter();
    increment_counter();
    add_to_total(10);
    add_to_total(20);
    add_to_total(30);
    let mut r: i32 = 0;
    r = get_count();    // 3
    r = get_total();    // 60
    r = sum_range(1, 100); // 5050
    debug_assert!(r);
}
