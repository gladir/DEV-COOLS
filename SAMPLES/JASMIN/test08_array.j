; test08_array.j - Creation et manipulation de tableaux
; Test de newarray, iastore, iaload, arraylength

.class public test08_array
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 4
  .limit locals 3

  ; int[] arr = new int[5]
  iconst_5
  newarray int
  astore_1

  ; arr[0] = 10, arr[1] = 20, arr[2] = 30, arr[3] = 40, arr[4] = 50
  aload_1
  iconst_0
  bipush 10
  iastore

  aload_1
  iconst_1
  bipush 20
  iastore

  aload_1
  iconst_2
  bipush 30
  iastore

  aload_1
  iconst_3
  bipush 40
  iastore

  aload_1
  iconst_4
  bipush 50
  iastore

  ; Afficher arr.length = 5
  getstatic java/lang/System/out Ljava/io/PrintStream;
  aload_1
  arraylength
  invokevirtual java/io/PrintStream/println(I)V

  ; Boucle : afficher chaque element
  iconst_0
  istore_2
ArrayLoop:
  iload_2
  aload_1
  arraylength
  if_icmpge ArrayEnd
  getstatic java/lang/System/out Ljava/io/PrintStream;
  aload_1
  iload_2
  iaload
  invokevirtual java/io/PrintStream/println(I)V
  iinc 2 1
  goto ArrayLoop
ArrayEnd:

  return
.end method
