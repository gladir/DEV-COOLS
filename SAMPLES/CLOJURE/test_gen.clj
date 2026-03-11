; test_gen.clj - Test TODO 25 : generation finale et fichiers exemples
; Teste la generation du pipeline complet :
;   - Formes de niveau superieur
;   - Variables globales (def)
;   - Fonctions (defn)
;   - Point d entree avec (defn -main ...)

; --- Variables globales ---
(def titre "Test TODO 25")
(def version 25)

; --- Fonction utilitaire ---
(defn double [x] (+ x x))

(defn somme [a b] (+ a b))

; --- Affichage de base ---
(println titre)
(println version)

; --- Appels de fonctions ---
(println (double 21))
(println (somme 10 32))

; --- Combinaison de formes ---
(def resultat (somme (double 5) (double 10)))
(println resultat)

; --- Point d entree -main (TODO 25) ---
(defn -main []
  (println "=== -main appelee ===")
  (println (str "titre=" titre))
  (println (str "version=" version))
  (println (str "double(7)=" (double 7)))
  (println "=== fin -main ==="))
