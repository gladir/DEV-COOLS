; hello.clj - println, def, str, variables globales

; --- Bonjour le monde ---
(println "Hello, World!")

; --- Variables globales avec def ---
(def nom "Clojure")
(def version 86)

; --- Affichage de variables ---
(println nom)
(println version)

; --- Concatenation avec str ---
(println (str "Bienvenue dans " nom " version " version))
(println (str "1 + 2 = " (+ 1 2)))

; --- Booleens et nil ---
(println true)
(println false)
(println nil)

; --- Caracteres ---
(println \A)
(println \space)

; --- Plusieurs def ---
(def x 42)
(def y 100)
(println (str "x=" x " y=" y " somme=" (+ x y)))
