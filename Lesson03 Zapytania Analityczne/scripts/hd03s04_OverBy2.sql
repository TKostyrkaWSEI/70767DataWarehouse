USE [AdventureworksDW2016CTP3];
GO

--	http://www.cs.put.poznan.pl/mzakrzewicz/pubs/plsem02b.pdf
--	http://www.ploug.org.pl/wp-content/uploads/ploug-szkola-04-06_KJ_Anal.pdf
--	https://mndevnotes.wordpress.com/2012/06/23/nowosci-w-sql-server-2012-funkcje-analityczne/
-------------------------------------------------------------------------------------------

--	Przy używaniu funkcji analitycznych istotna jest znajomość podstawowej terminologii 

	--	Partycje:		umożliwiają podział rezultatu zapytania na autonomiczne, niezależne zbiory, w ramach których funkcje analityczne będą mogły wyznaczać oddzielne rankingi, średnie itp. 
	--	Okna:			występują tylko w przypadku funkcji okna. Pozwalają na zdefiniowane ruchomego zakresu określanego indywidualnie dla każdego wiersza w ramach którego funkcja będzie wyznaczała swoją wartość 
	--	Bieżący wiersz:	wiersz, dla którego w danym momencie wyznaczany jest wynik funkcji analitycznej. W szczególności stanowi on punkt odniesienia przy wyznaczaniu zakresu okna

--	(1)
--	przygotować raport który porównuje wykonanie danego 
--	kraju do wykonania całości w obrębie konta
--	np. Koszty w Polsce to 10, koszty w całej organizacji to 200 - pokazać 10, 200 i 5%
---------------------------------------------------------------------

	SELECT 
		a.AccountType		, 
		o.OrganizationName	,
		SUM(f.Amount)		AS [Amount]
	INTO #Dane
	FROM 
				[dbo].[FactFinance]		AS	f
	INNER JOIN	[dbo].[DimAccount]		AS	a	ON a.AccountKey			= f.AccountKey
	INNER JOIN	[dbo].[DimOrganization]	AS	o	ON o.OrganizationKey	= f.OrganizationKey
	GROUP BY
		a.AccountType		, 
		o.OrganizationName		

	SELECT *
	FROM #Dane
	ORDER BY AccountType, OrganizationName

---------------------------------------------------------------------

	SELECT AccountType,
           OrganizationName,
           Amount,
		   SUM(Amount) OVER (PARTITION BY AccountType),
		   ROUND(100 * Amount / SUM(Amount) OVER (PARTITION BY AccountType), 2)
	FROM #Dane
	ORDER BY AccountType, OrganizationName

--	(2)
--	Przygotować raport narastający (YTD - Year Till Date)
--	prezentujący wyniki do daty a nie w dacie
---------------------------------------------------------------------

	SELECT 
		CAST(f.[Date] AS DATE)			AS [Date],
		a.AccountType					AS [AccountType], 
		CAST(SUM(f.Amount) AS MONEY)	AS [Amount]
	INTO #Revenue
	FROM 
				[dbo].[FactFinance]		AS	f
	INNER JOIN	[dbo].[DimAccount]		AS	a	ON a.AccountKey			= f.AccountKey
	WHERE a.AccountType = 'Revenue'
	AND YEAR(f.[Date]) = 2012
 	GROUP BY
		f.[Date]			,
		a.AccountType
	ORDER BY f.[Date]

	SELECT *
	FROM #Revenue AS f
	ORDER BY f.[Date]

--	LAG/LEAD - poprzedni, następny w ramach okna
---------------------------------------------------------------------

	SELECT f.[Date],
		   f.AccountType,
		   f.Amount,
		   LAG(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date]),
		   LEAD(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])
	FROM #Revenue AS f
	ORDER BY f.[Date];

	SELECT f.[Date],
		   f.AccountType,
		   f.Amount,
		   100 * (f.Amount - LAG(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])) / LAG(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date]),
		   100 * (f.Amount - LAG(f.Amount,2) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])) / LAG(f.Amount,2) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])
	FROM #Revenue AS f
	ORDER BY f.[Date];

	SELECT f.[Date],
		   f.AccountType,
		   f.Amount,
		   100 * (f.Amount - LAG(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])) / LAG(f.Amount) OVER (PARTITION BY f.AccountType ORDER BY f.[Date]),
		   100 * (f.Amount - LAG(f.Amount,2) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])) / LAG(f.Amount,2) OVER (PARTITION BY f.AccountType ORDER BY f.[Date])
	FROM #Revenue AS f
	ORDER BY f.[Date];

--	numer wiersza w oknie:
---------------------------------------------------------------------

	SELECT f.[Date],
		   f.AccountType,
		   f.Amount,
		   ROW_NUMBER() OVER (PARTITION BY f.AccountType ORDER BY f.[Date]),
		   ROW_NUMBER() OVER (PARTITION BY f.AccountType ORDER BY f.[Amount] DESC)
	FROM #Revenue AS f
	ORDER BY f.[Date];

---------------------------------------------------------------------

	SELECT *
	INTO #Revenue2
	FROM #Revenue AS f
	CROSS JOIN (VALUES(1),(2),(3)) AS a(ver)
	ORDER BY f.[Date];

	SELECT *
	FROM #Revenue2

--	Rankingi:
---------------------------------------------------------------------

	SELECT 
		f.ver,
		f.[Date],
		f.AccountType,
		f.Amount,   
		RANK()			OVER (PARTITION BY f.AccountType ORDER BY f.[Amount] DESC)	AS	[rnk],
		DENSE_RANK()	OVER (PARTITION BY f.AccountType ORDER BY f.[Amount] DESC)	AS	[dns],
		NTILE(2)		OVER (PARTITION BY f.AccountType ORDER BY f.[Amount] DESC)	AS	[nt2],
		NTILE(10)		OVER (PARTITION BY f.AccountType ORDER BY f.[Amount] DESC)	AS	[nt10]
	FROM #Revenue2 AS f
	ORDER BY rnk;