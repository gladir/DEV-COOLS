<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
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
  String nom = request.getParameter("nom");
  String langage = request.getParameter("langage");
  boolean envoye = "POST".equalsIgnoreCase(request.getMethod());
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Formulaire JSP</title>
</head>
<body>
  <h1>Preferences</h1>
  <form method="post" action="Test06Formulaire.jsp">
    <p>
      <label>Nom :
        <input name="nom" value="<%= html(nom) %>" required>
      </label>
    </p>
    <p>
      <label>Langage :
        <select name="langage">
          <option value="Java">Java</option>
          <option value="JSP">JSP</option>
          <option value="Jakarta">Jakarta</option>
        </select>
      </label>
    </p>
    <button type="submit">Envoyer</button>
  </form>

  <% if (envoye) { %>
    <% if (nom == null || nom.trim().length() == 0) { %>
      <p>Le nom est obligatoire.</p>
    <% } else { %>
      <p>
        Bonjour <%= html(nom.trim()) %>.
        Choix : <%= html(langage) %>.
      </p>
    <% } %>
  <% } %>
</body>
</html>

