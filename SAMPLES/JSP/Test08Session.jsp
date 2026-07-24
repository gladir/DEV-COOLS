<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         session="true" %>
<%!
  private String html(String valeur) {
    if (valeur == null) {
      return "";
    }
    return valeur.replace("&", "&amp;")
                 .replace("<", "&lt;")
                 .replace(">", "&gt;")
                 .replace("\"", "&quot;");
  }
%>
<%
  request.setCharacterEncoding("UTF-8");
  String action = request.getParameter("action");
  String nom = request.getParameter("nom");

  if ("enregistrer".equals(action)
      && nom != null
      && nom.trim().length() != 0) {
    session.setAttribute("nomVisiteur", nom.trim());
  } else if ("effacer".equals(action)) {
    session.removeAttribute("nomVisiteur");
  }

  String nomVisiteur =
      (String)session.getAttribute("nomVisiteur");
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Session JSP</title>
</head>
<body>
  <h1>Attribut de session</h1>
  <% if (nomVisiteur == null) { %>
    <p>Aucun nom n'est memorise.</p>
  <% } else { %>
    <p>Nom memorise : <strong><%= html(nomVisiteur) %></strong></p>
  <% } %>

  <form method="post" action="Test08Session.jsp">
    <input type="hidden" name="action" value="enregistrer">
    <label>Nom : <input name="nom" required></label>
    <button type="submit">Memoriser</button>
  </form>
  <p>
    <a href="Test08Session.jsp?action=effacer">Effacer la valeur</a>
  </p>
</body>
</html>

