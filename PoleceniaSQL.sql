USE [ContosoRetailDW]
GO

--	(A)
--	Wyjaśnij kontekst biznesowy danych:
------------------------------------------------
	SELECT	
			[ITMachinekey]
		  ,	[MachineKey]
		  ,	[Datekey]
		  ,	[CostAmount]
		  ,	[CostType]
	FROM [dbo].[FactITMachine]
	-- Koszty związane z obsługą sprzętu

--	(B)
--	Wyjaśnij popwiązania pomiędzy tabelami
--	na podstawie poniższej kwerendy:
------------------------------------------------

	SELECT	
			fm.[CostAmount]
		  ,	fm.[CostType]
		  ,	dd.[FullDateLabel]
		  ,	dm.[MachineLabel]
		  ,	dm.[MachineType]	  
		  ,	ds.[StoreType]
		  ,	ds.[StoreName]
		  ,	de.[EntityLabel]
		  ,	de.[EntityType]
		  ,	dg.[CityName]
	FROM 
				[dbo].[FactITMachine]	AS fm
	INNER JOIN	[dbo].[DimDate]			AS dd ON [dd].[Datekey]			= [fm].[Datekey]
	INNER JOIN  [dbo].[DimMachine]		AS dm ON [dm].[MachineKey]		= [fm].[MachineKey]
	INNER JOIN	[dbo].[DimStore]		AS ds ON [ds].[StoreKey]		= [dm].[StoreKey]
	INNER JOIN	[dbo].[DimEntity]		AS de ON [de].[EntityKey]		= [ds].[EntityKey]
	INNER JOIN	[dbo].[DimGeography]	AS dg ON [dg].[GeographyKey]	= [ds].[GeographyKey]
	GO
	
--	Przygotuj następujące widoki:
------------------------------------------------

	--	01	koszty utrzymania (Annual Maintenance Cost) 
	--		poniesiony przez przedsiębiorstwo w podziale na miesiące
	-------------------------------------------
	CREATE VIEW v_01MonthlyMaintenanceCost
	AS
	SELECT 
	dd.CalendarMonthLabel, 
	sum(fm.CostAmount) as [Annual Maintenance Cost]
	FROM 
				[dbo].[FactITMachine]	AS fm
	INNER JOIN	[dbo].[DimDate]			AS dd ON [dd].[Datekey]			= [fm].[Datekey]
	WHERE CostType = 'Annual Maintenance Cost'
	GROUP BY dd.CalendarMonthLabel
	GO
	
	--	02	koszty całkowite poniesione przez przedsiębiorstwo
	--		powiązane z maszynami dostarczonymi przez dostawcę (Fabrikam, Inc.)
	--		w podziale na lata
	--	
	--		Informacja o dostawcy znajduje się w wymiarze [DimMachine]
	-------------------------------------------
	CREATE VIEW v_02AnnualMaintenanceCostFabrikam
	AS
	SELECT  
	dd.CalendarYear,
	sum(fm.CostAmount) as [Annual Maintenance Cost]
	
		FROM 
				[dbo].[FactITMachine]	AS fm
	INNER JOIN	[dbo].[DimDate]			AS dd ON [dd].[Datekey]			= [fm].[Datekey]
	INNER JOIN  [dbo].[DimMachine]		AS dm ON [dm].[MachineKey]		= [fm].[MachineKey]
	WHERE dm.VendorName='Fabrikam, Inc.'
	GROUP BY dd.CalendarYear
	GO


	--	03	koszty całkowite poniesione przez przedsiębiorstwo
	--		powiązane z maszynami używanymi w sklepach znajdujących się w Europie
	--		w podziale na sklep (StoreName)
	-------------------------------------------
	CREATE VIEW v_03TotalCostByEuropeStores
	AS
	SELECT 
	ds.StoreName,
	sum(fm.CostAmount) as TotalCost
		FROM 
				[dbo].[FactITMachine]	AS fm
	INNER JOIN	[dbo].[DimDate]			AS dd ON [dd].[Datekey]			= [fm].[Datekey]
	INNER JOIN  [dbo].[DimMachine]		AS dm ON [dm].[MachineKey]		= [fm].[MachineKey]
	INNER JOIN	[dbo].[DimStore]		AS ds ON [ds].[StoreKey]		= [dm].[StoreKey]
	--INNER JOIN	[dbo].[DimEntity]		AS de ON [de].[EntityKey]		= [ds].[EntityKey]
	INNER JOIN	[dbo].[DimGeography]	AS dg ON [dg].[GeographyKey]	= [ds].[GeographyKey]
	WHERE dg.ContinentName = 'Europe'
	GROUP BY ds.StoreName

	GO

	--	04	koszty całkowite poniesione przez przedsiębiorstwo
	--		powiązane z maszynami używanymi w sklepach znajdujących się w Europie
	--		w podziale na sklep (StoreName)
	--	
	--		Dodać kolumnę z rankingiem (RANK()) gdzie pierwsze numery (1,2,3...)
	--		przyznawane są sklepom, które wygenerowały NAJWIĘKSZY koszt
	--
	--		Widok powinien zwracać 10 pierwszych sklepów
	-------------------------------------------
	CREATE VIEW v_04TotaslCostByEuropeStores
	AS
	SELECT TOP 10 
	RANK() OVER (ORDER BY sum(fm.CostAmount)  DESC) as [RANK],
	ds.StoreName,
	sum(fm.CostAmount) as TotalCost
		FROM 
				[dbo].[FactITMachine]	AS fm
	INNER JOIN	[dbo].[DimDate]			AS dd ON [dd].[Datekey]			= [fm].[Datekey]
	INNER JOIN  [dbo].[DimMachine]		AS dm ON [dm].[MachineKey]		= [fm].[MachineKey]
	INNER JOIN	[dbo].[DimStore]		AS ds ON [ds].[StoreKey]		= [dm].[StoreKey]
	INNER JOIN	[dbo].[DimGeography]	AS dg ON [dg].[GeographyKey]	= [ds].[GeographyKey]
	WHERE dg.ContinentName = 'Europe'
	GROUP BY 
	ds.StoreName
	ORDER BY TotalCost desc
	GO


	--	05	przygotować widok na podstawie zapytania z punktu (B)
	--		widok ZAINDEKSOWAC <- dodać wszystkie warunki konieczne dla indeksacji
	--		grupowanie po wszystkich kolumnach poza [CostAmount]
	--		
	-------------------------------------------	

	--	06	(***)	używając funkcjonalności CTE
	--		przygotować widok, który zwraca podsumowanie wszystkich kosztów
	--		dla trzech Grup z wymiaru DimEntity (Contoso North America, Contoso Europe, Contoso Asia)
	-------------------------------------------	