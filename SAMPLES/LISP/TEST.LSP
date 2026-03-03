; TEST.LSP - Programme de test LISP86
; Calcul de la factorielle + affichage
; Usage : LISP86.EXE TEST.LSP TEST.ASM

; --- Fonction factorielle recursive ---
(defun fact (n)
  (if (= n 0)
    1
    (* n (fact (- n 1)))))

; --- Fonction principale ---
(defun main ()
  (setq x 10)
  (print (fact x))
  (terpri))
