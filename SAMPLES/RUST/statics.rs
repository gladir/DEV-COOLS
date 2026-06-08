// statics.rs - Variables statiques globales et constantes
static MAX_ITEMS: i32 = 100;
static mut INSTANCE_COUNT: i32 = 0;
static mut ERROR_COUNT: i32 = 0;

fn create_instance() -> i32 {
    unsafe { INSTANCE_COUNT = INSTANCE_COUNT + 1; return INSTANCE_COUNT; }
}

fn report_error() {
    unsafe { ERROR_COUNT = ERROR_COUNT + 1; }
}

fn get_instances() -> i32 { unsafe { return INSTANCE_COUNT; } }
fn get_errors() -> i32 { unsafe { return ERROR_COUNT; } }

fn cap_to_max(v: i32) -> i32 {
    if v > MAX_ITEMS { return MAX_ITEMS; }
    return v;
}

pub fn main() {
    let mut r: i32 = 0;
    r = create_instance();
    println!("instance 1 id = {}", r);
    r = create_instance();
    println!("instance 2 id = {}", r);
    r = create_instance();
    println!("instance 3 id = {}", r);
    report_error();
    report_error();
    r = get_instances();
    println!("total instances = {}", r);
    r = get_errors();
    println!("total erreurs = {}", r);
    r = cap_to_max(150);
    println!("cap_to_max(150) = {}", r);
    debug_assert!(r);
}
