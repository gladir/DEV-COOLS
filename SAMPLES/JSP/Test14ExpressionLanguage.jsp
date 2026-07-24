<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
  request.setAttribute("prixUnitaire", Integer.valueOf(125));
  request.setAttribute("quantite", Integer.valueOf(4));
  session.setAttribute("utilisateur", "Grace");
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Expression Language</title>
</head>
<body>
  <h1>Langage d'expressions JSP</h1>
  <ul>
    <li>Le parametre nom est absent : ${empty param.nom}</li>
    <li>Utilisateur : ${sessionScope.utilisateur}</li>
    <li>Prix : ${requestScope.prixUnitaire}</li>
    <li>Quantite : ${requestScope.quantite}</li>
    <li>Total : ${prixUnitaire * quantite}</li>
    <li>Au moins trois articles : ${quantite ge 3}</li>
  </ul>
  <p>
    EL simplifie l'acces aux attributs et aux proprietes, mais son
    resultat doit etre echappe lorsqu'il peut contenir une saisie.
  </p>
</body>
</html>
