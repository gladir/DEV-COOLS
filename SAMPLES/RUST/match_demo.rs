// match_demo.rs - Simulation de match via if/else en cascade
fn day_type(d: i32) -> i32 {
    if d == 6 || d == 7 { return 2; }
    if d >= 1 && d <= 5 { return 1; }
    return 0;
}

fn season(month: i32) -> i32 {
    if month == 12 || month == 1 || month == 2 { return 1; }
    if month >= 3 && month <= 5 { return 2; }
    if month >= 6 && month <= 8 { return 3; }
    if month >= 9 && month <= 11 { return 4; }
    return 0;
}

fn grade(score: i32) -> i32 {
    if score >= 90 { return 5; }
    if score >= 80 { return 4; }
    if score >= 70 { return 3; }
    if score >= 60 { return 2; }
    return 1;
}

pub fn main() {
    let mut r: i32 = 0;
    r = day_type(3);
    println!("day_type(3) = {}", r);
    r = day_type(7);
    println!("day_type(7) = {}", r);
    r = season(7);
    println!("season(7) = {}", r);
    r = grade(95);
    println!("grade(95) = {}", r);
    r = grade(72);
    println!("grade(72) = {}", r);
    debug_assert!(r);
}
