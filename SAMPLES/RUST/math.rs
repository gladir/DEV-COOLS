// math.rs - Fonctions arithmetiques compiles par RUST86
// Demontre : fn, params, return, static, const

const MAX_VAL: i16 = 1000;
static mut COUNTER: i16 = 0;

fn add(a: i16, b: i16) -> i16 {
    return a + b;
}

fn mul(a: i16, b: i16) -> i16 {
    return a * b;
}

fn abs_val(x: i16) -> i16 {
    if x < 0 {
        return 0 - x;
    }
    return x;
}

pub fn main() {
    let x: i16 = 10;
    let y: i16 = 20;
    let mut z: i16 = 0;
    z = add(x, y);
    z = mul(z, 2);
    z = abs_val(0 - z);
    debug_assert!(z);
}
