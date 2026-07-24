<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         errorPage="Test12GestionErreur.jsp" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Declenchement d'une erreur</title>
</head>
<body>
  <h1>Demonstration de errorPage</h1>
  <p>La prochaine expression declenche une division par zero.</p>
  <p>Resultat : <%= 10 / Integer.parseInt("0") %></p>
</body>
</html>
