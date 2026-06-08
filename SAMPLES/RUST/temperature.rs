// temperature.rs - Conversion de temperatures
// Demontre : arithmetique entiere, division tronquee

fn celsius_to_fahrenheit(c: i32) -> i32 {
    return (c * 9) / 5 + 32;
}

fn fahrenheit_to_celsius(f: i32) -> i32 {
    return ((f - 32) * 5) / 9;
}

fn celsius_to_kelvin(c: i32) -> i32 {
    return c + 273;
}

fn kelvin_to_celsius(k: i32) -> i32 {
    return k - 273;
}

fn is_freezing(c: i32) -> bool {
    return c <= 0;
}

fn is_boiling(c: i32) -> bool {
    return c >= 100;
}

pub fn main() {
    let mut r: i32 = 0;
    r = celsius_to_fahrenheit(0);     // 32
    r = celsius_to_fahrenheit(100);   // 212
    r = fahrenheit_to_celsius(212);   // 100
    r = celsius_to_kelvin(0);         // 273
    r = kelvin_to_celsius(373);       // 100
    let mut b: bool = false;
    b = is_freezing(0 - 10);          // true
    b = is_boiling(150);              // true
    debug_assert!(r);
}
