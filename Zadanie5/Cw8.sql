use AdventureWorksDW2019;

SELECT OrderDate, COUNT(*) AS OrdersCount
FROM dbo.FactInternetSales
GROUP BY OrderDate
HAVING COUNT(*) < 100
ORDER BY OrdersCount DESC;


WITH RankedProducts AS (
    SELECT OrderDate, ProductKey, UnitPrice, ROW_NUMBER() OVER (PARTITION BY OrderDate ORDER BY UnitPrice DESC) AS Ranking
    FROM dbo.FactInternetSales
)
SELECT OrderDate, ProductKey, UnitPrice
FROM RankedProducts
WHERE Ranking <= 3
ORDER BY OrderDate, Ranking;