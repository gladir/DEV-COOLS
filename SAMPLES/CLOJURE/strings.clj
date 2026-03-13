; strings.clj - str, subs, upper-case, lower-case, trim

; --- str : concatenation ---
(println (str "Hello" " " "World"))
(println (str "abc" 42))
(println (str))

; --- subs : sous-chaine ---
(println (subs "Hello World" 6))
(println (subs "Hello World" 0 5))

; --- count : longueur de chaine ---
(println (count "Hello"))
(println (count ""))

; --- get : caractere par index ---
(println (get "abcde" 0))
(println (get "abcde" 4))

; --- clojure.string/upper-case ---
(println (clojure.string/upper-case "hello world"))

; --- clojure.string/lower-case ---
(println (clojure.string/lower-case "HELLO WORLD"))

; --- clojure.string/trim ---
(println (clojure.string/trim "  espaces  "))

; --- clojure.string/includes? ---
(println (clojure.string/includes? "hello world" "world"))
(println (clojure.string/includes? "hello" "xyz"))

; --- clojure.string/replace ---
(println (clojure.string/replace "hello world" "world" "clojure"))
(println (clojure.string/replace "aaa" "a" "b"))

; --- clojure.string/join ---
(def items (list "a" "b" "c"))
(println (clojure.string/join ", " items))
(println (clojure.string/join "-" (list "2026" "03" "10")))

; --- str avec types mixtes ---
(println (str "val=" 42 " ok=" true))
