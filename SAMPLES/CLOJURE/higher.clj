; higher.clj - map, filter, reduce, apply, comp, partial

; --- Fonctions auxiliaires ---
(defn double [x] (+ x x))
(defn carre [x] (* x x))
(defn is-pos [x] (> x 0))
(defn add [a b] (+ a b))
(defn inc1 [x] (+ x 1))

; --- map : appliquer une fonction a chaque element ---
(println (count (map double (list 1 2 3 4 5))))

; --- filter : garder les elements verifiant un predicat ---
(println (count (filter is-pos (list 1 -2 3 -4 5))))

; --- reduce : accumuler une valeur ---
(println (reduce add 0 (list 1 2 3 4 5)))

; --- reduce sans valeur initiale ---
(println (reduce add (list 10 20 30)))

; --- remove : inverse de filter ---
(println (count (remove is-pos (list 1 -2 3 -4 5))))

; --- some : premier element verifiant le predicat ---
(println (some is-pos (list -1 -2 3 4)))

; --- every? : tous verifient le predicat ? ---
(println (every? is-pos (list 1 2 3)))
(println (every? is-pos (list 1 -2 3)))

; --- identity ---
(println (identity 42))
(println (identity "hello"))

; --- comp : composition de fonctions ---
(def double-inc (comp double inc1))
(println (double-inc 5))

; --- partial : application partielle ---
(def add10 (partial add 10))
(println (add10 32))

; --- constantly : fonction constante ---
(def toujours42 (constantly 42))
(println (toujours42 99))

; --- into : fusionner des collections ---
(println (count (into (list 10) (list 1 2 3))))
