; test28_examples.j - Test de validation TODO 25
; Verifie que les exemples couvrent toutes les fonctionnalites :
;   variables locales, arithmetique, conditions, boucles,
;   appels de methodes, manipulation de pile, tableaux, exceptions

.class public test28_examples
.super java/lang/Object
.source test28_examples.j

; Constructeur par defaut
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; Methode statique : addition
.method public static add(II)I
  .limit stack 2
  .limit locals 2
  iload_0
  iload_1
  iadd
  ireturn
.end method

; Methode principale
.method public static main([Ljava/lang/String;)V
  .limit stack 4
  .limit locals 5

  ; --- Variables locales ---
  bipush 10
  istore_1          ; x = 10
  bipush 20
  istore_2          ; y = 20

  ; --- Arithmetique ---
  iload_1
  iload_2
  iadd
  istore_3          ; z = x + y = 30

  ; --- Appel de methode statique ---
  iload_1
  iload_2
  invokestatic test28_examples/add(II)I
  istore 4          ; w = add(x, y) = 30

  ; --- Condition ---
  iload_3
  iload 4
  if_icmpne not_equal
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "OK: add result matches"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  goto end_cond
not_equal:
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "FAIL: add result mismatch"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
end_cond:

  ; --- Boucle ---
  iconst_0
  istore_1          ; i = 0
loop_start:
  iload_1
  iconst_3
  if_icmpge loop_end
  iinc 1 1          ; i++
  goto loop_start
loop_end:

  ; --- Manipulation de pile ---
  bipush 42
  dup               ; 42, 42
  pop               ; 42
  bipush 7
  swap              ; 7, 42
  pop
  pop

  ; --- Tableau ---
  iconst_3
  newarray int      ; int[3]
  dup
  iconst_0
  sipush 100
  iastore           ; arr[0] = 100
  dup
  iconst_1
  sipush 200
  iastore           ; arr[1] = 200
  dup
  iconst_0
  iaload            ; arr[0] -> 100
  pop
  pop               ; cleanup array ref

  ; --- Exception ---
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "OK: test28_examples passed"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

  return
.end method
