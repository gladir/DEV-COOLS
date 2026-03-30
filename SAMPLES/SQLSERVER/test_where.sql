-- Test des operateurs WHERE SQL Server
SELECT * FROM Employees WHERE Salary BETWEEN 40000 AND 60000
GO
SELECT * FROM Employees WHERE Department IN ('Engineering', 'Sales')
GO
SELECT * FROM Employees WHERE LastName LIKE 'D%'
GO
SELECT * FROM Employees WHERE LastName IS NOT NULL
GO
SELECT * FROM Employees WHERE Salary > 50000 AND Department = 'Engineering'
GO
SELECT * FROM Employees WHERE Salary > 70000 OR Department = 'Sales'
GO
