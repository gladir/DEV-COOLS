; loops.clj - loop/recur, dotimes, doseq, while

; --- loop/recur : boucle avec accumulateur ---
(println
  (loop [i 0 acc 0]
    (if (= i 5)
      acc
      (recur (inc i) (+ acc i)))))

; --- loop/recur : compteur ---
(loop [n 1]
  (when (<= n 5)
    (println (str "n=" n))
    (recur (inc n))))

; --- dotimes ---
(dotimes [i 5]
  (println (str "dotimes i=" i)))

; --- doseq sur vecteur ---
(doseq [x [10 20 30]]
  (println (str "doseq x=" x)))

; --- doseq sur liste ---
(doseq [item (list 1 2 3 4 5)]
  (println item))

; --- loop/recur : factorielle ---
(defn fact [n]
  (loop [i n acc 1]
    (if (<= i 1)
      acc
      (recur (dec i) (* acc i)))))

(println (str "5! = " (fact 5)))

; --- loop/recur : fibonacci ---
(defn fib [n]
  (loop [i 0 a 0 b 1]
    (if (= i n)
      a
      (recur (inc i) b (+ a b)))))

(println (str "fib(10) = " (fib 10)))

; --- while ---
(def counter 0)
(while (< counter 3)
  (println (str "while counter=" counter))
  (def counter (inc counter)))
