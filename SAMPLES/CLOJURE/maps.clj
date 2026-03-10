; maps.clj - hash-map, get, assoc, dissoc, keys, vals

; --- Creer une map ---
(def m {:a 1 :b 2 :c 3})

; --- get : acces par cle ---
(println (get m :a))
(println (get m :b))
(println (get m :c))

; --- count ---
(println (count m))

; --- assoc : ajout / modification ---
(def m2 (assoc m :d 4))
(println (get m2 :d))
(println (count m2))

; --- dissoc : suppression de cle ---
(def m3 (dissoc m :b))
(println (count m3))

; --- contains? ---
(println (contains? m :a))
(println (contains? m :z))

; --- keys : liste des cles ---
(def ks (keys m))
(println (count ks))

; --- vals : liste des valeurs ---
(def vs (vals m))
(println (count vs))

; --- map? ---
(println (map? m))
(println (map? 42))

; --- hash-map explicite ---
(def m4 (hash-map :x 10 :y 20))
(println (get m4 :x))
(println (get m4 :y))

; --- get avec valeur par defaut ---
(println (get m :z 0))

; --- Utilisation avec defn ---
(defn nom-complet [personne]
  (str (get personne :prenom) " " (get personne :nom)))

(println (nom-complet {:prenom 42 :nom 99}))
