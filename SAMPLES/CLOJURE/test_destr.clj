; Test TODO 21 - Destructuration

; Test 1 : destructuration sequentielle dans let
(let [[a b c] (vector 1 2 3)]
  (println a)
  (println b)
  (println c))

; Test 2 : destructuration avec _ (ignore)
(let [[x _ z] (vector 10 20 30)]
  (println x)
  (println z))

; Test 3 : destructuration associative {:keys}
(let [{:keys [nom age]} (hash-map :nom 42 :age 25)]
  (println nom)
  (println age))

; Test 4 : destructuration associative explicite
(let [{x :nom y :age} (hash-map :nom 42 :age 25)]
  (println x)
  (println y))

; Test 5 : defn avec destructuration
(defn somme-vec [[a b c]]
  (+ a (+ b c)))

(println (somme-vec (vector 1 2 3)))
