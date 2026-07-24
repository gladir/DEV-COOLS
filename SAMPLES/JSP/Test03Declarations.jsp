<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%!
  /*
   * Une declaration devient un membre de la servlet generee.
   * Elle ne doit pas conserver un etat mutable propre a une requete.
   */
  private String nomApplication() {
    return "Catalogue JSP";
  }

  private int carre(int valeur) {
    return valeur * valeur;
  }
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Declarations JSP</title>
</head>
<body>
  <h1><%= nomApplication() %></h1>
  <p>Le carre de 12 vaut <%= carre(12) %>.</p>
</body>
</html>

