SELECT COUNT(*) AS TotalRows FROM Employees
GO
SELECT SUM(Salary) AS TotalSalary FROM Employees
GO
SELECT AVG(Salary) AS AvgSalary FROM Employees
GO
SELECT MIN(Salary) AS MinSalary, MAX(Salary) AS MaxSalary FROM Employees
GO
SELECT Department, COUNT(*) AS Cnt, AVG(Salary) AS AvgSal FROM Employees GROUP BY Department
GO
SELECT Department, COUNT(*) AS Cnt FROM Employees GROUP BY Department HAVING COUNT(*) > 1
GO
