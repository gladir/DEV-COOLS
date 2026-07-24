<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
  Integer nombreVisites;
  synchronized (application) {
    nombreVisites =
        (Integer)application.getAttribute("nombreVisites");
    if (nombreVisites == null) {
      nombreVisites = Integer.valueOf(0);
    }
    nombreVisites = Integer.valueOf(nombreVisites.intValue() + 1);
    application.setAttribute("nombreVisites", nombreVisites);
  }
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Portee application</title>
</head>
<body>
  <h1>Attribut partage par l'application</h1>
  <p>Nombre de chargements : <%= nombreVisites %></p>
  <p>
    Le verrou protege ici la sequence lecture-modification-ecriture.
    Une application reelle emploierait un service ou un compteur atomique.
  </p>
</body>
</html>

