GO
SELECT 1 AS One, 2 AS Two, 3 AS Three
GO
SELECT 'Hello' AS Greeting, 42 AS Answer
GO
SELECT 1 + 2 AS Addition, 10 - 3 AS Subtraction, 4 * 5 AS Multiplication
GO
SELECT 10 / 3 AS IntDiv, 10 % 3 AS Modulo
GO
SELECT TOP 3 * FROM Employees ORDER BY Salary DESC
GO
SELECT DISTINCT Department FROM Employees
GO
SELECT * FROM Employees WHERE Salary > 50000
GO
SELECT * FROM Employees WHERE Department = 'Engineering'
GO
SELECT * FROM Employees ORDER BY LastName ASC
GO
