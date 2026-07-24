<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ taglib prefix="c"
           uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn"
           uri="http://java.sun.com/jsp/jstl/functions" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Echappement avec JSTL</title>
</head>
<body>
  <h1>Sorties controlees</h1>
  <p>
    c:out :
    <c:out value="${param.texte}"
           default="Ajouter ?texte=&lt;exemple&gt;" />
  </p>
  <p>
    fn:escapeXml :
    ${fn:escapeXml(empty param.texte ? '(absent)' : param.texte)}
  </p>
  <p>
    Ne jamais injecter directement une saisie dans un script, un style,
    une URL ou un attribut sans appliquer l'encodage adapte au contexte.
  </p>
</body>
</html>

