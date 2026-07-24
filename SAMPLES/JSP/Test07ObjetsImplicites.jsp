<%@ page contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%!
  private String html(String valeur) {
    if (valeur == null) {
      return "";
    }
    return valeur.replace("&", "&amp;")
                 .replace("<", "&lt;")
                 .replace(">", "&gt;");
  }
%>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Objets implicites</title>
</head>
<body>
  <h1>Objets implicites JSP</h1>
  <dl>
    <dt>request.getMethod()</dt>
    <dd><%= html(request.getMethod()) %></dd>
    <dt>request.getRequestURI()</dt>
    <dd><%= html(request.getRequestURI()) %></dd>
    <dt>request.getRemoteAddr()</dt>
    <dd><%= html(request.getRemoteAddr()) %></dd>
    <dt>response.getContentType()</dt>
    <dd><%= html(response.getContentType()) %></dd>
    <dt>session.getId()</dt>
    <dd><%= html(session.getId()) %></dd>
    <dt>application.getServerInfo()</dt>
    <dd><%= html(application.getServerInfo()) %></dd>
    <dt>config.getServletName()</dt>
    <dd><%= html(config.getServletName()) %></dd>
  </dl>
  <p>
    Autres objets disponibles : <code>out</code>, <code>page</code>,
    <code>pageContext</code> et, sur une page d'erreur,
    <code>exception</code>.
  </p>
</body>
</html>

