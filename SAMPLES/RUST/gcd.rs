// gcd.rs - Plus grand diviseur commun (algorithme d'Euclide)
fn gcd(a: i32, b: i32) -> i32 {
    let mut x: i32 = 0;
    let mut y: i32 = 0;
    x = a;
    y = b;
    while y != 0 {
        let mut tmp: i32 = 0;
        tmp = y;
        y = x % y;
        x = tmp;
    }
    return x;
}

fn lcm(a: i32, b: i32) -> i32 {
    let mut g: i32 = 0;
    g = gcd(a, b);
    return (a / g) * b;
}

pub fn main() {
    let mut r: i32 = 0;
    r = gcd(48, 18);
    println!("gcd(48, 18) = {}", r);
    r = gcd(100, 75);
    println!("gcd(100, 75) = {}", r);
    r = lcm(4, 6);
    println!("lcm(4, 6) = {}", r);
    r = lcm(12, 18);
    println!("lcm(12, 18) = {}", r);
    debug_assert!(r);
}
