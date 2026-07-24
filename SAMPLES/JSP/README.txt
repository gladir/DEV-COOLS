EXEMPLES JSP / JAKARTA SERVER PAGES
===================================

Ce dossier contient des exemples portant l'extension .jsp. Ils doivent etre
deployes dans une application Web prise en charge par un conteneur JSP.

Pages sans dependance JSTL :

  Test01Bonjour.jsp          page minimale
  Test02Directives.jsp       directives page et commentaires
  Test03Declarations.jsp     declarations et expressions historiques
  Test04Scriptlets.jsp       instructions Java historiques
  Test05Parametres.jsp       lecture et echappement d'un parametre
  Test06Formulaire.jsp       formulaire traite par la meme page
  Test07ObjetsImplicites.jsp request, response et autres objets implicites
  Test08Session.jsp          etat conserve dans la session
  Test09Application.jsp      compteur partage par l'application
  Test10Include.jsp          inclusion statique
  Test11IncludeAction.jsp    inclusion dynamique avec jsp:include
  Test12Erreur.jsp           page qui declare une page d'erreur
  Test12GestionErreur.jsp    page d'erreur correspondante
  Test13Actions.jsp          jsp:useBean, jsp:setProperty et jsp:getProperty
  Test14ExpressionLanguage.jsp langage d'expressions EL
  FragmentEntete.jsp         fragment inclus
  FragmentPied.jsp           fragment inclus

Pages qui exigent une implementation JSTL :

  Test15JstlJavaEE.jsp       URI JSTL historique Java EE
  Test16JstlJakarta.jsp      URI Jakarta Tags moderne
  Test17JstlXml.jsp          echappement XML avec JSTL historique

Les API Servlet/JSP ont change de nom de paquet lors du passage de Java EE a
Jakarta EE :

  Java EE historique     javax.servlet.*
  Jakarta EE moderne     jakarta.servlet.*

Les objets implicites JSP evitent d'importer directement l'un de ces paquets;
la plupart des pages simples fonctionnent donc dans les deux familles.

Pour les pages JSTL, choisir l'exemple correspondant au conteneur et aux
bibliotheques installes :

  Java EE / JSTL ancien  http://java.sun.com/jsp/jstl/core
  Jakarta Tags moderne  jakarta.tags.core

Les declarations `<%! ... %>` et scriptlets `<% ... %>` sont documentes parce
qu'ils appartiennent au langage JSP historique. Dans une application moderne,
placer la logique dans des servlets, controleurs ou services, puis employer
EL et les bibliotheques de balises dans la vue.

Deploiement conceptuel :

  1. copier ce dossier dans la racine Web de l'application;
  2. demarrer le conteneur;
  3. ouvrir /JSP/Test01Bonjour.jsp dans le navigateur.

Ne pas publier directement les pages de demonstration d'erreur ou les pages
contenant des informations de diagnostic dans une application de production.

