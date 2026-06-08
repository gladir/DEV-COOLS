// unsafe_ptr.rs - Manipulation de pointeurs bruts
// Demontre : *const T, *mut T, unsafe, deref, arithmetique

fn read_i32(p: *const i32) -> i32 {
    unsafe {
        return *p;
    }
}

fn write_i32(p: *mut i32, v: i32) {
    unsafe {
        *p = v;
    }
}

fn swap_via_ptr(a: *mut i32, b: *mut i32) {
    unsafe {
        let mut tmp: i32 = 0;
        tmp = *a;
        *a = *b;
        *b = tmp;
    }
}

fn sum_ptr_range(p: *const i32, count: i32) -> i32 {
    let mut s: i32 = 0;
    let mut i: i32 = 0;
    while i < count {
        unsafe {
            s = s + *p;
        }
        i = i + 1;
    }
    return s;
}

pub fn main() {
    let mut x: i32 = 42;
    let mut y: i32 = 99;
    let mut r: i32 = 0;
    r = read_i32(&x);           // 42
    write_i32(&mut y, 7);
    r = read_i32(&y);           // 7
    swap_via_ptr(&mut x, &mut y);
    r = read_i32(&x);           // 7
    r = read_i32(&y);           // 42
    debug_assert!(r);
}
