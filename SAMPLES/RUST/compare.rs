// compare.rs - Comparaisons et tri simple
// Demontre : comparaisons multi-types, tri a bulles sur variables

fn cmp_i32(a: i32, b: i32) -> i32 {
    // retourne -1, 0 ou 1
    if a < b {
        return 0 - 1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

fn cmp_u8(a: u8, b: u8) -> i32 {
    if a < b {
        return 0 - 1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

fn sort3(a: i32, b: i32, c: i32) -> i32 {
    // retourne la valeur mediane triee au milieu
    let mut x: i32 = 0;
    let mut y: i32 = 0;
    let mut z: i32 = 0;
    x = a;
    y = b;
    z = c;
    let mut tmp: i32 = 0;
    if x > y {
        tmp = x;
        x = y;
        y = tmp;
    }
    if y > z {
        tmp = y;
        y = z;
        z = tmp;
    }
    if x > y {
        tmp = x;
        x = y;
        y = tmp;
    }
    return y;  // mediane
}

fn between(x: i32, lo: i32, hi: i32) -> bool {
    return cmp_i32(x, lo) >= 0 && cmp_i32(x, hi) <= 0;
}

pub fn main() {
    let mut r: i32 = 0;
    r = cmp_i32(5, 10);     // -1
    r = cmp_i32(10, 5);     // 1
    r = cmp_i32(7, 7);      // 0
    r = sort3(9, 3, 6);     // 6 (mediane)
    r = sort3(1, 5, 3);     // 3 (mediane)
    let mut b: bool = false;
    b = between(5, 1, 10);  // true
    b = between(15, 1, 10); // false
    r = cmp_i32(r, 0);       // r=3 vs 0 => 1
    debug_assert!(r);
}
