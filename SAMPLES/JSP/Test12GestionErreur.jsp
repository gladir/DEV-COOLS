<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         isErrorPage="true" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Erreur traitee</title>
</head>
<body>
  <h1>Une erreur a ete interceptee</h1>
  <p>Type : <%= exception.getClass().getName() %></p>
  <p>
    Le detail interne n'est volontairement pas affiche.
    Il doit etre consigne cote serveur.
  </p>
</body>
</html>

