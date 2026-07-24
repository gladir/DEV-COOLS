<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Directive include</title>
</head>
<body>
  <%@ include file="FragmentEntete.jsp" %>
  <main>
    <h1>Inclusion statique</h1>
    <p>
      La directive include fusionne le fragment avec la page pendant
      la traduction JSP.
    </p>
  </main>
  <%@ include file="FragmentPied.jsp" %>
</body>
</html>

