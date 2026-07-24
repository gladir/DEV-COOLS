EXEMPLES J++ (.jpp)
====================

Ces fichiers illustrent le langage Microsoft Visual J++ et les clones qui
acceptent l'extension .jpp. Le compilateur Visual J++ historique utilisait
normalement l'extension .java : un compilateur donne peut donc demander de
renommer temporairement le fichier .jpp en .java.

Exemples portables Java 1.1 / J++ :

  Test01Bonjour.jpp
  Test02Variables.jpp
  Test03Instructions.jpp
  Test04Methodes.jpp
  Test05Tableaux.jpp
  Test06ProprietesBean.jpp
  Test07Heritage.jpp
  Test08Interfaces.jpp
  Test09Exceptions.jpp
  Test10Collections.jpp
  Test11Threads.jpp
  Test12Fichiers.jpp
  Test13Awt.jpp

Extensions Microsoft non portables :

  Test14Delegates.jpp
  Test15Conditionnelle.jpp
  Test16Win32.jpp
  Test17PaquetsMicrosoft.jpp
  Test18JDirect.jpp

Dans les exemples portables, le nom de la classe publique correspond au nom
du fichier sans l'extension. Exemple conceptuel avec un clone J++ :

  jpp Test01Bonjour.jpp

Avec le compilateur JVC historique, consulter l'aide de sa version. S'il
n'accepte que .java, copier ou renommer le source :

  copy Test01Bonjour.jpp Test01Bonjour.java
  jvc Test01Bonjour.java
  jview Test01Bonjour

Les exemples 14 a 18 exigent Visual J++, la MSJVM ou les SDK Microsoft
appropries. Ils ne sont pas compilables avec un javac standard.

