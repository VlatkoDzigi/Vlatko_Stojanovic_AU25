-- Safely create table with 10M rows
DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeeery_long_string' || x AS col
FROM generate_series(1, power(10,7)::int) AS x;  

-- Quick sanity check
SELECT COUNT(*) AS rows_before 
FROM public.table_to_delete;

-- Size snapshot (before)
SELECT
  pg_size_pretty(pg_table_size('public.table_to_delete'))        AS table_bytes,
  pg_size_pretty(pg_indexes_size('public.table_to_delete'))      AS index_bytes,
  pg_size_pretty(pg_total_relation_size('public.table_to_delete')) AS total_bytes;

-- DELETE 1/3 rows 
DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeeery_long_string','')::int % 3 = 0;

-- Check how many rows are left:
SELECT COUNT(*) AS rows_after_delete
FROM public.table_to_delete;

-- Measure the size immediately after DELETE:
SELECT
  pg_size_pretty(pg_table_size('public.table_to_delete'))         AS table_bytes_after_delete,
  pg_size_pretty(pg_total_relation_size('public.table_to_delete')) AS total_bytes_after_delete;

-- Run VACUUM FULL to reclaim space:
VACUUM FULL VERBOSE public.table_to_delete;

-- Measure again after VACUUM FULL:
SELECT
  pg_size_pretty(pg_table_size('public.table_to_delete'))         AS table_bytes_after_vacuum_full,
  pg_size_pretty(pg_total_relation_size('public.table_to_delete')) AS total_bytes_after_vacuum_full;

-- Recreate base table with 10M rows for TRUNCATE test
DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeeery_long_string' || x AS col
FROM generate_series(1, (power(10,7))::int) AS x;

-- Quick sanity check
SELECT COUNT(*) AS rows_before 
FROM public.table_to_delete;

-- Checking memory size:
SELECT
  pg_size_pretty(pg_table_size('public.table_to_delete'))          AS table_bytes_before_truncate,
  pg_size_pretty(pg_total_relation_size('public.table_to_delete'))  AS total_bytes_before_truncate;

-- Run TRUNCATE
TRUNCATE public.table_to_delete;

-- Chek after TRUNCATE
SELECT
  pg_size_pretty(pg_table_size('public.table_to_delete'))          AS table_bytes_after_truncate,
  pg_size_pretty(pg_total_relation_size('public.table_to_delete'))  AS total_bytes_after_truncate;

/*
1) Space consumption (before/after)
    - Before DELETE: 575 MB
    - After DELETE (no VACUUM): 575 MB
    - After VACUUM FULL: 383 MB
    - Before TRUNCATE (recreated base table): 575 MB
    - After TRUNCATE: 8 KB


2) Durations (measured)
    - Creating base table: 20.349 s
    - DELETE 1/3 of rows: 18.336 s
    - VACUUM FULL VERBOSE: 8.773 s
    - Recreate base table: 25.544 s
    - TRUNCATE public.table_to_delete: 0.102 s

3) Conclusions
    - DELETE removed rows logically, but the physical space on disk remained the same (575 MB). PostgreSQL keeps deleted tuples until a VACUUM FULL operation is executed.

    - VACUUM FULL compacted the table and released unused space, reducing it to 383 MB (about one-third smaller, matching the deleted portion).

    - TRUNCATE was almost instantaneous (0.102 s) and released the entire space at once, shrinking the table to just 8 KB. 
      It is therefore the fastest and most efficient method for completely clearing a table but cannot be filtered with a WHERE clause.
*/ 