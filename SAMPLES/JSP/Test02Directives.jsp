<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         import="java.util.Date,java.text.DateFormat" %>
<%-- Ce commentaire JSP ne figure pas dans la reponse envoyee. --%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Directives JSP</title>
</head>
<body>
  <h1>Directive page</h1>
  <p>Langage de script : Java</p>
  <p>Encodage du source et de la reponse : UTF-8</p>
  <p>
    Date formatee :
    <%= DateFormat.getDateTimeInstance().format(new Date()) %>
  </p>
</body>
</html>

