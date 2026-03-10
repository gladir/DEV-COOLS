; vectors.clj - vector, nth, assoc, conj, subvec

; --- Creer un vecteur ---
(def v [10 20 30 40 50])

; --- nth : acces par index ---
(println (nth v 0))
(println (nth v 2))
(println (nth v 4))

; --- count ---
(println (count v))

; --- conj : ajouter en fin ---
(def v2 (conj v 60))
(println (count v2))
(println (nth v2 5))

; --- assoc : remplacement par index ---
(def v3 (assoc v 2 99))
(println (nth v3 2))

; --- first et rest ---
(println (first v))

; --- Vecteur litteral ---
(def nums [1 2 3])
(println (nth nums 0))
(println (nth nums 1))
(println (nth nums 2))

; --- get : synonyme de nth ---
(println (get v 1))
(println (get v 3))

; --- empty? ---
(println (empty? v))
(println (empty? []))

; --- vector? ---
(println (vector? v))
(println (vector? 42))

; --- Utilisation avec defn ---
(defn somme-vec [v]
  (+ (nth v 0) (+ (nth v 1) (nth v 2))))

(println (somme-vec [100 200 300]))
