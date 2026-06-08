// temperature.rs - Conversions de temperatures
fn celsius_to_fahrenheit(c: i32) -> i32 { return (c * 9) / 5 + 32; }
fn fahrenheit_to_celsius(f: i32) -> i32 { return ((f - 32) * 5) / 9; }
fn celsius_to_kelvin(c: i32) -> i32 { return c + 273; }

pub fn main() {
    let mut r: i32 = 0;
    r = celsius_to_fahrenheit(0);
    println!("0 C en F = {}", r);
    r = celsius_to_fahrenheit(100);
    println!("100 C en F = {}", r);
    r = fahrenheit_to_celsius(212);
    println!("212 F en C = {}", r);
    r = celsius_to_kelvin(0);
    println!("0 C en K = {}", r);
    r = celsius_to_kelvin(100);
    println!("100 C en K = {}", r);
    debug_assert!(r);
}
