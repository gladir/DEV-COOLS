<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%!
  private String echapperHtml(String valeur) {
    if (valeur == null) {
      return "";
    }
    return valeur.replace("&", "&amp;")
                 .replace("<", "&lt;")
                 .replace(">", "&gt;")
                 .replace("\"", "&quot;")
                 .replace("'", "&#39;");
  }
%>
<%
  request.setCharacterEncoding("UTF-8");
  String nom = request.getParameter("nom");
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Parametres JSP</title>
</head>
<body>
  <h1>Lecture d'un parametre</h1>
  <p>Essayer l'adresse <code>?nom=Ada</code>.</p>
  <% if (nom == null || nom.length() == 0) { %>
    <p>Aucun nom n'a ete fourni.</p>
  <% } else { %>
    <p>Bonjour <strong><%= echapperHtml(nom) %></strong>.</p>
  <% } %>
</body>
</html>

