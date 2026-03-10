; Test TODO 22 - Fonctions d'ordre superieur

; Fonctions auxiliaires
(defn double [x] (+ x x))
(defn is-pos [x] (> x 0))
(defn add [a b] (+ a b))
(defn inc1 [x] (+ x 1))
(defn dec1 [x] (- x 1))

; Test 1 : map
(println (count (map double (list 1 2 3))))

; Test 2 : filter
(println (count (filter is-pos (list 1 -2 3 -4 5))))

; Test 3 : reduce avec init
(println (reduce add 0 (list 1 2 3 4 5)))

; Test 4 : reduce sans init
(println (reduce add (list 10 20 30)))

; Test 5 : remove
(println (count (remove is-pos (list 1 -2 3 -4 5))))

; Test 6 : identity
(println (identity 42))

; Test 7 : every? (tous positifs ? non)
(println (every? is-pos (list 1 2 -3)))

; Test 8 : every? (tous positifs ? oui)
(println (every? is-pos (list 1 2 3)))

; Test 9 : some (premier positif)
(println (some is-pos (list -1 -2 3 4)))

; Test 10 : into
(println (count (into (list 10) (list 1 2 3))))
