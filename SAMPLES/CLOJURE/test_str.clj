; test_str.clj - Test TODO 23 : chaines de caracteres

; --- str : concatenation ---
(println (str "Hello" " " "World"))
(println (str "abc" 42))
(println (str))

; --- subs : sous-chaine ---
(println (subs "Hello World" 6))
(println (subs "Hello World" 0 5))

; --- count : longueur chaine ---
(println (count "Hello"))

; --- get : caractere par index ---
(println (get "abc" 0))
(println (get "abc" 2))

; --- clojure.string/upper-case ---
(println (clojure.string/upper-case "hello"))

; --- clojure.string/lower-case ---
(println (clojure.string/lower-case "HELLO"))

; --- clojure.string/trim ---
(println (clojure.string/trim "  hello  "))

; --- clojure.string/includes? ---
(println (clojure.string/includes? "hello world" "world"))
(println (clojure.string/includes? "hello" "xyz"))

; --- clojure.string/replace ---
(println (clojure.string/replace "hello world" "world" "clojure"))

; --- clojure.string/join ---
(def items (list "a" "b" "c"))
(println (clojure.string/join ", " items))
