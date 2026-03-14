; destruct.clj - destructuration sequentielle et associative

; --- Destructuration sequentielle dans let ---
(let [[a b c] (vector 1 2 3)]
  (println a)
  (println b)
  (println c))

; --- Destructuration avec _ (ignore) ---
(let [[x _ z] (vector 10 20 30)]
  (println x)
  (println z))

; --- Destructuration associative {:keys} ---
(let [{:keys [nom age]} (hash-map :nom 42 :age 25)]
  (println nom)
  (println age))

; --- Destructuration associative explicite ---
(let [{x :a y :b} (hash-map :a 100 :b 200)]
  (println x)
  (println y))

; --- defn avec destructuration sequentielle ---
(defn somme-paire [[a b]]
  (+ a b))

(println (somme-paire (vector 10 20)))

; --- defn avec destructuration associative ---
(defn affiche-point [{:keys [x y]}]
  (println (str "(" x "," y ")")))

(affiche-point (hash-map :x 3 :y 7))

; --- let avec plusieurs liaisons dont destructuration ---
(let [n 10
      [a b] (vector 1 2)]
  (println (str "n=" n " a=" a " b=" b)))

; --- loop/recur avec destructuration ---
(loop [[x & rest] (list 1 2 3)]
  (when x
    (println x)
    (when rest
      (recur rest))))
