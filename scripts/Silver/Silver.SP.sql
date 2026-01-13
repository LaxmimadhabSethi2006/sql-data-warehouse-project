/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/;


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
   Declare @start_time DATETIME,@end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
  BEGIN TRY
SET @batch_start_time=GETDATE();
PRINT'===============================================';
PRINT'Loading Silver Layer';
PRINT'===============================================';

PRINT'----------------------------------';
PRINT'Loading CRM Tables';
PRINT'----------------------------------';
SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;

PRINT'>>Inserting Data Into: silver.crm_cust_info';
INSERT INTO  silver.crm_cust_info(
cst_id,
cst_key,
cst_firstname,
cst_lastname,
cst_martial_status,
cst_gender ,
cst_create_date
)
select
cst_id,
cst_key,
trim(cst_firstname),
trim(cst_lastname),
case 
when upper(Trim(cst_martial_status ))='M' then 'Married'
when upper(Trim(cst_martial_status))='S' then 'Single'
else 'n/a'
end as cst_martial_status,
case 
when upper(Trim(cst_gender ))='M' then 'Male'
when upper(Trim(cst_gender )) ='F' then 'Female'
else 'n/a'
end as cst_gender,
cst_create_date
from
(
select
*,
ROW_NUMBER() over (Partition by cst_id order by cst_create_date desc) as latest_date
from bronze.crm_cust_info
where cst_id is not null
)t
where  latest_date = 1

SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.crm_prd_info';
TRUNCATE TABLE silver.crm_prd_info;

PRINT'>>Inserting Data Into: silver.crm_prd_info';
INSERT INTO silver.crm_prd_info(
prd_id,
cat_id,
prd_key,
prd_nm,
prd_cost,
prd_line,
prd_start_dt,
prd_end_dt
)
select
prd_id,
replace(substring(prd_key,1,5),'-' ,'_' )as cat_id,
substring(prd_key,7,len(prd_key)) as prd_key,
prd_nm,
coalesce(prd_cost,0) as prd_cost,
case
when upper(trim(prd_line))='M' then 'Mountain'
when upper(trim(prd_line))='R' then 'Road'
when upper(trim(prd_line))='S' then 'other Sales'
when upper(trim(prd_line))='T' then 'Touring'
else 'n/a'
end as prd_line,
cast(prd_start_dt as date) as prd_start_dt,
cast(lead(prd_start_dt) over (partition by prd_key order by prd_start_dt)-1 as date) as prd_end_dt 
from bronze.crm_prd_info

SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.crm_sales_details';
TRUNCATE TABLE silver.crm_sales_details;

PRINT'>>Inserting Data Into:silver.crm_sales_details';
INSERT INTO silver.crm_sales_details (
sales_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price 
)
select
sales_ord_num,
sls_prd_key,
sls_cust_id,
case 
when sls_order_dt<=0 or len(sls_order_dt)!=8 then null
else  cast(cast(sls_order_dt as varchar) as date)
end as sls_order_dt,
case 
when sls_ship_dt<=0 or len(sls_ship_dt)!=8 then null
else cast(cast(sls_ship_dt as varchar) as date)
end as sls_ship_dt,
case 
when sls_due_dt<=0 or len(sls_due_dt)!=8 then null
else cast(cast(sls_due_dt as varchar) as date)
end as sls_due_dt,
case 
when sls_sales is null or sls_sales<=0 or sls_quantity!= sls_quantity *abs(sls_price) then sls_quantity *abs(sls_price)
else sls_sales
end as sls_sales,
sls_quantity,
case 
when sls_price is null or sls_price<=0 then sls_sales /nullif(sls_quantity,0)
else sls_price
end as sls_price
from bronze.crm_sales_details

SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

PRINT'----------------------------------';
PRINT'Loading ERP Tables';
PRINT'----------------------------------';

SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.erp_loc_a101';
TRUNCATE TABLE silver.erp_loc_a101;

PRINT'>>Inserting Data Into:silver.erp_loc_a101';
INSERT INTO silver.erp_loc_a101(
cid,
cntry
)
select 
replace(cid,'-','') cid,
case
when trim(cntry)='DE' then 'Germany'
when trim(cntry) in ('US','USA') then 'United States'
when trim(cntry)='' OR cntry is null then 'n/a'
else trim(cntry)
end as cntry
from bronze.erp_loc_a101


SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.erp_cust_az12';
TRUNCATE TABLE silver.erp_cust_az12;

PRINT'>>Inserting Data Into:silver.erp_cust_az12';
INSERT INTO silver.erp_cust_az12(
cid,
bdate,
gen
)
select
case 
when cid like 'NAS%' then substring(cid,4,len(cid))
else cid
end as cid,
case
when bdate>getdate() then null
else bdate
end as bdate,
case
when upper(trim(gen)) in ('F','Female') then 'Female'
when upper(trim(gen)) in ('M','Male') then 'Male'
else 'n/a'
end as gen
from bronze.erp_cust_az12

SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

SET @start_time=GETDATE();
PRINT '>>Truncating Table:silver.erp_px_cat_g1v2';
TRUNCATE TABLE silver.erp_px_cat_g1v2;

PRINT'>>Inserting Data Into:silver.erp_px_cat_g1v2';
INSERT INTO silver.erp_px_cat_g1v2(
id,
cat,
subcat,
maintenance
)
select
id,
cat,
subcat,
maintenance
from bronze.erp_px_cat_g1v2

SET @end_time=GETDATE();
PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
PRINT '>> -------------';

   SET @batch_end_time=GETDATE();

		PRINT '=========================================='
		PRINT 'Loading silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
  END TRY
  BEGIN CATCH
     PRINT'===================================================='
     PRINT'Error occured during loading bronze layer'
     PRINT'Error Message'+ Error_Message();
     PRINT'Error Message'+ cast (Error_Number() as NVARCHAR);
     PRINT'Error Message'+ cast(Error_state() as NVARCHAR);
     PRINT'====================================================='
  END CATCH
END