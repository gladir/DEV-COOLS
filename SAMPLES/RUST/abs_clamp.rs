// abs_clamp.rs - Valeur absolue, saturation, ecrêtage
// Demontre : comparaisons, negation via soustraction, bornes

fn abs_i32(x: i32) -> i32 {
    if x < 0 {
        return 0 - x;
    }
    return x;
}

fn clamp_i32(x: i32, lo: i32, hi: i32) -> i32 {
    if x < lo {
        return lo;
    }
    if x > hi {
        return hi;
    }
    return x;
}

fn saturate_u8(x: i32) -> u8 {
    if x < 0 {
        return 0;
    }
    if x > 255 {
        return 255;
    }
    return x;
}

fn sign(x: i32) -> i32 {
    if x > 0 {
        return 1;
    }
    if x < 0 {
        return 0 - 1;
    }
    return 0;
}

pub fn main() {
    let mut r: i32 = 0;
    r = abs_i32(0 - 42);     // 42
    r = abs_i32(17);          // 17
    r = clamp_i32(200, 0, 100); // 100
    r = clamp_i32(0 - 5, 0, 100); // 0
    r = clamp_i32(50, 0, 100);   // 50
    r = sign(0 - 7);          // -1
    r = sign(5);              // 1
    let mut b: u8 = 0;
    b = saturate_u8(300);     // 255
    b = saturate_u8(0 - 1);   // 0
    debug_assert!(r);
}
