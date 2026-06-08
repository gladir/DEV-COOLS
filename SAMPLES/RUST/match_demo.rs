// match_demo.rs - Simulation de match via if/else en cascade
// Demontre : if/else if chains, retours de valeurs distinctes

fn day_type(d: i32) -> i32 {
    // 1=lundi .. 7=dimanche; retourne 1=semaine, 2=weekend
    if d == 6 || d == 7 {
        return 2;
    }
    if d >= 1 && d <= 5 {
        return 1;
    }
    return 0;
}

fn season(month: i32) -> i32 {
    // 1=hiver, 2=printemps, 3=ete, 4=automne
    if month == 12 || month == 1 || month == 2 {
        return 1;
    }
    if month >= 3 && month <= 5 {
        return 2;
    }
    if month >= 6 && month <= 8 {
        return 3;
    }
    if month >= 9 && month <= 11 {
        return 4;
    }
    return 0;
}

fn grade(score: i32) -> i32 {
    // A=5, B=4, C=3, D=2, F=1
    if score >= 90 {
        return 5;
    }
    if score >= 80 {
        return 4;
    }
    if score >= 70 {
        return 3;
    }
    if score >= 60 {
        return 2;
    }
    return 1;
}

pub fn main() {
    let mut r: i32 = 0;
    r = day_type(3);    // 1 (semaine)
    r = day_type(7);    // 2 (weekend)
    r = season(7);      // 3 (ete)
    r = season(1);      // 1 (hiver)
    r = grade(95);      // 5
    r = grade(72);      // 3
    r = grade(55);      // 1
    debug_assert!(r);
}
