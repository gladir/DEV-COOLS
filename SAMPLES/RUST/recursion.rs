// recursion.rs - Algorithmes recursifs classiques
// Demontre : recursion mutuelle, recursion profonde, cas de base

fn sum_digits(n: i32) -> i32 {
    if n < 0 {
        return sum_digits(0 - n);
    }
    if n < 10 {
        return n;
    }
    return (n % 10) + sum_digits(n / 10);
}

fn count_digits(n: i32) -> i32 {
    if n < 0 {
        return count_digits(0 - n);
    }
    if n < 10 {
        return 1;
    }
    return 1 + count_digits(n / 10);
}

fn reverse_digits(n: i32) -> i32 {
    if n < 10 {
        return n;
    }
    return (n % 10) * power10(count_digits(n) - 1) + reverse_digits(n / 10);
}

fn power10(e: i32) -> i32 {
    if e <= 0 {
        return 1;
    }
    return 10 * power10(e - 1);
}

fn ackermann(m: i32, n: i32) -> i32 {
    if m == 0 {
        return n + 1;
    }
    if n == 0 {
        return ackermann(m - 1, 1);
    }
    return ackermann(m - 1, ackermann(m, n - 1));
}

pub fn main() {
    let mut r: i32 = 0;
    r = sum_digits(12345);   // 15
    r = count_digits(9999);  // 4
    r = reverse_digits(123); // 321
    r = ackermann(2, 3);     // 9
    r = ackermann(3, 2);     // 29
    debug_assert!(r);
}
