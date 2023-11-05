use AdventureWorksDW2019;

/*DESCRIBE AdventureWorksDW2019.dbo.FactInternetSales; /*Oracle */*/

SELECT *
FROM information_schema.columns
WHERE table_schema = 'dbo'
AND table_name = 'FactInternetSales'; /*Postgres*/

/*DESCRIBE AdventureWorksDW2019.dbo.FactInternetSales; /*MySql */*/