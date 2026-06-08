// statics.rs - Variables statiques globales et constantes
// Demontre : static, static mut, constantes entières

static MAX_ITEMS: i32 = 100;
static MIN_VALUE: i32 = 0 - 32768;
static MAX_VALUE: i32 = 32767;

static mut INSTANCE_COUNT: i32 = 0;
static mut ERROR_COUNT: i32 = 0;

fn create_instance() -> i32 {
    unsafe {
        INSTANCE_COUNT = INSTANCE_COUNT + 1;
        return INSTANCE_COUNT;
    }
}

fn report_error() {
    unsafe {
        ERROR_COUNT = ERROR_COUNT + 1;
    }
}

fn get_instances() -> i32 {
    unsafe {
        return INSTANCE_COUNT;
    }
}

fn get_errors() -> i32 {
    unsafe {
        return ERROR_COUNT;
    }
}

fn cap_to_max(v: i32) -> i32 {
    if v > MAX_ITEMS {
        return MAX_ITEMS;
    }
    return v;
}

pub fn main() {
    let mut id1: i32 = 0;
    let mut id2: i32 = 0;
    let mut id3: i32 = 0;
    id1 = create_instance();   // 1
    id2 = create_instance();   // 2
    id3 = create_instance();   // 3
    report_error();
    report_error();
    let mut r: i32 = 0;
    r = get_instances();       // 3
    r = get_errors();          // 2
    r = cap_to_max(150);       // 100
    r = cap_to_max(50);        // 50
    debug_assert!(r);
}
