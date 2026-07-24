<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Action jsp:include</title>
</head>
<body>
  <jsp:include page="FragmentEntete.jsp" flush="true" />
  <main>
    <h1>Inclusion dynamique</h1>
    <p>
      L'action <code>jsp:include</code> execute la ressource incluse
      pour chaque requete.
    </p>
  </main>
  <jsp:include page="FragmentPied.jsp" flush="true" />
</body>
</html>

