DROP TABLE IF EXISTS `yourproject.yourdataset.account_owner`
;

CREATE TABLE	`yourproject.yourdataset.account_owner`
(
 account_id	INT64
,customer_id	INT64
,customer_name	STRING
,start_date	DATE
,end_date	DATE	
)
;

INSERT INTO  yourdataset.account_owner select 1,2,'Jane BobSon',DATE('2020-07-02'),DATE('2020-08-31');
INSERT INTO  yourdataset.account_owner select 1,2,'Jane McPoppyPop',DATE('2020-09-01'),DATE('9999-12-31');

DROP TABLE IF EXISTS `yourproject.yourdataset.account_type`
;

CREATE TABLE	`yourproject.yourdataset.account_type`
(
 account_id	INT64
,account_type	STRING
,start_date	DATE
,end_date	DATE	
)
;

INSERT INTO  yourdataset.account_type select 1,'Awesome',DATE('2020-05-02'),DATE('2020-06-30');
INSERT INTO  yourdataset.account_type select 1,'Basic as',DATE('2020-07-01'),DATE('2020-08-01');
INSERT INTO  yourdataset.account_type select 1,'Alright I suppose',DATE('2020-08-02'),DATE('2020-08-31');
INSERT INTO  yourdataset.account_type select 1,'Awesome',DATE('2020-09-01'),DATE('9999-12-31');


SELECT * FROM 
yourdataset.account_owner
ORDER BY START_DATE ASC
;

SELECT * FROM 
yourdataset.account_type
ORDER BY START_DATE ASC
;

-- no we miss lots of changes
SELECT * FROM 
yourdataset.account_owner T1
LEFT JOIN
yourdataset.account_type T2
ON T1.account_id = T2.account_id
AND t1.start_date between t2.start_date and t2.end_date
;

-- we've still missed something
SELECT * FROM 
yourdataset.account_owner T1
LEFT JOIN
yourdataset.account_type T2
ON T1.account_id = T2.account_id
AND 
(t1.start_date between t2.start_date and t2.end_date
OR t1.end_date between t2.start_date and t2.end_date
)
;


-- Change to full join and we have all our records
-- but getting this to where we want to be is still annoying, this is not enough records to generate the output we need
-- for example on the second row, the owner type is unknown on the 1st of July, we should have a record to highlight this
-- while we could run a series of steps and conditional logic to sort this out, if we were trying to merge 100 tables, it would become completly unmanagable to join them directly and capture all state
-- there is another way though
SELECT * FROM 
yourdataset.account_owner T1
FULL JOIN
yourdataset.account_type T2
ON T1.account_id = T2.account_id
AND 
(t1.start_date between t2.start_date and t2.end_date
OR t1.end_date between t2.start_date and t2.end_date
)
order by t2.start_date asc, t1.start_date asc
;



--Rather than join the tables together directly, we do a little work to make our lives MUCH easier

DROP TABLE IF EXISTS  yourdataset.account_change_dates
;

CREATE TABLE yourdataset.account_change_dates
(
 account_id INT64
,change_date DATE
)
;


--- OUR INPUT DATA IS CONTIGUOUS, THERE ARE NO GAPS IN TIME, AS SUCH WE ONLY NEED START DATES FROM SOURCE
--- A LATER EXAMPLE WILL EXPAND ON THIS
INSERT INTO yourdataset.account_change_dates
select * from
(
SELECT
 account_id	
,start_date
FROM
yourdataset.account_owner
UNION ALL
SELECT
 account_id	
,start_date
FROM
yourdataset.account_type
)
group by 1,2
;



--- closer to what we needed
select * from
yourdataset.account_change_dates t1
left join
yourdataset.account_owner t2
on t1.account_id = t2.account_id
and t1.change_date between t2.start_date and t2.end_date
left join
yourdataset.account_type t3
on t1.account_id = t3.account_id
and t1.change_date between t3.start_date and t3.end_date
order by change_date asc
;



select 
 t1.account_id
,t1.change_date
,COALESCE(
-- we will set our records to end 1 day before the next record starts, if there is no next record, we will use the high valued end date, in this case 9999-12-31 but your org may use something else
 max(DATE_SUB(change_date, interval 1 day)) over (partition by t1.account_id order by t1.change_date asc rows between 1 following and 1 following)
 ,DATE('9999-12-31')
 ) as calculated_end_date
,t2.customer_id
,t2.customer_name
,t2.start_date	
,t2.end_date
,t3.account_type	
,t3.start_date
,t3.end_date
from
yourdataset.account_change_dates t1
left join
yourdataset.account_owner t2
on t1.account_id = t2.account_id
and t1.change_date between t2.start_date and t2.end_date
left join
yourdataset.account_type t3
on t1.account_id = t3.account_id
and t1.change_date between t3.start_date and t3.end_date
order by change_date asc
;


--- If we have source data with gaps in time, we can use nearly the same method but a little extra work is needed

--- let's refresh our example data

DROP TABLE IF EXISTS `yourproject.yourdataset.account_owner`
;

CREATE TABLE	`yourproject.yourdataset.account_owner`
(
 account_id	INT64
,customer_id	INT64
,customer_name	STRING
,start_date	DATE
,end_date	DATE	
)
;

INSERT INTO  yourdataset.account_owner select 1,2,'Jane BobSon',DATE('2020-07-02'),DATE('2020-08-15'); -- this row now ends before the next starts
INSERT INTO  yourdataset.account_owner select 1,2,'Jane McPoppyPop',DATE('2020-09-01'),DATE('9999-12-31');



DROP TABLE IF EXISTS `yourproject.yourdataset.account_type`
;

CREATE TABLE	`yourproject.yourdataset.account_type`
(
 account_id	INT64
,account_type	STRING
,start_date	DATE
,end_date	DATE	
)
;

INSERT INTO  yourdataset.account_type select 1,'Awesome',DATE('2020-05-02'),DATE('2020-06-30');
INSERT INTO  yourdataset.account_type select 1,'Basic as',DATE('2020-07-01'),DATE('2020-07-20'); -- this row now ends before the next starts
INSERT INTO  yourdataset.account_type select 1,'Alright I suppose',DATE('2020-08-02'),DATE('2020-08-25'); -- this row now ends before the next starts
INSERT INTO  yourdataset.account_type select 1,'Awesome',DATE('2020-09-01'),DATE('9999-12-31');



SELECT * FROM 
yourdataset.account_owner
ORDER BY START_DATE ASC
;

SELECT * FROM 
yourdataset.account_type
ORDER BY START_DATE ASC
;


--- now we have gaps, what would the full join look like
--- the second and third records would need to be split into parts
SELECT * FROM 
yourdataset.account_owner T1
FULL JOIN
yourdataset.account_type T2
ON T1.account_id = T2.account_id
AND 
(t1.start_date between t2.start_date and t2.end_date
OR t1.end_date between t2.start_date and t2.end_date
)
order by t2.start_date asc, t1.start_date asc
;






DROP TABLE IF EXISTS  yourdataset.account_change_dates
;

CREATE TABLE yourdataset.account_change_dates
(
 account_id INT64
,change_date DATE
)
;

--- collate, this time because we have gaps, we need to also capture the end date of records as we need to correct identify when a source has no data available
INSERT INTO yourdataset.account_change_dates
select * from
(
SELECT
 account_id	
,start_date
FROM
yourdataset.account_owner
UNION ALL
SELECT
 account_id	
,end_date
FROM
yourdataset.account_owner
where end_date <> '9999-12-31'
UNION ALL
SELECT
 account_id	
,start_date
FROM
yourdataset.account_type
UNION ALL
SELECT
 account_id	
,end_date
FROM
yourdataset.account_type
where end_date <> '9999-12-31'
)
group by 1,2
;

--- as expected, we've now got more dates
select * from
yourdataset.account_change_dates
order by change_date asc
;




--- In many cases this may now be good enough to do what we need, but our solution is wasting some space, we're showing the same values occuring sequentially
--- as well as waste space this hinders identifying moments of change from the data we've created, so let's sort that out in the next step
select 
 t1.account_id
,t1.change_date
,COALESCE(
-- we will set our records to end 1 day before the next record starts, if there is no next record, we will use the high valued end date, in this case 9999-12-31 but your org may use something else
 max(DATE_SUB(change_date, interval 1 day)) over (partition by t1.account_id order by t1.change_date asc rows between 1 following and 1 following)
 ,DATE('9999-12-31')
 ) as calculated_end_date
,t2.customer_id
,t2.customer_name
,t2.start_date	
,t2.end_date
,t3.account_type	
,t3.start_date
,t3.end_date
from
yourdataset.account_change_dates t1
left join
yourdataset.account_owner t2
on t1.account_id = t2.account_id
and t1.change_date between t2.start_date and t2.end_date
left join
yourdataset.account_type t3
on t1.account_id = t3.account_id
and t1.change_date between t3.start_date and t3.end_date
order by change_date asc
;


--- WE MIGHT DO THIS SLIGHTLY DIFFERENTLY IF AT ALL CONCERNED WE MAY HAVE PATTERNS IN THE DATA SUCH AS COL 1 = 11, COL 2 = 12 CONFLICTING WITH COL 1 = 1, COL 2 = 112
--- IF THAT WAS A CONCERN, WE COULD COMPARE ALL COLUMNS, OR ADD SOMETHING INTO OUR VALUE STRING BETWEEN EACH COLUMN

WITH T1 AS
(
select 
 t1.account_id
,t1.change_date
/*
,COALESCE(
-- we will set our records to end 1 day before the next record starts, if there is no next record, we will use the high valued end date, in this case 9999-12-31 but your org may use something else
 max(DATE_SUB(change_date, interval 1 day)) over (partition by t1.account_id order by t1.change_date asc rows between 1 following and 1 following)
 ,DATE('9999-12-31')
 ) as calculated_end_date  --- WE WILL NOW DO THIS LATER AFTER REMOVING SUCCESIVE ROWS WITH IDENTICAL VALUES
 */
,t2.customer_id
,t2.customer_name
,t3.account_type	
,CONCAT(COALESCE(CAST(customer_id AS STRING), 'NOT THIS'), COALESCE(customer_name, 'NOT THIS'), COALESCE(account_type, 'NOT THIS')) AS VALUE_STRING
from
yourdataset.account_change_dates t1
left join
yourdataset.account_owner t2
on t1.account_id = t2.account_id
and t1.change_date between t2.start_date and t2.end_date
left join
yourdataset.account_type t3
on t1.account_id = t3.account_id
and t1.change_date between t3.start_date and t3.end_date
)
, T2 AS
(
SELECT 
 *
,MAX(VALUE_STRING) OVER (partition by t1.account_id order by t1.change_date asc rows between 1 preceding and 1 preceding) AS PREV_VALUE_STRING
FROM 
 T1
)
SELECT 
 T2.account_id	
,t2.change_date	AS start_date
,COALESCE(
-- we will set our records to end 1 day before the next record starts, if there is no next record, we will use the high valued end date, in this case 9999-12-31 but your org may use something else
 max(DATE_SUB(t2.change_date, interval 1 day)) over (partition by t2.account_id order by t2.change_date asc rows between 1 following and 1 following)
 ,DATE('9999-12-31')
 ) as calculated_end_date
,t2.customer_id	
,t2.customer_name	
,t2.account_type

FROM 
T2
WHERE VALUE_STRING <> PREV_VALUE_STRING -- we look back instead of forwards, as we will certainly need the first record
OR PREV_VALUE_STRING IS NULL --- KEEP THE FIRST RECORD (WE'VE NO NULL VALUES OTHERWISE DUE TO COALESCE)
order by change_date asc
;

--- Now for this little super simple example this may feel like total overkill, but with minimal change this methodology can be expanded to handle lots of tables at once and any number of horrible clashes on date range between all sources
--- It's a flexible approach to be used when appropriate, i.e we need to keep track of ALL values over time

--- it's worth noting that this is not a magic answer to everything, if you've got issues in you're source data, any sort of corruption in time series then things are going to get messy.
--- I'll write about strategies for sorting our poor source data in another post

