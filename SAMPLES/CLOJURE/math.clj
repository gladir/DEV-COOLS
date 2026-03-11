; math.clj - defn, fn, +, -, *, /, mod, comparaisons

; --- Arithmetique de base ---
(println (+ 10 20))
(println (- 100 42))
(println (* 6 7))
(println (/ 100 5))
(println (mod 17 5))

; --- Fonctions nommees (defn) ---
(defn carre [x] (* x x))
(println (carre 7))

(defn double [n] (+ n n))
(println (double 21))

(defn somme [a b] (+ a b))
(println (somme 10 32))

; --- Fonctions multi-arg arithmetique ---
(defn moyenne [a b] (/ (+ a b) 2))
(println (moyenne 10 20))

; --- Comparaisons ---
(println (= 1 1))
(println (= 1 2))
(println (< 3 5))
(println (> 10 5))
(println (<= 5 5))
(println (>= 3 7))

; --- Predicats ---
(println (zero? 0))
(println (zero? 5))
(println (pos? 3))
(println (neg? -7))

; --- inc et dec ---
(println (inc 41))
(println (dec 43))

; --- abs et max/min ---
(defn abs-val [x] (if (neg? x) (- 0 x) x))
(println (abs-val -42))
(println (abs-val 42))

(println (max 10 20))
(println (min 10 20))
