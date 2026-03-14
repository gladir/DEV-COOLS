; test26_classgen.j - Test de la generation complete .class (TODO 23)
; Teste le programme principal : ligne de commande, generation binaire,
; emission du Constant Pool, des champs, methodes et attributs de classe.
;
; Ce fichier exerce les fonctionnalites suivantes :
; - ParseCommandLine (-o, -d, -g, -v)
; - CPEmitAll (emission du Constant Pool)
; - EmitFieldInfo (champs avec ConstantValue)
; - EmitMethodInfo (methodes avec Code, Exceptions, Deprecated, Signature)
; - Generation complete du fichier .class (magic, version, CP, access,
;   this/super, interfaces, champs, methodes, attributs de classe)

.source test26_classgen.java
.class public test26_classgen
.super java/lang/Object

; --- Champ statique avec valeur initiale ---
.field public static GREETING Ljava/lang/String; = "Bonjour"
.field public static COUNT I = 42

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode avec .line (LineNumberTable) ---
.method public static greet()V
  .limit stack 2
  .limit locals 0
  .line 10
  getstatic java/lang/System/out Ljava/io/PrintStream;
  .line 11
  getstatic test26_classgen/GREETING Ljava/lang/String;
  .line 12
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 13
  return
.end method

; --- Methode avec branchement (labels) ---
.method public static abs(I)I
  .limit stack 1
  .limit locals 1
  iload_0
  ifge positive
  iload_0
  ineg
  ireturn
positive:
  iload_0
  ireturn
.end method

; --- Methode avec exception handler (.catch) ---
.method public static safeDivide(II)I
  .limit stack 2
  .limit locals 3
  .catch java/lang/ArithmeticException from startDiv to endDiv using handler
startDiv:
  iload_0
  iload_1
  idiv
  ireturn
endDiv:
handler:
  pop
  iconst_0
  ireturn
.end method

; --- Point d'entree principal ---
.method public static main([Ljava/lang/String;)V
  .limit stack 3
  .limit locals 1
  .line 100

  ; Appeler greet()
  invokestatic test26_classgen/greet()V

  ; Afficher abs(-7) = 7
  .line 101
  getstatic java/lang/System/out Ljava/io/PrintStream;
  bipush -7
  invokestatic test26_classgen/abs(I)I
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher safeDivide(10, 3) = 3
  .line 102
  getstatic java/lang/System/out Ljava/io/PrintStream;
  bipush 10
  iconst_3
  invokestatic test26_classgen/safeDivide(II)I
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher safeDivide(10, 0) = 0
  .line 103
  getstatic java/lang/System/out Ljava/io/PrintStream;
  bipush 10
  iconst_0
  invokestatic test26_classgen/safeDivide(II)I
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher le champ COUNT
  .line 104
  getstatic java/lang/System/out Ljava/io/PrintStream;
  getstatic test26_classgen/COUNT I
  invokevirtual java/io/PrintStream/println(I)V

  ; Message de succes
  .line 105
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "test26_classgen OK"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

  return
.end method
