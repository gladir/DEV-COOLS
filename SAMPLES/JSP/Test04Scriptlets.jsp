<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Scriptlets historiques</title>
</head>
<body>
  <h1>Boucle produite par un scriptlet</h1>
  <ul>
  <%
    int total = 0;
    for (int i = 1; i <= 5; i++) {
      total += i;
  %>
    <li>Valeur <%= i %></li>
  <%
    }
  %>
  </ul>
  <p>Total : <%= total %></p>
  <p>
    Dans un nouveau projet, une balise JSTL c:forEach est preferable
    a cette construction.
  </p>
</body>
</html>

