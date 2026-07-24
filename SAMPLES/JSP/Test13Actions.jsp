<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<jsp:useBean id="calendrier"
             class="java.util.GregorianCalendar"
             scope="page" />
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Actions JSP standard</title>
</head>
<body>
  <h1>jsp:useBean</h1>
  <p>
    L'action a cree ou retrouve une instance de
    <code>java.util.GregorianCalendar</code>.
  </p>
  <p>
    Millisecondes depuis l'epoque Unix :
    <jsp:getProperty name="calendrier"
                     property="timeInMillis" />
  </p>
  <p>
    Pour un bean applicatif, <code>jsp:setProperty</code> appelle un
    setter JavaBean et <code>jsp:getProperty</code> appelle son getter.
  </p>
</body>
</html>
