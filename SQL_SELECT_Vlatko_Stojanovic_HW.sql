/*
TASK 1.1
What is asked: 
Animation movies released between 2017 and 2019, with rate > 1, sorted alphabetically.
My understanding / business logic:
 - “rate” = film.rental_rate (numeric).
 - “Animation movies” = films linked to category.name = 'Animation'.
 - Years inclusive: BETWEEN 2017 AND 2019.
 - Alphabetical by title.
*/

-- Plain JOINs
SELECT DISTINCT f.title
FROM public.film AS f
INNER JOIN public.film_category AS fc
  ON fc.film_id = f.film_id
INNER JOIN public.category AS c
  ON c.category_id = fc.category_id
WHERE LOWER(c.name) = 'animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;
-- Pros: simple, readable, uses natural keys (names). Cons: if a film is tagged twice to the same category (rare), DISTINCT guards duplicates.

-- CTE (precompute animation film ids)
WITH animation_film_ids AS (
  SELECT fc.film_id
  FROM public.film_category AS fc
  INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
  WHERE LOWER(c.name) = 'animation'
)
SELECT DISTINCT f.title
FROM public.film AS f
INNER JOIN animation_film_ids AS a
  ON a.film_id = f.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;
-- Pros: separates filtering logic; easy to extend. Cons: slightly longer.

-- Subquery (EXISTS) solution
SELECT DISTINCT f.title
FROM public.film AS f
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
  AND EXISTS (
    SELECT 1
    FROM public.film_category AS fc
    INNER JOIN public.category AS c
      ON c.category_id = fc.category_id
    WHERE fc.film_id = f.film_id
      AND LOWER(c.name) = 'animation'
  )
ORDER BY f.title ASC;
-- Pros: expresses “membership in Animation” clearly. Cons: correlated check per row.


/*
TASK 1.2
What is asked: 
Revenue per store after March 2017 (i.e., from April 1, 2017), show address and address2 as one column + revenue.
My understanding / business logic:
 - Revenue = SUM(payment.amount).
 - Path: payment -> rental -> inventory -> store -> address.
 - Date filter: payment_date >= DATE '2017-04-01'.
 - We combine address lines while handling possible NULL in address2.
 */

-- JOINs + aggregation
SELECT
  CONCAT_WS(' ', a.address, a.address2) AS store_address,
  SUM(p.amount) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
  ON a.address_id = s.address_id
INNER JOIN public.inventory AS i
  ON i.store_id = s.store_id
INNER JOIN public.rental AS r
  ON r.inventory_id = i.inventory_id
INNER JOIN public.payment AS p
  ON p.rental_id = r.rental_id
WHERE p.payment_date >= DATE '2017-04-01'
GROUP BY s.store_id, a.address, a.address2
ORDER BY revenue DESC;
-- Pros: one pass, explicit path, no hard-coded IDs, handles address2 NULL. Cons: joins can multiply rows if data is messy (dvdrental is clean).

-- CTE to prefilter payments
WITH payments_since_apr2017 AS (
  SELECT rental_id, amount
  FROM public.payment
  WHERE payment_date >= DATE '2017-04-01'
)
SELECT
  CONCAT_WS(' ', a.address, a.address2) AS store_address,
  SUM(ps.amount) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
  ON a.address_id = s.address_id
INNER JOIN public.inventory AS i
  ON i.store_id = s.store_id
INNER JOIN public.rental AS r
  ON r.inventory_id = i.inventory_id
INNER JOIN payments_since_apr2017 AS ps
  ON ps.rental_id = r.rental_id
GROUP BY s.store_id, a.address, a.address2
ORDER BY revenue DESC;
-- Pros: narrows early; good if payments table is big. Cons: similar complexity to JOIN.

-- Correlated subquery per store
SELECT
  CONCAT_WS(' ', a.address, a.address2) AS store_address,
  COALESCE((
    SELECT SUM(p.amount)
    FROM public.inventory AS i
    INNER JOIN public.rental AS r
      ON r.inventory_id = i.inventory_id
    INNER JOIN public.payment AS p
      ON p.rental_id = r.rental_id
    WHERE i.store_id = s.store_id
      AND p.payment_date >= DATE '2017-04-01'
  ), 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
  ON a.address_id = s.address_id
ORDER BY revenue DESC;
-- Pros: easy to read per-store logic; returns stores even with zero revenue. Cons: subquery runs per store (fine—few stores).


/*
TASK 1.3
What is asked: 
Top-5 actors by number of movies they acted in, considering films released after 2015. Columns: first_name, last_name, number_of_movies. Sort by number_of_movies desc.
My understanding / business logic:
 - Count distinct film appearances per actor, filtering film.release_year > 2015.
 - Use LIMIT 5 for “top-5”.
 - Add a deterministic tie-break (name) to keep result stable. 
 */

-- JOINs + GROUP BY
SELECT
  a.first_name,
  a.last_name,
  COUNT(DISTINCT fa.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa
  ON fa.actor_id = a.actor_id
INNER JOIN public.film AS f
  ON f.film_id = fa.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC, a.last_name, a.first_name
LIMIT 5;
-- Pros: canonical aggregation; efficient with indexes. Cons: none significant.

-- CTE then limit
WITH actor_counts AS (
  SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    COUNT(DISTINCT fa.film_id) AS number_of_movies
  FROM public.actor AS a
  INNER JOIN public.film_actor AS fa
    ON fa.actor_id = a.actor_id
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
  WHERE f.release_year > 2015
  GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name, last_name, number_of_movies
FROM actor_counts
ORDER BY number_of_movies DESC, last_name, first_name
LIMIT 5;
-- Pros: convenient if we later want top-N per region, etc. Cons: a bit longer.

-- Correlated subquery per actor
SELECT
  a.first_name,
  a.last_name,
  (
    SELECT COUNT(DISTINCT fa.film_id)
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
      ON f.film_id = fa.film_id
    WHERE fa.actor_id = a.actor_id
      AND f.release_year > 2015
  ) AS number_of_movies
FROM public.actor AS a
ORDER BY number_of_movies DESC, a.last_name, a.first_name
LIMIT 5;
-- Pros: clean “count per actor” story. Cons: subquery per actor (acceptable on small table).


/*
TASK 1.4
What is asked: 
For each release_year, show counts of Drama, Travel, Documentary films.
Columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies.
Sort by release_year descending. “Dealing with NULL values is encouraged.”
My understanding / business logic:
 - Count per category using conditional aggregation.
 - If a year has no films in a category, return 0 (use SUM(CASE ...)). 
 */

-- LEFT JOIN + conditional aggregation
SELECT
  f.release_year,
  SUM(CASE WHEN LOWER(c.name) = 'drama'        THEN 1 ELSE 0 END) AS number_of_drama_movies,
  SUM(CASE WHEN LOWER(c.name) = 'travel'       THEN 1 ELSE 0 END) AS number_of_travel_movies,
  SUM(CASE WHEN LOWER(c.name) = 'documentary'  THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM public.film AS f
LEFT JOIN public.film_category AS fc
  ON fc.film_id = f.film_id
LEFT JOIN public.category AS c
  ON c.category_id = fc.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;
-- Pros: one pass; SUM(CASE ...) yields 0 instead of NULL. Cons: none for this part.

-- CTE 
WITH per_cat AS (
    SELECT
        f.release_year,
        LOWER(c.name) AS category_name,
        COUNT(*) AS cnt
    FROM public.film AS f
    INNER JOIN public.film_category AS fc ON fc.film_id = f.film_id
    INNER JOIN public.category      AS c  ON c.category_id = fc.category_id
    WHERE LOWER(c.name) IN ('drama','travel','documentary')
    GROUP BY f.release_year, LOWER(c.name)
),
years AS (
    SELECT DISTINCT f.release_year
    FROM public.film AS f
)
SELECT
    y.release_year,
    COALESCE(MAX(CASE WHEN pc.category_name = 'drama'       THEN pc.cnt END), 0) AS number_of_drama_movies,
    COALESCE(MAX(CASE WHEN pc.category_name = 'travel'      THEN pc.cnt END), 0) AS number_of_travel_movies,
    COALESCE(MAX(CASE WHEN pc.category_name = 'documentary' THEN pc.cnt END), 0) AS number_of_documentary_movies
FROM years AS y
LEFT JOIN per_cat AS pc
    ON pc.release_year = y.release_year
GROUP BY y.release_year
ORDER BY y.release_year DESC;
-- Pros: makes category series explicit. Cons: longer code.

-- Scalar subqueries per year
SELECT
  y.release_year,
  COALESCE((
    SELECT COUNT(*)
    FROM public.film f
    INNER JOIN public.film_category fc ON fc.film_id = f.film_id
    INNER JOIN public.category c ON c.category_id = fc.category_id
    WHERE f.release_year = y.release_year AND LOWER(c.name) = 'drama'
  ), 0) AS number_of_drama_movies,
  COALESCE((
    SELECT COUNT(*)
    FROM public.film f
    INNER JOIN public.film_category fc ON fc.film_id = f.film_id
    INNER JOIN public.category c ON c.category_id = fc.category_id
    WHERE f.release_year = y.release_year AND LOWER(c.name) = 'travel'
  ), 0) AS number_of_travel_movies,
  COALESCE((
    SELECT COUNT(*)
    FROM public.film f
    INNER JOIN public.film_category fc ON fc.film_id = f.film_id
    INNER JOIN public.category c ON c.category_id = fc.category_id
    WHERE f.release_year = y.release_year AND LOWER(c.name) = 'documentary'
  ), 0) AS number_of_documentary_movies
FROM (
  SELECT DISTINCT release_year
  FROM public.film
) AS y
ORDER BY y.release_year DESC;
-- Pros: simple to reason about; easy to add more categories. Cons: multiple subqueries per year.


/*
TASK 2.1
What is asked: 
Find three employees who generated the most revenue in 2017. If an employee worked in several stores during the year, show the store of their last processed payment in 2017. Use only payment_date to define 2017.
My understanding / business logic:
 - Revenue = SUM(public.payment.amount) where payment_date is in [2017-01-01, 2018-01-01).
 - The store of a payment is derived by payment → rental → inventory → store.
 - “Last store” = store from the most recent payment the staff processed in 2017. 
 */

-- JOIN + correlated subquery
SELECT
  s.first_name,
  s.last_name,
  SUM(p.amount) AS revenue_2017,
  (
    SELECT CONCAT_WS(' ', a.address, a.address2)
    FROM public.payment p2
    INNER JOIN public.rental   r2 ON r2.rental_id = p2.rental_id
    INNER JOIN public.inventory i2 ON i2.inventory_id = r2.inventory_id
    INNER JOIN public.store    st  ON st.store_id   = i2.store_id
    INNER JOIN public.address  a   ON a.address_id  = st.address_id
    WHERE p2.staff_id = s.staff_id
      AND p2.payment_date >= DATE '2017-01-01'
      AND p2.payment_date <  DATE '2018-01-01'
    ORDER BY p2.payment_date DESC, p2.payment_id DESC
    LIMIT 1
  ) AS last_store_2017
FROM public.staff   AS s
INNER JOIN public.payment AS p
  ON p.staff_id = s.staff_id
WHERE p.payment_date >= DATE '2017-01-01'
  AND p.payment_date <  DATE '2018-01-01'
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY revenue_2017 DESC, s.last_name, s.first_name
LIMIT 3;
-- Pros: Short and clear; no hard-coded IDs. Cons: subquery executes per staff.

-- CTEs
WITH payments_2017 AS (
  SELECT payment_id, staff_id, rental_id, amount, payment_date
  FROM public.payment
  WHERE payment_date >= DATE '2017-01-01'
    AND payment_date <  DATE '2018-01-01'
),
revenue_by_staff AS (
  SELECT staff_id, SUM(amount) AS revenue_2017
  FROM payments_2017
  GROUP BY staff_id
),
last_payment_per_staff AS (
  SELECT p1.staff_id, p1.rental_id
  FROM payments_2017 p1
  INNER JOIN (
    SELECT staff_id, MAX(payment_date) AS last_dt
    FROM payments_2017
    GROUP BY staff_id
  ) mx
    ON mx.staff_id = p1.staff_id AND mx.last_dt = p1.payment_date
  WHERE p1.payment_id = (
    SELECT MAX(p2.payment_id)
    FROM payments_2017 p2
    WHERE p2.staff_id = p1.staff_id AND p2.payment_date = p1.payment_date
  )
),
last_store AS (
  SELECT
    lps.staff_id,
    CONCAT_WS(' ', a.address, a.address2) AS last_store_2017
  FROM last_payment_per_staff lps
  INNER JOIN public.rental   r  ON r.rental_id  = lps.rental_id
  INNER JOIN public.inventory i  ON i.inventory_id = r.inventory_id
  INNER JOIN public.store    st ON st.store_id  = i.store_id
  INNER JOIN public.address  a  ON a.address_id = st.address_id
)
SELECT
  s.first_name,
  s.last_name,
  rbs.revenue_2017,
  ls.last_store_2017
FROM revenue_by_staff rbs
INNER JOIN public.staff s ON s.staff_id = rbs.staff_id
LEFT  JOIN last_store  ls ON ls.staff_id = rbs.staff_id
ORDER BY rbs.revenue_2017 DESC, s.last_name, s.first_name
LIMIT 3;
-- Pros: Clean separation of concerns; easy to test each step. Cons: Longer code. Execution time.

-- Subquery
SELECT
  s.first_name,
  s.last_name,
  (
    SELECT SUM(p.amount)
    FROM public.payment p
    WHERE p.staff_id = s.staff_id
      AND p.payment_date >= DATE '2017-01-01'
      AND p.payment_date <  DATE '2018-01-01'
  ) AS revenue_2017,
  (
    SELECT CONCAT_WS(' ', a.address, a.address2)
    FROM public.payment p2
    INNER JOIN public.rental   r2 ON r2.rental_id = p2.rental_id
    INNER JOIN public.inventory i2 ON i2.inventory_id = r2.inventory_id
    INNER JOIN public.store    st  ON st.store_id   = i2.store_id
    INNER JOIN public.address  a   ON a.address_id  = st.address_id
    WHERE p2.staff_id = s.staff_id
      AND p2.payment_date >= DATE '2017-01-01'
      AND p2.payment_date <  DATE '2018-01-01'
    ORDER BY p2.payment_date DESC, p2.payment_id DESC
    LIMIT 1
  ) AS last_store_2017
FROM public.staff s
WHERE EXISTS (
  SELECT 1 FROM public.payment p
  WHERE p.staff_id = s.staff_id
    AND p.payment_date >= DATE '2017-01-01'
    AND p.payment_date <  DATE '2018-01-01'
)
ORDER BY revenue_2017 DESC, s.last_name, s.first_name
LIMIT 3;
-- Pros: Very explicit; easy to explain. Cons: Two correlated subqueries per staff.


/*
TASK 2.2
What is asked: 
Show 5 films with the highest number of rentals and add an “expected age” column using MPA rating mapping:
G→0+, PG→10+, PG-13→13+, R→17+, NC-17→18+.
My understanding / business logic:
 - Rentals per film via inventory → rental.
 - Map film.rating to age using a CASE expression. 
 */

-- JOIN 
SELECT
  f.title,
  COUNT(r.rental_id) AS number_of_rentals,
  CASE UPPER(f.rating::text)
    WHEN 'G'      THEN '0+'
    WHEN 'PG'     THEN '10+'
    WHEN 'PG-13'  THEN '13+'
    WHEN 'R'      THEN '17+'
    WHEN 'NC-17'  THEN '18+'
    ELSE NULL
  END AS expected_audience_age
FROM public.film      AS f
INNER JOIN public.inventory AS i ON i.film_id      = f.film_id
INNER JOIN public.rental   AS r ON r.inventory_id = i.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY number_of_rentals DESC, f.title
LIMIT 5;
-- Pros: Straightforward and fast. Cons: None.
   
-- CTE
WITH film_rentals AS (
  SELECT i.film_id, COUNT(*) AS number_of_rentals
  FROM public.inventory i
  INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
  GROUP BY i.film_id
)
SELECT
  f.title,
  fr.number_of_rentals,
  CASE UPPER(f.rating::text)
    WHEN 'G'      THEN '0+'
    WHEN 'PG'     THEN '10+'
    WHEN 'PG-13'  THEN '13+'
    WHEN 'R'      THEN '17+'
    WHEN 'NC-17'  THEN '18+'
    ELSE NULL
  END AS expected_audience_age
FROM film_rentals fr
INNER JOIN public.film f ON f.film_id = fr.film_id
ORDER BY fr.number_of_rentals DESC, f.title
LIMIT 5;
-- Pros: Easy to extend (e.g., add revenue). Cons: Slightly more verbose.
  
-- Subquery
SELECT
  f.title,
  (
    SELECT COUNT(*)
    FROM public.inventory i
    INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
    WHERE i.film_id = f.film_id
  ) AS number_of_rentals,
  CASE UPPER(f.rating::text)
    WHEN 'G'      THEN '0+'
    WHEN 'PG'     THEN '10+'
    WHEN 'PG-13'  THEN '13+'
    WHEN 'R'      THEN '17+'
    WHEN 'NC-17'  THEN '18+'
    ELSE NULL
  END AS expected_audience_age
FROM public.film f
ORDER BY number_of_rentals DESC, f.title
LIMIT 5;
-- Pros: Minimal joins in the outer query. Cons: Subquery runs per film.


/*
TASK 3 V1
What is asked: 
Gap between the latest film’s release_year and the current year
My understanding / business logic:
 - For each actor, compute current_year - MAX(release_year) across their films.
 - Use EXTRACT(YEAR FROM CURRENT_DATE) so nothing is hard-coded. 
 */

-- JOIN 
SELECT
  a.first_name,
  a.last_name,
  MAX(f.release_year) AS last_release_year,
  EXTRACT(YEAR FROM CURRENT_DATE)::int - MAX(f.release_year) AS years_since_last_movie
FROM public.actor a
INNER JOIN public.film_actor fa ON fa.actor_id = a.actor_id
INNER JOIN public.film f        ON f.film_id   = fa.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_since_last_movie DESC, a.last_name, a.first_name;

-- CTE 
WITH last_year AS (
  SELECT fa.actor_id, MAX(f.release_year) AS last_release_year
  FROM public.film_actor fa
  INNER JOIN public.film f ON f.film_id = fa.film_id
  GROUP BY fa.actor_id
)
SELECT
  a.first_name,
  a.last_name,
  ly.last_release_year,
  EXTRACT(YEAR FROM CURRENT_DATE)::int - ly.last_release_year AS years_since_last_movie
FROM last_year ly
INNER JOIN public.actor a ON a.actor_id = ly.actor_id
ORDER BY years_since_last_movie DESC, a.last_name, a.first_name;

-- Subquery 
SELECT
  a.first_name,
  a.last_name,
  (SELECT MAX(f.release_year)
   FROM public.film_actor fa
   INNER JOIN public.film f ON f.film_id = fa.film_id
   WHERE fa.actor_id = a.actor_id) AS last_release_year,
  EXTRACT(YEAR FROM CURRENT_DATE)::int -
  (SELECT MAX(f.release_year)
   FROM public.film_actor fa
   INNER JOIN public.film f ON f.film_id = fa.film_id
   WHERE fa.actor_id = a.actor_id) AS years_since_last_movie
FROM public.actor a
ORDER BY years_since_last_movie DESC, a.last_name, a.first_name;


/*
TASK 3 V2
What is asked: 
Sequential gaps between films per actor (longest inactivity stretch)
My understanding / business logic:
 - For each actor, create the ordered set of distinct release_year values.
 - For every year y1, find the next year y2 > y1 for that actor, then compute gap = y2 - y1.
 - Report the maximum such gap per actor. 
 */
   
-- JOIN
WITH actor_years AS (
  SELECT DISTINCT fa.actor_id, f.release_year
  FROM public.film_actor fa
  INNER JOIN public.film f ON f.film_id = fa.film_id
),
next_year AS (
  SELECT
    y1.actor_id,
    y1.release_year AS start_year,
    MIN(y2.release_year) AS next_year
  FROM actor_years y1
  LEFT JOIN actor_years y2
    ON y2.actor_id = y1.actor_id
   AND y2.release_year > y1.release_year
  GROUP BY y1.actor_id, y1.release_year
),
gaps AS (
  SELECT actor_id, COALESCE(next_year - start_year, 0) AS gap_years
  FROM next_year
)
SELECT
  a.first_name,
  a.last_name,
  MAX(g.gap_years) AS longest_inactivity_years
FROM gaps g
INNER JOIN public.actor a ON a.actor_id = g.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY longest_inactivity_years DESC, a.last_name, a.first_name;
-- Pros: Pure joins/aggregations; easy to follow. Cons: Two passes.

-- CTE 
WITH actor_years AS (
  SELECT DISTINCT fa.actor_id, f.release_year
  FROM public.film_actor fa
  INNER JOIN public.film f ON f.film_id = fa.film_id
),
adjacent_pairs AS (
  SELECT y1.actor_id, y1.release_year AS start_year, y2.release_year AS next_year
  FROM actor_years y1
  INNER JOIN actor_years y2
    ON y2.actor_id = y1.actor_id AND y2.release_year > y1.release_year
  LEFT JOIN actor_years y3
    ON y3.actor_id = y1.actor_id
   AND y3.release_year > y1.release_year
   AND y3.release_year < y2.release_year
  WHERE y3.actor_id IS NULL
),
gaps AS (
  SELECT actor_id, (next_year - start_year) AS gap_years
  FROM adjacent_pairs
)
SELECT
  a.first_name,
  a.last_name,
  COALESCE(MAX(g.gap_years), 0) AS longest_inactivity_years
FROM public.actor a
LEFT JOIN gaps g ON g.actor_id = a.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY longest_inactivity_years DESC, a.last_name, a.first_name;
-- Pros: Computes true adjacent gaps. Cons: Slightly heavier join logic.

-- Subquery
SELECT
  a.first_name,
  a.last_name,
  (
    SELECT MAX(
      COALESCE((
        SELECT MIN(f2.release_year)
        FROM public.film_actor fa2
        INNER JOIN public.film f2 ON f2.film_id = fa2.film_id
        WHERE fa2.actor_id = a.actor_id
          AND f2.release_year > y.release_year
      ) - y.release_year, 0)
    )
    FROM (
      SELECT DISTINCT f.release_year
      FROM public.film_actor fa
      INNER JOIN public.film f ON f.film_id = fa.film_id
      WHERE fa.actor_id = a.actor_id
    ) AS y
  ) AS longest_inactivity_years
FROM public.actor a
ORDER BY longest_inactivity_years DESC, a.last_name, a.first_name;
-- Pros: No grouping outside; concise. Cons: Deeply nested subqueries. Execution time.

