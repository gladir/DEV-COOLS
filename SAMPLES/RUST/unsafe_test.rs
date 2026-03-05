// unsafe_test.rs - Blocs unsafe et extern compiles par RUST86
// Demontre : extern "C", unsafe { }, pointeurs bruts *const/*mut

extern "C" {
    fn puts(s: i16);
}

fn safe_noop(x: i16) -> i16 {
    return x;
}

pub fn main() {
    unsafe {
        let p: *const i16 = 0;
    }
    let v: i16 = safe_noop(42);
    debug_assert!(v);
    panic!("unsafe_test: fin normale");
}
