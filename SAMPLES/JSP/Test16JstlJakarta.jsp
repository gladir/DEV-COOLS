<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Jakarta Tags</title>
</head>
<body>
  <h1>JSTL dans un environnement Jakarta moderne</h1>

  <c:set var="titre" value="Jakarta Server Pages" />
  <p>
    Titre : <c:out value="${titre}" />
  </p>
  <p>
    Longueur : ${fn:length(titre)}
  </p>

  <c:if test="${empty param.recherche}">
    <p>Le parametre <code>recherche</code> est absent.</p>
  </c:if>
  <c:if test="${not empty param.recherche}">
    <p>Recherche : <c:out value="${param.recherche}" /></p>
  </c:if>

  <ol>
    <c:forEach var="numero" begin="1" end="5">
      <li>Element ${numero}</li>
    </c:forEach>
  </ol>
</body>
</html>

