; lists.clj - list, cons, first, rest, conj, nth

; --- Creer une liste ---
(def l (list 1 2 3 4 5))

; --- first : premier element ---
(println (first l))

; --- rest : le reste ---
(println (first (rest l)))

; --- nth : acces par index ---
(println (nth l 0))
(println (nth l 2))
(println (nth l 4))

; --- count : longueur ---
(println (count l))

; --- cons : ajouter en tete ---
(def l2 (cons 0 l))
(println (first l2))
(println (count l2))

; --- conj : ajouter en tete (pour les listes) ---
(def l3 (conj l 0))
(println (first l3))

; --- empty? ---
(println (empty? l))
(println (empty? (list)))

; --- list? ---
(println (list? l))
(println (list? 42))

; --- seq? ---
(println (seq? l))

; --- second : deuxieme element ---
(println (second l))

; --- last : dernier element ---
(println (last l))

; --- Liste vide ---
(def vide (list))
(println (count vide))
(println (empty? vide))
