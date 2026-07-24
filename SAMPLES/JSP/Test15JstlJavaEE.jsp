<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ taglib prefix="c"
           uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn"
           uri="http://java.sun.com/jsp/jstl/functions" %>
<%
  request.setAttribute(
      "langages",
      new String[] { "Java", "JSP", "JSTL" });
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>JSTL Java EE historique</title>
</head>
<body>
  <h1>Conditions et boucle JSTL</h1>
  <c:choose>
    <c:when test="${empty param.nom}">
      <p>Ajouter <code>?nom=Ada</code> a l'adresse.</p>
    </c:when>
    <c:otherwise>
      <p>Bonjour <c:out value="${param.nom}" />.</p>
    </c:otherwise>
  </c:choose>

  <ul>
    <c:forEach var="langage" items="${langages}">
      <li>
        <c:out value="${langage}" />
        (${fn:length(langage)} caracteres)
      </li>
    </c:forEach>
  </ul>
</body>
</html>
