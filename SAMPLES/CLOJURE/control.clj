; control.clj - if, when, cond, case, do, let

; --- if : expression conditionnelle ---
(println (if true "vrai" "faux"))
(println (if false "vrai" "faux"))
(println (if (> 10 5) "plus grand" "plus petit"))

; --- when : execute si vrai ---
(when true (println "when : vrai"))
(when (= 1 1) (println "when : 1 = 1"))

; --- cond : conditions multiples ---
(def n 15)
(println
  (cond
    (= n 0) "zero"
    (< n 10) "petit"
    (< n 20) "moyen"
    :else "grand"))

; --- case : dispatch sur valeur ---
(def jour 3)
(println
  (case jour
    1 "lundi"
    2 "mardi"
    3 "mercredi"
    4 "jeudi"
    5 "vendredi"
    "autre"))

; --- do : sequence d expressions ---
(do
  (println "do : premiere")
  (println "do : deuxieme")
  (println "do : troisieme"))

; --- let : liaisons locales ---
(let [a 10
      b 20
      c (+ a b)]
  (println (str "a=" a " b=" b " c=" c)))

; --- let imbrique ---
(let [x 5]
  (let [y (* x 2)]
    (println (str "x=" x " y=" y))))

; --- if-not ---
(println (if-not false "if-not : ok" "if-not : ko"))

; --- when-not ---
(when-not false (println "when-not : execute"))
