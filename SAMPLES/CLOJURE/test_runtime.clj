;; test_runtime.clj
;; Test des routines runtime (TODO 24)

;; --- Tests de base : println et str ---
(println "=== Test runtime TODO 24 ===")

;; Entier
(println 42)

;; Chaine
(println "hello world")

;; Booleen
(println true)
(println false)

;; nil
(println nil)

;; --- Concatenation via str ---
(println (str "nombre: " 123))
(println (str "bool: " true))

;; --- Comparaisons d egalite ---
(println (= 1 1))
(println (= 1 2))
(println (= "abc" "abc"))

;; --- Vecteurs ---
(def v [10 20 30])
(println (nth v 0))
(println (nth v 1))
(println (count v))

;; --- Maps ---
(def m {:a 1 :b 2})
(println (get m :a))
(println (get m :b))
(println (count m))

;; --- Ensembles ---
(def s #{1 2 3})
(println (contains? s 2))
(println (count s))

;; --- Arithmetique ---
(println (+ 10 20))
(println (- 100 42))
(println (* 6 7))

(println "=== Fin tests runtime ===")
