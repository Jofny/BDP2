USE AdventureWorksDW2019;
GO

CREATE PROCEDURE Zadanie3
    @YearsAgo INT
AS
BEGIN
    SELECT CR.*
    FROM dbo.FactCurrencyRate AS CR
    INNER JOIN dbo.DimCurrency AS C
        ON CR.CurrencyKey = C.CurrencyKey
    WHERE
        CR.Date <= DATEADD(YEAR, -@YearsAgo, GETDATE())
        AND (C.CurrencyAlternateKey = 'GBP' OR C.CurrencyAlternateKey = 'EUR');
END;
GO

DECLARE @YearsAgo INT
SET @YearsAgo = 11
EXEC Zadanie3 @YearsAgo;
