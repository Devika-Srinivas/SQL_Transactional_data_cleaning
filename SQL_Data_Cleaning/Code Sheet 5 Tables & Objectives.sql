-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------BRINGING THE DATA TOGETHER--------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

----To Select the Database
USE [Transactional data Test]

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------INSPECTING THE DATA--------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

----Lookup Tables
SELECT TOP 10 * FROM Store_Lookup
SELECT TOP 10 * FROM Sellers_Lookup
SELECT TOP 10 * FROM Calendar_Lookup

------Data Tables 
SELECT * FROM Opportunities_Wk25
SELECT * FROM Business_Targets
SELECT * FROM Revenue_Wk25

-------Ojective 1
--We want to see the performance of our revenue over months
--We want to see the partner fee and registration fee over months
--We want to compare Revenue vs Targets
--We want to have a forecast until the end of the year
--We want to have a baseline
--We want to have a runrate
--We want to be able to slice the data by all categories

-------Objective 2
---We want to see all opportunities in one view

-----Objective 3
---We want to be able to have the opportunity changes WoW
---We want to have calculated fields on WoW changes

---Always start with the important table, in this case sales/revenue

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------CLEANING REVENUE TABLE------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM Revenue_Wk25

----Step 1 Renaming columns
SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
Revenue FROM Revenue_Wk25

-----Step 2 Split different types of Revenue
SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee FROM Revenue_Wk25

---SELECT DISTINCT Product_Category FROM Revenue_Wk25
---SELECT DISTINCT Service_Comp_Group FROM Business_Targets

----Step 3 Summarizing product category

SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
CASE
	WHEN Product_Category LIKE '%Service%' THEN 'Services'
	WHEN Product_Category LIKE '%Support%' THEN 'Support'
	WHEN Product_Category LIKE '%Product%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category_2,
IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee 
FROM Revenue_Wk25 

---24,803 rows

----Summing the data with new Product Category

SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
SUM(Revenue) AS Revenue,
SUM(Partner_Fee) AS Partner_Fee,
SUM(Registration_Fee) AS Registration_Fee 
FROM
	(
	SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
	CASE
		WHEN Product_Category LIKE '%Service%' THEN 'Services'
		WHEN Product_Category LIKE '%Support%' THEN 'Support'
		WHEN Product_Category LIKE '%Product%' THEN 'Products'
		ELSE 'Need Mapping'
		END AS Product_Category_2,
	IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
	IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
	IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
	FROM Revenue_Wk25
	) a
GROUP BY Account_No,Fiscal_Month, Product_Category_2

----13,703 rows	

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------CLEANING OPPORTUNITIES TABLE------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM Opportunities_Wk25

--- Step 1 Fixing the Product Category

SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
CASE
	WHEN Product LIKE '%Service%' THEN 'Services'
	WHEN Product LIKE '%Support%' THEN 'Support'
	WHEN Product LIKE '%Product%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
WHERE Product IS NOT NULL AND Product <> 'Null'

--- 12317 rows

--- Step 2 Joining with Calendar table 

SELECT a.Account_No, a.Product_Category, b.Fiscal_Month,
SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
FROM

	(
	SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
	CASE
		WHEN Product LIKE '%Service%' THEN 'Services'
		WHEN Product LIKE '%Support%' THEN 'Support'
		WHEN Product LIKE '%Product%' THEN 'Products'
		ELSE 'Need Mapping'
		END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
	Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
	WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
	) a

	LEFT JOIN
	(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
	ON a.Opportunity_Est_Date = b.Date_Value
GROUP BY Account_No, Product_Category,b.Fiscal_Month

--- 5,866 rows

---- Step 3 Extrabulation 

SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
FROM
	(
	SELECT a.*, 
	CASE
		WHEN Fiscal_Month LIKE '%July%' THEN 11
		WHEN Fiscal_Month LIKE '%August%' THEN 10
		WHEN Fiscal_Month LIKE '%September%' THEN 9
		WHEN Fiscal_Month LIKE '%October%' THEN 8
		WHEN Fiscal_Month LIKE '%November%' THEN 7
		WHEN Fiscal_Month LIKE '%December%' THEN 6
		WHEN Fiscal_Month LIKE '%January%' THEN 5
		WHEN Fiscal_Month LIKE '%February%' THEN 4
		WHEN Fiscal_Month LIKE '%March%' THEN 3
		WHEN Fiscal_Month LIKE '%April%' THEN 2
		WHEN Fiscal_Month LIKE '%May%' THEN 1
		WHEN Fiscal_Month LIKE '%June%' THEN 0
		END AS Extrap_Months_Left_For_FY

	FROM

		(
		SELECT a.Account_No, a.Product_Category, b.Fiscal_Month,
		SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
		FROM

			(
			SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
			CASE
				WHEN Product LIKE '%Service%' THEN 'Services'
				WHEN Product LIKE '%Support%' THEN 'Support'
				WHEN Product LIKE '%Product%' THEN 'Products'
				ELSE 'Need Mapping'
				END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
			Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
			WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
			) a

			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Opportunity_Est_Date = b.Date_Value
		GROUP BY Account_No, Product_Category,b.Fiscal_Month
		) a
	)a

-------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------JOINING REVENUE TABLE WITH OPPORTUNITIES TABLE--------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------
	
--- Account_No, Fiscal_Month, Product_Category from revenue
--- Account_No, Fiscal_Month, Producy_Category from opportunities, 
---however Fiscal_Month does not look same in both tables 2023-07-18, July, 2019 need to fix that

SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL(Revenue, 0) AS Revenue, 
ISNULL(Partner_Fee, 0) AS Partner_Fee, 
ISNULL(Registration_Fee, 0) AS Registration_Fee, 
ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
ISNULL(Opportunity_Extrap, 0) AS Opportunity_Extrap
FROM
	(----Revenue Dataset
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
	FROM (
		SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
		SUM(Revenue) AS Revenue,
		SUM(Partner_Fee) AS Partner_Fee,
		SUM(Registration_Fee) AS Registration_Fee 
		FROM
			(
			SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
			CASE
				WHEN Product_Category LIKE '%Service%' THEN 'Services'
				WHEN Product_Category LIKE '%Support%' THEN 'Support'
				WHEN Product_Category LIKE '%Product%' THEN 'Products'
				ELSE 'Need Mapping'
				END AS Product_Category_2,
			IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
			IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
			IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
			FROM Revenue_Wk25
			) a
		GROUP BY Account_No,Fiscal_Month, Product_Category_2
		)a
		LEFT JOIN 
		(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
		ON a.Fiscal_Month = b.Fiscal_Month
	) a

	FULL JOIN

	(---- Opportunities Dataset 
	SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
	FROM
		(
		SELECT a.*, 
		CASE
			WHEN Fiscal_Month LIKE '%July%' THEN 11
			WHEN Fiscal_Month LIKE '%August%' THEN 10
			WHEN Fiscal_Month LIKE '%September%' THEN 9
			WHEN Fiscal_Month LIKE '%October%' THEN 8
			WHEN Fiscal_Month LIKE '%November%' THEN 7
			WHEN Fiscal_Month LIKE '%December%' THEN 6
			WHEN Fiscal_Month LIKE '%January%' THEN 5
			WHEN Fiscal_Month LIKE '%February%' THEN 4
			WHEN Fiscal_Month LIKE '%March%' THEN 3
			WHEN Fiscal_Month LIKE '%April%' THEN 2
			WHEN Fiscal_Month LIKE '%May%' THEN 1
			WHEN Fiscal_Month LIKE '%June%' THEN 0
			END AS Extrap_Months_Left_For_FY

		FROM

			(
			SELECT a.Account_No, a.Product_Category, b.Fiscal_Month,
			SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
			FROM

				(
				SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
				CASE
					WHEN Product LIKE '%Service%' THEN 'Services'
					WHEN Product LIKE '%Support%' THEN 'Support'
					WHEN Product LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
				Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
				WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
				) a

				LEFT JOIN
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
				ON a.Opportunity_Est_Date = b.Date_Value
			GROUP BY Account_No, Product_Category,b.Fiscal_Month
			) a
		)a
	)b
	ON a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category

---Always join on all distinct columns to avoid duplication in this case we have three account no, fiscal month and product category. 

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------CREATING A BASELINE---------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

----We have taken last month as baseline in this course, generally last 3 months or last 6 months average is taken as baseline 

SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
FROM
	(
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
	FROM (
			SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
			SUM(Revenue) AS Revenue,
			SUM(Partner_Fee) AS Partner_Fee,
			SUM(Registration_Fee) AS Registration_Fee 
			FROM
				(
				SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
				CASE
					WHEN Product_Category LIKE '%Service%' THEN 'Services'
					WHEN Product_Category LIKE '%Support%' THEN 'Support'
					WHEN Product_Category LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category_2,
				IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
				IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
				IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
				FROM Revenue_Wk25
				) a
			GROUP BY Account_No,Fiscal_Month, Product_Category_2
			)a
			LEFT JOIN 
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
			ON a.Fiscal_Month = b.Fiscal_Month

			WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup 
			WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
	)a

	CROSS JOIN

	(
	SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
	(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
	(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
	)b

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------CLEANING TARGET TABLE---------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM Business_Targets

SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target] 
FROM 
	(SELECT Store_Number AS Account_No, Service_Comp_Group AS Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a ----16,014

	LEFT JOIN 
	(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
	ON a.Fiscal_Month = b.Date_Value

---16,014
	
-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------JOINING BASELINE WITH TARGETS-----------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL(Baseline, 0) AS Baseline,
ISNULL([Target], 0) AS [Target]
FROM
	(
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
	FROM
		(
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
		FROM (
				SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
				SUM(Revenue) AS Revenue,
				SUM(Partner_Fee) AS Partner_Fee,
				SUM(Registration_Fee) AS Registration_Fee 
				FROM
					(
					SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
					CASE
						WHEN Product_Category LIKE '%Service%' THEN 'Services'
						WHEN Product_Category LIKE '%Support%' THEN 'Support'
						WHEN Product_Category LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category_2,
					IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
					IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
					IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
					FROM Revenue_Wk25
					) a
				GROUP BY Account_No,Fiscal_Month, Product_Category_2
				)a
				LEFT JOIN 
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
				ON a.Fiscal_Month = b.Fiscal_Month

				WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup 
				WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		)a

		CROSS JOIN

		(
		SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
		(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
		(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		)b
	)a

	FULL JOIN

	(
	SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target] 
	FROM 
		(SELECT Store_Number AS Account_No, Service_Comp_Group AS Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a ----16,014

		LEFT JOIN 
		(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
		ON a.Fiscal_Month = b.Date_Value
	)b
	ON 
	a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------OPPORTUNITIES INTO RR-------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, 
IIF(Opportunity_Usage < 0, 0, Opportunity_Usage)  AS Opportunity_Into_RR
FROM
	(SELECT a.*, b.Fiscal_Month AS Future_fiscal_Months, b.Month_ID AS Est_Month_ID
	FROM
		(
		SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
			FROM
				(
				SELECT a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID,
				SUM(a.Opportunity_Usage) AS Opportunity_Usage,

				CASE
					WHEN Fiscal_Month LIKE '%July%' THEN 11
					WHEN Fiscal_Month LIKE '%August%' THEN 10
					WHEN Fiscal_Month LIKE '%September%' THEN 9
					WHEN Fiscal_Month LIKE '%October%' THEN 8
					WHEN Fiscal_Month LIKE '%November%' THEN 7
					WHEN Fiscal_Month LIKE '%December%' THEN 6
					WHEN Fiscal_Month LIKE '%January%' THEN 5
					WHEN Fiscal_Month LIKE '%February%' THEN 4
					WHEN Fiscal_Month LIKE '%March%' THEN 3
					WHEN Fiscal_Month LIKE '%April%' THEN 2
					WHEN Fiscal_Month LIKE '%May%' THEN 1
					WHEN Fiscal_Month LIKE '%June%' THEN 0
					END AS Extrap_Months_Left_For_FY

				FROM

					(
					SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, b.Month_ID, 
					SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
					FROM

						(
						SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
						CASE
							WHEN Product LIKE '%Service%' THEN 'Services'
							WHEN Product LIKE '%Support%' THEN 'Support'
							WHEN Product LIKE '%Product%' THEN 'Products'
							ELSE 'Need Mapping'
							END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
						Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
						WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
						) a

						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
						ON a.Opportunity_Est_Date = b.Date_Value
					WHERE ----WHERE IN Option 1 ('','','','')
					a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND 
					b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
					GROUP BY Account_No, Product_Category,b.Fiscal_Month,b.Month_ID
					) a
				GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID
			)a
		)a 
	
		CROSS JOIN 

		(
		SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
		(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
		(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) 
		)b
	---9,605 rows
	WHERE a.Month_ID <= b.Month_ID
		)a
	---5,814 rows

		LEFT JOIN 
		(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup)b 
		ON a.Est_Month_ID = b.Month_ID

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------BRINGING ALL THE VIEWS TOGETHER---------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
----We have the revenue + Opportunities full join 
----We have baseline + Targets full join
----We have opportunites into RR table 

----Phase 1 - Full Join Baseline into Targets + Milestone into RR Tables 

SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL(a.Baseline, 0) AS Baseline,
ISNULL(a.[Target], 0) AS [Target],
ISNULL(Opportunity_Into_RR,0) AS Opportunity_Into_RR
FROM


	(----This is Baseline + Targets
	SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
	ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(Baseline, 0) AS Baseline,
	ISNULL([Target], 0) AS [Target]
	FROM
		(---This is Baseline
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
		FROM
			(
			SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
			FROM (
					SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
					SUM(Revenue) AS Revenue,
					SUM(Partner_Fee) AS Partner_Fee,
					SUM(Registration_Fee) AS Registration_Fee 
					FROM
						(
						SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
						CASE
							WHEN Product_Category LIKE '%Service%' THEN 'Services'
							WHEN Product_Category LIKE '%Support%' THEN 'Support'
							WHEN Product_Category LIKE '%Product%' THEN 'Products'
							ELSE 'Need Mapping'
							END AS Product_Category_2,
						IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
						IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
						IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
						FROM Revenue_Wk25
						) a
					GROUP BY Account_No,Fiscal_Month, Product_Category_2
					)a
					LEFT JOIN 
					(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
					ON a.Fiscal_Month = b.Fiscal_Month

					WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup 
					WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
			)a

			CROSS JOIN

			(
			SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
			(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
			(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
			)b
		)a

		FULL JOIN

		(---This is Targets
		SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target] 
		FROM 
			(SELECT Store_Number AS Account_No, Service_Comp_Group AS Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a ----16,014

			LEFT JOIN 
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
			ON a.Fiscal_Month = b.Date_Value
		)b
		ON 
		a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	)a

	FULL JOIN 
	(---This is opportunities into RR 
	SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, 
	IIF(Opportunity_Usage < 0, 0, Opportunity_Usage)  AS Opportunity_Into_RR
	FROM
		(SELECT a.*, b.Fiscal_Month AS Future_fiscal_Months, b.Month_ID AS Est_Month_ID
		FROM
			(
			SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
				FROM
					(
					SELECT a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID,
					SUM(a.Opportunity_Usage) AS Opportunity_Usage,

					CASE
						WHEN Fiscal_Month LIKE '%July%' THEN 11
						WHEN Fiscal_Month LIKE '%August%' THEN 10
						WHEN Fiscal_Month LIKE '%September%' THEN 9
						WHEN Fiscal_Month LIKE '%October%' THEN 8
						WHEN Fiscal_Month LIKE '%November%' THEN 7
						WHEN Fiscal_Month LIKE '%December%' THEN 6
						WHEN Fiscal_Month LIKE '%January%' THEN 5
						WHEN Fiscal_Month LIKE '%February%' THEN 4
						WHEN Fiscal_Month LIKE '%March%' THEN 3
						WHEN Fiscal_Month LIKE '%April%' THEN 2
						WHEN Fiscal_Month LIKE '%May%' THEN 1
						WHEN Fiscal_Month LIKE '%June%' THEN 0
						END AS Extrap_Months_Left_For_FY

					FROM

						(
						SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, b.Month_ID, 
						SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
						FROM

							(
							SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
							CASE
								WHEN Product LIKE '%Service%' THEN 'Services'
								WHEN Product LIKE '%Support%' THEN 'Support'
								WHEN Product LIKE '%Product%' THEN 'Products'
								ELSE 'Need Mapping'
								END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
							Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
							WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
							) a

							LEFT JOIN
							(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
							ON a.Opportunity_Est_Date = b.Date_Value
						WHERE ----WHERE IN Option 1 ('','','','')
						a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND 
						b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
						GROUP BY Account_No, Product_Category,b.Fiscal_Month,b.Month_ID
						) a
					GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID
				)a
			)a 
	
			CROSS JOIN 

			(
			SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
			(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
			(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) 
			)b
		---9,605 rows
		WHERE a.Month_ID <= b.Month_ID
			)a
		---5,814 rows

			LEFT JOIN 
			(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup)b 
			ON a.Est_Month_ID = b.Month_ID
		)b
ON a.Account_No = b.Account_No AND a.Product_Category = b.Product_Category AND a.Fiscal_Month = b.Fiscal_Month
----1,91,870 rows

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------JOINING ALL VIEWS-----------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
	ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(Revenue, 0) AS Revenue, 
	ISNULL(Partner_Fee, 0) AS Partner_Fee, 
	ISNULL(Registration_Fee, 0) AS Registration_Fee, 
	ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
	ISNULL(Opportunity_Extrap, 0) AS Opportunity_Extrap, 
	ISNULL(b.Baseline, 0) AS Baseline,
	ISNULL(b.[Target], 0) AS [Target],
	ISNULL(b.Opportunity_Into_RR,0) AS Opportunity_Into_RR
FROM

	(---This is Revenue + Opportunities table 
	SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
	ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(Revenue, 0) AS Revenue, 
	ISNULL(Partner_Fee, 0) AS Partner_Fee, 
	ISNULL(Registration_Fee, 0) AS Registration_Fee, 
	ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
	ISNULL(Opportunity_Extrap, 0) AS Opportunity_Extrap
	FROM
		(----Revenue Dataset
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
		FROM (
			SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
			SUM(Revenue) AS Revenue,
			SUM(Partner_Fee) AS Partner_Fee,
			SUM(Registration_Fee) AS Registration_Fee 
			FROM
				(
				SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
				CASE
					WHEN Product_Category LIKE '%Service%' THEN 'Services'
					WHEN Product_Category LIKE '%Support%' THEN 'Support'
					WHEN Product_Category LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category_2,
				IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
				IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
				IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
				FROM Revenue_Wk25
				) a
			GROUP BY Account_No,Fiscal_Month, Product_Category_2
			)a
			LEFT JOIN 
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
			ON a.Fiscal_Month = b.Fiscal_Month
		) a

		FULL JOIN

		(---- Opportunities Dataset 
		SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
		FROM
			(
			SELECT DISTINCT a.Account_No, a.Product_Category, a.Fiscal_Month,
			SUM(Opportunity_Usage) AS Opportunity_Usage,
			CASE
				WHEN Fiscal_Month LIKE '%July%' THEN 11
				WHEN Fiscal_Month LIKE '%August%' THEN 10
				WHEN Fiscal_Month LIKE '%September%' THEN 9
				WHEN Fiscal_Month LIKE '%October%' THEN 8
				WHEN Fiscal_Month LIKE '%November%' THEN 7
				WHEN Fiscal_Month LIKE '%December%' THEN 6
				WHEN Fiscal_Month LIKE '%January%' THEN 5
				WHEN Fiscal_Month LIKE '%February%' THEN 4
				WHEN Fiscal_Month LIKE '%March%' THEN 3
				WHEN Fiscal_Month LIKE '%April%' THEN 2
				WHEN Fiscal_Month LIKE '%May%' THEN 1
				WHEN Fiscal_Month LIKE '%June%' THEN 0
				END AS Extrap_Months_Left_For_FY

			FROM

				(
				SELECT a.Account_No, a.Product_Category, b.Fiscal_Month,
				SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
				FROM

					(
					SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
					CASE
						WHEN Product LIKE '%Service%' THEN 'Services'
						WHEN Product LIKE '%Support%' THEN 'Support'
						WHEN Product LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
					Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
					WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
					) a

					LEFT JOIN
					(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
					ON a.Opportunity_Est_Date = b.Date_Value
				GROUP BY Account_No, Product_Category,b.Fiscal_Month
				) a
			GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month
			)a
		)b
		ON a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	)a ---4,22,123 rows

	FULL JOIN 

	(---- Baseline into Targets + Milestone into RR Tables 
	SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
	ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(a.Baseline, 0) AS Baseline,
	ISNULL(a.[Target], 0) AS [Target],
	ISNULL(Opportunity_Into_RR,0) AS Opportunity_Into_RR
	FROM


		(----This is Baseline + Targets
		SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
		ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL(Baseline, 0) AS Baseline,
		ISNULL([Target], 0) AS [Target]
		FROM
			(---This is Baseline
			SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
			FROM
				(
				SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
				FROM (
						SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
						SUM(Revenue) AS Revenue,
						SUM(Partner_Fee) AS Partner_Fee,
						SUM(Registration_Fee) AS Registration_Fee 
						FROM
							(
							SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
							CASE
								WHEN Product_Category LIKE '%Service%' THEN 'Services'
								WHEN Product_Category LIKE '%Support%' THEN 'Support'
								WHEN Product_Category LIKE '%Product%' THEN 'Products'
								ELSE 'Need Mapping'
								END AS Product_Category_2,
							IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
							IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
							IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
							FROM Revenue_Wk25
							) a
						GROUP BY Account_No,Fiscal_Month, Product_Category_2
						)a
						LEFT JOIN 
						(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
						ON a.Fiscal_Month = b.Fiscal_Month

						WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup 
						WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
				)a

				CROSS JOIN

				(
				SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
				(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
				(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
				)b
			)a

			FULL JOIN

			(---This is Targets
			SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target] 
			FROM 
				(SELECT Store_Number AS Account_No, Service_Comp_Group AS Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a ----16,014

				LEFT JOIN 
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
				ON a.Fiscal_Month = b.Date_Value
			)b
			ON 
			a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
		)a

		FULL JOIN 
		(---This is opportunities into RR 
		SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, 
		IIF(Opportunity_Usage < 0, 0, Opportunity_Usage)  AS Opportunity_Into_RR
		FROM
			(SELECT a.*, b.Fiscal_Month AS Future_fiscal_Months, b.Month_ID AS Est_Month_ID
			FROM
				(
				SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
					FROM
						(
						SELECT a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID,
						SUM(a.Opportunity_Usage) AS Opportunity_Usage,

						CASE
							WHEN Fiscal_Month LIKE '%July%' THEN 11
							WHEN Fiscal_Month LIKE '%August%' THEN 10
							WHEN Fiscal_Month LIKE '%September%' THEN 9
							WHEN Fiscal_Month LIKE '%October%' THEN 8
							WHEN Fiscal_Month LIKE '%November%' THEN 7
							WHEN Fiscal_Month LIKE '%December%' THEN 6
							WHEN Fiscal_Month LIKE '%January%' THEN 5
							WHEN Fiscal_Month LIKE '%February%' THEN 4
							WHEN Fiscal_Month LIKE '%March%' THEN 3
							WHEN Fiscal_Month LIKE '%April%' THEN 2
							WHEN Fiscal_Month LIKE '%May%' THEN 1
							WHEN Fiscal_Month LIKE '%June%' THEN 0
							END AS Extrap_Months_Left_For_FY

						FROM

							(
							SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, b.Month_ID, 
							SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
							FROM

								(
								SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
								CASE
									WHEN Product LIKE '%Service%' THEN 'Services'
									WHEN Product LIKE '%Support%' THEN 'Support'
									WHEN Product LIKE '%Product%' THEN 'Products'
									ELSE 'Need Mapping'
									END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
								Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
								WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
								) a

								LEFT JOIN
								(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
								ON a.Opportunity_Est_Date = b.Date_Value
							WHERE ----WHERE IN Option 1 ('','','','')
							a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND 
							b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
							GROUP BY Account_No, Product_Category,b.Fiscal_Month,b.Month_ID
							) a
						GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID
					)a
				)a 
	
				CROSS JOIN 

				(
				SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
				(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
				(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) 
				)b
			---9,605 rows
			WHERE a.Month_ID <= b.Month_ID
				)a
			---5,814 rows

				LEFT JOIN 
				(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup)b 
				ON a.Est_Month_ID = b.Month_ID
			)b
	ON a.Account_No = b.Account_No AND a.Product_Category = b.Product_Category AND a.Fiscal_Month = b.Fiscal_Month
	)b
ON a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
----6,12,109 rows


-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------Joining Transactional with Lookup Tables------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

CREATE VIEW ipi_data_Revenue_Summary AS 

SELECT final.*, 
b.Fiscal_Quarter, b.Fiscal_Year, b.Month_ID,
c.Account_Name, c.Industry, c.Vertical, c.Segment, c.Store_Manager_Alias, c.Potential_Account, c.Vertical_Manager_Alias,
d.General_Seller, d.Services_Seller, d.Product_Seller
FROM

	(-----This is all the transactional Data
	SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
		ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL(Revenue, 0) AS Revenue, 
		ISNULL(Partner_Fee, 0) AS Partner_Fee, 
		ISNULL(Registration_Fee, 0) AS Registration_Fee, 
		ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
		ISNULL(Opportunity_Extrap, 0) AS Opportunity_Extrap, 
		ISNULL(b.Baseline, 0) AS Baseline,
		ISNULL(b.[Target], 0) AS [Target],
		ISNULL(b.Opportunity_Into_RR,0) AS Opportunity_Into_RR
	FROM

		(---This is Revenue + Opportunities table 
		SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
		ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL(Revenue, 0) AS Revenue, 
		ISNULL(Partner_Fee, 0) AS Partner_Fee, 
		ISNULL(Registration_Fee, 0) AS Registration_Fee, 
		ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
		ISNULL(Opportunity_Extrap, 0) AS Opportunity_Extrap
		FROM
			(----Revenue Dataset
			SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
			FROM (
				SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
				SUM(Revenue) AS Revenue,
				SUM(Partner_Fee) AS Partner_Fee,
				SUM(Registration_Fee) AS Registration_Fee 
				FROM
					(
					SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
					CASE
						WHEN Product_Category LIKE '%Service%' THEN 'Services'
						WHEN Product_Category LIKE '%Support%' THEN 'Support'
						WHEN Product_Category LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category_2,
					IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
					IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
					IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
					FROM Revenue_Wk25
					) a
				GROUP BY Account_No,Fiscal_Month, Product_Category_2
				)a
				LEFT JOIN 
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
				ON a.Fiscal_Month = b.Fiscal_Month
			) a

			FULL JOIN

			(---- Opportunities Dataset 
			SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
			FROM
				(
				SELECT DISTINCT a.Account_No, a.Product_Category, a.Fiscal_Month,
				SUM(Opportunity_Usage) AS Opportunity_Usage,
				CASE
					WHEN Fiscal_Month LIKE '%July%' THEN 11
					WHEN Fiscal_Month LIKE '%August%' THEN 10
					WHEN Fiscal_Month LIKE '%September%' THEN 9
					WHEN Fiscal_Month LIKE '%October%' THEN 8
					WHEN Fiscal_Month LIKE '%November%' THEN 7
					WHEN Fiscal_Month LIKE '%December%' THEN 6
					WHEN Fiscal_Month LIKE '%January%' THEN 5
					WHEN Fiscal_Month LIKE '%February%' THEN 4
					WHEN Fiscal_Month LIKE '%March%' THEN 3
					WHEN Fiscal_Month LIKE '%April%' THEN 2
					WHEN Fiscal_Month LIKE '%May%' THEN 1
					WHEN Fiscal_Month LIKE '%June%' THEN 0
					END AS Extrap_Months_Left_For_FY

				FROM

					(
					SELECT a.Account_No, a.Product_Category, b.Fiscal_Month,
					SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
					FROM

						(
						SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
						CASE
							WHEN Product LIKE '%Service%' THEN 'Services'
							WHEN Product LIKE '%Support%' THEN 'Support'
							WHEN Product LIKE '%Product%' THEN 'Products'
							ELSE 'Need Mapping'
							END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
						Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
						WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
						) a

						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
						ON a.Opportunity_Est_Date = b.Date_Value
					GROUP BY Account_No, Product_Category,b.Fiscal_Month
					) a
				GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month
				)a
			)b
			ON a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
		)a ---4,22,123 rows

		FULL JOIN 

		(---- Baseline into Targets + Milestone into RR Tables 
		SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
		ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL(a.Baseline, 0) AS Baseline,
		ISNULL(a.[Target], 0) AS [Target],
		ISNULL(Opportunity_Into_RR,0) AS Opportunity_Into_RR
		FROM


			(----This is Baseline + Targets
			SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
			ISNULL(a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
			ISNULL(a.Product_Category, b.Product_Category) AS Product_Category,
			ISNULL(Baseline, 0) AS Baseline,
			ISNULL([Target], 0) AS [Target]
			FROM
				(---This is Baseline
				SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
				FROM
					(
					SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
					FROM (
							SELECT Account_No,Fiscal_Month, Product_Category_2 AS Product_Category, 
							SUM(Revenue) AS Revenue,
							SUM(Partner_Fee) AS Partner_Fee,
							SUM(Registration_Fee) AS Registration_Fee 
							FROM
								(
								SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, 
								CASE
									WHEN Product_Category LIKE '%Service%' THEN 'Services'
									WHEN Product_Category LIKE '%Support%' THEN 'Support'
									WHEN Product_Category LIKE '%Product%' THEN 'Products'
									ELSE 'Need Mapping'
									END AS Product_Category_2,
								IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue,
								IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
								IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
								FROM Revenue_Wk25
								) a
							GROUP BY Account_No,Fiscal_Month, Product_Category_2
							)a
							LEFT JOIN 
							(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
							ON a.Fiscal_Month = b.Fiscal_Month

							WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup 
							WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
					)a

					CROSS JOIN

					(
					SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
					(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
					(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
					)b
				)a

				FULL JOIN

				(---This is Targets
				SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target] 
				FROM 
					(SELECT Store_Number AS Account_No, Service_Comp_Group AS Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a ----16,014

					LEFT JOIN 
					(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup)b
					ON a.Fiscal_Month = b.Date_Value
				)b
				ON 
				a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
			)a

			FULL JOIN 
			(---This is opportunities into RR 
			SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, 
			IIF(Opportunity_Usage < 0, 0, Opportunity_Usage)  AS Opportunity_Into_RR
			FROM
				(SELECT a.*, b.Fiscal_Month AS Future_fiscal_Months, b.Month_ID AS Est_Month_ID
				FROM
					(
					SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
						FROM
							(
							SELECT a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID,
							SUM(a.Opportunity_Usage) AS Opportunity_Usage,

							CASE
								WHEN Fiscal_Month LIKE '%July%' THEN 11
								WHEN Fiscal_Month LIKE '%August%' THEN 10
								WHEN Fiscal_Month LIKE '%September%' THEN 9
								WHEN Fiscal_Month LIKE '%October%' THEN 8
								WHEN Fiscal_Month LIKE '%November%' THEN 7
								WHEN Fiscal_Month LIKE '%December%' THEN 6
								WHEN Fiscal_Month LIKE '%January%' THEN 5
								WHEN Fiscal_Month LIKE '%February%' THEN 4
								WHEN Fiscal_Month LIKE '%March%' THEN 3
								WHEN Fiscal_Month LIKE '%April%' THEN 2
								WHEN Fiscal_Month LIKE '%May%' THEN 1
								WHEN Fiscal_Month LIKE '%June%' THEN 0
								END AS Extrap_Months_Left_For_FY

							FROM

								(
								SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, b.Month_ID, 
								SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
								FROM

									(
									SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
									CASE
										WHEN Product LIKE '%Service%' THEN 'Services'
										WHEN Product LIKE '%Support%' THEN 'Support'
										WHEN Product LIKE '%Product%' THEN 'Products'
										ELSE 'Need Mapping'
										END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
									Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
									WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 AND Project_Status <> 'Inactive'
									) a

									LEFT JOIN
									(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
									ON a.Opportunity_Est_Date = b.Date_Value
								WHERE ----WHERE IN Option 1 ('','','','')
								a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND 
								b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
								GROUP BY Account_No, Product_Category,b.Fiscal_Month,b.Month_ID
								) a
							GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month, a.Month_ID
						)a
					)a 
	
					CROSS JOIN 

					(
					SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
					(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
					(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) 
					)b
				---9,605 rows
				WHERE a.Month_ID <= b.Month_ID
					)a
				---5,814 rows

					LEFT JOIN 
					(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup)b 
					ON a.Est_Month_ID = b.Month_ID
				)b
		ON a.Account_No = b.Account_No AND a.Product_Category = b.Product_Category AND a.Fiscal_Month = b.Fiscal_Month
		)b
	ON a.Account_No = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	)final

	LEFT JOIN 
	(----This is the calendar_lookup
	SELECT DISTINCT Fiscal_Month,Fiscal_Quarter, Fiscal_Year, Month_ID 
	FROM Calendar_Lookup
	)b
	ON final.Fiscal_Month = b.Fiscal_Month

	LEFT JOIN 
	(----This is the Store_lookup 
	SELECT AccountNo, Store AS Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias 
	FROM Store_Lookup
	)c
	ON final.Account_No = c.AccountNo

	LEFT JOIN 
	(----This is the Sellers_Lookup 
	SELECT Store_ID, General_Seller, Services_Seller, Product_Seller
	FROM Sellers_Lookup
	)d
	ON final.Account_No = d.Store_ID
-----6,12,109 rows
--SELECT * FROM Store_Lookup
--SELECT TOP 10 * FROM Sellers_Lookup
--SELECT TOP 10 * FROM Calendar_Lookup

SELECT * FROM ipi_data_Revenue_Summary

-----------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------CREATING OPPORTUNITIES VIEWS------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
---OBJECTIVE 2------
---We want to see all opportunities in one view

CREATE VIEW ipi_data_Opportunity_Summary AS 

SELECT a.*, 
CASE 
	WHEN Opportunity_Usage < 0 THEN 'Below < $0'
	WHEN Opportunity_Usage BETWEEN 0 AND 10000 THEN '$0 to $10,000'
	WHEN Opportunity_Usage BETWEEN 10000 AND 50000 THEN '$10,000 to $50,000'
	WHEN Opportunity_Usage BETWEEN 50000 AND 100000 THEN '$50,000 to $100,000'
	WHEN Opportunity_Usage BETWEEN 100000 AND 200000 THEN '$100,000 to $200,000'
	ELSE '200,000 +'
	END AS Opportunity_Usage_Range,
CASE 
	WHEN Opportunity_Extrap < 0 THEN 'Below < $0'
	WHEN Opportunity_Extrap BETWEEN 0 AND 10000 THEN '$0 to $10,000'
	WHEN Opportunity_Extrap BETWEEN 10000 AND 50000 THEN '$10,000 to $50,000'
	WHEN Opportunity_Extrap BETWEEN 50000 AND 100000 THEN '$50,000 to $100,000'
	WHEN Opportunity_Extrap BETWEEN 100000 AND 200000 THEN '$100,000 to $200,000'
	ELSE '200,000 +'
	END AS Opportunity_Extrap_Range,
Fiscal_Quarter, Fiscal_Year, Month_ID,
Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias,
General_Seller, Services_Seller, Product_Seller
FROM

	(---- Opportunities Dataset 
		SELECT a.*, IIF(Opportunity_Usage < 0, 0, Extrap_Months_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrap
		FROM
			(
			SELECT DISTINCT a.Account_No, a.Product_Category, a.Fiscal_Month, Product, Opportunity_Status, Opportunity_Stage, 
			SUM(Opportunity_Usage) AS Opportunity_Usage,
			CASE
				WHEN Fiscal_Month LIKE '%July%' THEN 12
				WHEN Fiscal_Month LIKE '%August%' THEN 11
				WHEN Fiscal_Month LIKE '%September%' THEN 10
				WHEN Fiscal_Month LIKE '%October%' THEN 9
				WHEN Fiscal_Month LIKE '%November%' THEN 8
				WHEN Fiscal_Month LIKE '%December%' THEN 7
				WHEN Fiscal_Month LIKE '%January%' THEN 6
				WHEN Fiscal_Month LIKE '%February%' THEN 5
				WHEN Fiscal_Month LIKE '%March%' THEN 4
				WHEN Fiscal_Month LIKE '%April%' THEN 3
				WHEN Fiscal_Month LIKE '%May%' THEN 2
				WHEN Fiscal_Month LIKE '%June%' THEN 1
				END AS Extrap_Months_Left_For_FY

			FROM

				(
				SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, Product, Opportunity_Status, Opportunity_Stage,
				SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS float)) AS Opportunity_Usage
				FROM

					(
					SELECT Store_No AS Account_No, Opportunity_Est_Date, Product,
					CASE
						WHEN Product LIKE '%Service%' THEN 'Services'
						WHEN Product LIKE '%Support%' THEN 'Support'
						WHEN Product LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category, Opportunity_ID, Opportunity_Name, Project_Status,
					Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
					WHERE Product IS NOT NULL AND Product <> 'Null'  AND Opportunity_Usage <> 0 
					) a

					LEFT JOIN
					(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
					ON a.Opportunity_Est_Date = b.Date_Value
				GROUP BY Account_No, Product_Category,b.Fiscal_Month, Product, Opportunity_Status, Opportunity_Stage
				) a
			GROUP BY a.Account_No, a.Product_Category, a.Fiscal_Month, Product, Opportunity_Status, Opportunity_Stage
			)a ----12,063 rows
		)a

	LEFT JOIN 
	(----This is the calendar_lookup
	SELECT DISTINCT Fiscal_Month,Fiscal_Quarter, Fiscal_Year, Month_ID 
	FROM Calendar_Lookup
	)b
	ON a.Fiscal_Month = b.Fiscal_Month

	LEFT JOIN 
	(----This is the Store_lookup 
	SELECT AccountNo, Store AS Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias 
	FROM Store_Lookup
	)c
	ON a.Account_No = c.AccountNo

	LEFT JOIN 
	(----This is the Sellers_Lookup 
	SELECT Store_ID, General_Seller, Services_Seller, Product_Seller
	FROM Sellers_Lookup
	)d
	ON a.Account_No = d.Store_ID

SELECT * FROM ipi_data_Opportunity_Summary
----12,063 rows
