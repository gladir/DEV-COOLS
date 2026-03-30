-- Test des variables et DECLARE SQL Server
DECLARE @x INT
SET @x = 42
SELECT @x AS Expr1
GO
DECLARE @name VARCHAR(50)
SET @name = 'SQL Server'
SELECT @name AS Expr1
GO
DECLARE @pi FLOAT
SET @pi = 3.14159
SELECT @pi AS Expr1
GO
