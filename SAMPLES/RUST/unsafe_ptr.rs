// unsafe_ptr.rs - Encodage et decodage de paires de valeurs (i8 dans i32)
fn encode_pair(hi: i32, lo: i32) -> i32 {
    return hi * 256 + lo;
}

fn decode_hi(v: i32) -> i32 {
    return v / 256;
}

fn decode_lo(v: i32) -> i32 {
    return v % 256;
}

fn swap_pair(v: i32) -> i32 {
    let mut hi: i32 = 0;
    let mut lo: i32 = 0;
    hi = v / 256;
    lo = v % 256;
    return lo * 256 + hi;
}

fn add_pairs(x: i32, y: i32) -> i32 {
    let mut xhi: i32 = 0;
    let mut xlo: i32 = 0;
    let mut yhi: i32 = 0;
    let mut ylo: i32 = 0;
    let mut rhi: i32 = 0;
    let mut rlo: i32 = 0;
    xhi = decode_hi(x);
    xlo = decode_lo(x);
    yhi = decode_hi(y);
    ylo = decode_lo(y);
    rhi = xhi + yhi;
    rlo = xlo + ylo;
    return encode_pair(rhi, rlo);
}

pub fn main() {
    let mut r: i32 = 0;
    let mut pair: i32 = 0;
    pair = encode_pair(10, 20);
    r = decode_hi(pair);
    println!("hi = {}", r);
    r = decode_lo(pair);
    println!("lo = {}", r);
    let mut swapped: i32 = 0;
    swapped = swap_pair(pair);
    r = decode_hi(swapped);
    println!("swapped hi = {}", r);
    r = decode_lo(swapped);
    println!("swapped lo = {}", r);
    let mut p1: i32 = 0;
    let mut p2: i32 = 0;
    let mut sum_pair: i32 = 0;
    p1 = encode_pair(1, 2);
    p2 = encode_pair(3, 4);
    sum_pair = add_pairs(p1, p2);
    r = decode_hi(sum_pair);
    println!("sum hi = {}", r);
    r = decode_lo(sum_pair);
    println!("sum lo = {}", r);
    debug_assert!(r);
}
