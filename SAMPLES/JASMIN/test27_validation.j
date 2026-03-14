; test27_validation.j - Test de la validation du bytecode (TODO 24)
; Teste les verifications effectuees par ValidateBytecode :
;   - .class et .super definis -> OK
;   - methodes non-abstract ont du code -> OK
;   - .limit stack et .limit locals definis -> OK
;   - descripteurs de types valides -> OK
;   - labels tous resolus -> OK
;   - Constant Pool dans les limites -> OK
;   - bytecode dans les limites -> OK
;
; Ce fichier est un assemblage valide qui passe toutes les
; verifications sans erreur ni avertissement.

.source test27_validation.java
.class public test27_validation
.super java/lang/Object

; --- Champ avec descripteur valide ---
.field public static myField I
.field private message Ljava/lang/String;

; --- Constructeur ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode avec labels resolus et limites explicites ---
.method public static check(I)Z
  .limit stack 1
  .limit locals 1
  iload_0
  ifge isPositive
  iconst_0
  ireturn
isPositive:
  iconst_1
  ireturn
.end method

; --- Methode abstract (pas de code) ---
; Note : abstract methods need an abstract class
; On utilise une methode native pour tester l'absence de code
.method public static native nativeMethod()V
.end method

; --- Point d'entree principal ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1

  ; Tester check(5) = true (1)
  iconst_5
  invokestatic test27_validation/check(I)Z
  ifeq fail

  ; Tester check(-1) = false (0)
  iconst_m1
  invokestatic test27_validation/check(I)Z
  ifne fail

  ; Succes
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "test27_validation OK"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return

fail:
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "test27_validation FAIL"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method
