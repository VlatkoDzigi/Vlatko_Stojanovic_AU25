-- Task 1.1: Insert 3 favorite films 
BEGIN;

WITH lang AS (
  SELECT language_id FROM public.language WHERE name = 'English' LIMIT 1
),
to_insert AS (
  SELECT * FROM (VALUES
    ('Shutter Island',   'US psychological thriller (2010).',         2010,         7,           4.99::numeric, 138,    19.99::numeric,  'R'::mpaa_rating,      ARRAY['Trailers']::text[]),
    ('Toma',             'Serbian biographical drama (2021).',        2021,         14,          9.99::numeric, 140,    19.99::numeric,  'PG-13'::mpaa_rating,   ARRAY['Trailers']::text[]),
    ('Nebeska udica',    'Serbian drama (1999/2000).',                2000,         21,          19.99::numeric,105,    19.99::numeric,  'PG-13'::mpaa_rating,   ARRAY['Trailers']::text[])
  ) AS v(title, description, release_year, rental_duration, rental_rate, length, replacement_cost, rating, special_features)
)
INSERT INTO public.film
  (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features)
SELECT v.title, v.description, v.release_year, lang.language_id, v.rental_duration, v.rental_rate, v.length, v.replacement_cost, v.rating, CURRENT_DATE, v.special_features
FROM to_insert v
CROSS JOIN lang
WHERE NOT EXISTS (
  SELECT 1 FROM public.film f WHERE LOWER(f.title) = LOWER(v.title)
)
RETURNING film_id, title, release_year, rental_rate, rental_duration;

COMMIT;

-- Verification:
SELECT title, release_year, rental_rate, rental_duration, rating
FROM public.film
WHERE title IN ('Shutter Island','Toma','Nebeska udica');


-- Task 1.2: Insert actors

/*
 - VALUES CTE keeps all names in one place (easy to review).
 - WHERE NOT EXISTS makes the script re-runnable without duplicates.
 - LOWER() on both sides makes compare case-insensitive.
 - last_update is set to CURRENT_DATE 
 */

BEGIN;

WITH actors(first_name, last_name) AS (
  VALUES
    ('Leonardo', 'DiCaprio'),
    ('Mark',     'Ruffalo'),
    ('Ben',      'Kingsley'),
    ('Milan',    'Maric'),
    ('Tamara',   'Dragicevic'),
    ('Petar',    'Bencina'),
    ('Nebojsa',  'Glogovac'),
    ('Nikola',   'Djuricko'),
    ('Dragan',   'Bjelogrlic'),
    ('Ana',      'Sofrenovic')
)
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT a.first_name, a.last_name, CURRENT_DATE
FROM actors a
WHERE NOT EXISTS (
  SELECT 1
  FROM public.actor t
  WHERE LOWER(t.first_name) = LOWER(a.first_name)
    AND LOWER(t.last_name)  = LOWER(a.last_name)
)
RETURNING actor_id, first_name, last_name;

COMMIT;

-- Verification:
SELECT first_name, last_name, last_update
FROM public.actor
WHERE (first_name, last_name) IN (
  ('Leonardo','DiCaprio'),
  ('Mark','Ruffalo'),
  ('Ben','Kingsley'),
  ('Milan','Maric'),
  ('Tamara','Dragicevic'),
  ('Petar','Bencina'),
  ('Nebojsa','Glogovac'),
  ('Nikola','Djuricko'),
  ('Dragan','Bjelogrlic'),
  ('Ana','Sofrenovic')
)
ORDER BY last_name, first_name;


-- Task 1.3: Link films and actors 

/*
- We declare the desired film–actor pairs inline (easy to read and review).
- We JOIN to lookup IDs instead of hardcoding them.
- LOWER(...) matching makes it robust to case differences.
- WHERE NOT EXISTS prevents duplicates.
*/

BEGIN;

WITH pairs (film, first, last) AS (
  SELECT 'Shutter Island',  'Leonardo', 'DiCaprio'   UNION ALL
  SELECT 'Shutter Island',  'Mark',     'Ruffalo'    UNION ALL
  SELECT 'Shutter Island',  'Ben',      'Kingsley'   UNION ALL
  SELECT 'Toma',            'Milan',    'Maric'      UNION ALL
  SELECT 'Toma',            'Tamara',   'Dragicevic' UNION ALL
  SELECT 'Toma',            'Petar',    'Bencina'    UNION ALL
  SELECT 'Nebeska udica',   'Nebojsa',  'Glogovac'   UNION ALL
  SELECT 'Nebeska udica',   'Nikola',   'Djuricko'    UNION ALL
  SELECT 'Nebeska udica',   'Dragan',   'Bjelogrlic' UNION ALL
  SELECT 'Nebeska udica',   'Ana',      'Sofrenovic'
),
joined AS (
  SELECT f.film_id, a.actor_id
  FROM pairs p
  JOIN public.film  f
    ON LOWER(f.title) = LOWER(p.film)
  JOIN public.actor a
    ON LOWER(a.first_name) = LOWER(p.first)
   AND LOWER(a.last_name)  = LOWER(p.last)
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT j.actor_id, j.film_id, CURRENT_DATE
FROM joined j
WHERE NOT EXISTS (
  SELECT 1
  FROM public.film_actor fa
  WHERE fa.actor_id = j.actor_id
    AND fa.film_id  = j.film_id
)
RETURNING actor_id, film_id;

COMMIT;

-- Verification:
SELECT f.title, a.first_name, a.last_name
FROM public.film_actor fa
JOIN public.film  f ON f.film_id  = fa.film_id
JOIN public.actor a ON a.actor_id = fa.actor_id
WHERE f.title IN ('Shutter Island','Toma','Nebeska udica')
ORDER BY f.title, a.last_name, a.first_name;


-- Task 1.4: Add one copy of each movie to an existing store

/*
 - No hard-coded IDs: we read store_id and film_id from tables.
 - WHERE NOT EXISTS prevents duplicates if rerun.
 - CURRENT_DATE fills required last_update. 
*/  

BEGIN;

WITH store_choice AS (
  SELECT store_id
  FROM public.store
  ORDER BY store_id
  LIMIT 1
),
films AS (
  SELECT film_id, title
  FROM public.film
  WHERE title IN ('Shutter Island', 'Toma', 'Nebeska udica')
),
to_insert AS (
  SELECT f.film_id, s.store_id
  FROM films f
  CROSS JOIN store_choice s
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
      AND i.store_id = s.store_id
  )
)

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT film_id, store_id, CURRENT_DATE
FROM to_insert
RETURNING inventory_id, film_id, store_id;

COMMIT;

-- Verification:
SELECT i.inventory_id, f.title, i.store_id
FROM public.inventory i
JOIN public.film f ON f.film_id = i.film_id
WHERE f.title IN ('Shutter Island', 'Toma', 'Nebeska udica')
ORDER BY f.title;


-- Task 1.5 Pick one customer with ≥43 rentals and ≥43 payments and update info

/* 
- No hard-coded IDs: both the customer and address are discovered by queries.
- The HAVING clause enforces ≥43 rentals and ≥43 payments.
- LIMIT 1 guarantees a single updated row.
- CURRENT_DATE sets last_update as required. 
*/

BEGIN;

WITH cust AS (
  SELECT c.customer_id
  FROM public.customer c
  JOIN public.rental  r ON r.customer_id  = c.customer_id
  JOIN public.payment p ON p.customer_id  = c.customer_id
  GROUP BY c.customer_id
  HAVING COUNT(DISTINCT r.rental_id)  >= 43
     AND COUNT(DISTINCT p.payment_id) >= 43
  ORDER BY COUNT(*) DESC
  LIMIT 1
),
any_addr AS (
  SELECT address_id
  FROM public.address
  ORDER BY address_id
  LIMIT 1
)

UPDATE public.customer c
SET first_name = 'Vlatko',
    last_name  = 'Stojanovic',
    email      = 'vlatko.stojanovic@example.com',
    address_id = (SELECT address_id FROM any_addr),
    last_update= CURRENT_DATE
WHERE c.customer_id = (SELECT customer_id FROM cust)
RETURNING customer_id, first_name, last_name, email, address_id;

COMMIT;

-- Verification:
SELECT COUNT(*) AS how_many_named_vlatko
FROM public.customer
WHERE first_name = 'Vlatko' AND last_name = 'Stojanovic';

SELECT c.customer_id, c.first_name, c.last_name, c.email, c.address_id
FROM public.customer c
WHERE c.first_name = 'Vlatko' AND c.last_name = 'Stojanovic';


-- Task 1.6: Rent the favorite movies and pay for them

/*
 - Picks one store and one staff member from that store.
 - Finds my three films and one inventory copy per film from that store.
 - Inserts rentals for me at a fixed timestamp; prevents duplicates with NOT EXISTS.
 - Inserts matching payments at a fixed timestamp; prevents duplicates with NOT EXISTS.
 */

BEGIN;

WITH t AS (
  SELECT TIMESTAMP '2017-03-15 10:00:00' AS rent_ts,
         TIMESTAMP '2017-03-15 10:05:00' AS pay_ts
),
cust AS (
  SELECT customer_id
  FROM public.customer
  WHERE first_name = 'Vlatko' AND last_name = 'Stojanovic'
  LIMIT 1
),
store_choice AS (
  SELECT store_id FROM public.store ORDER BY store_id LIMIT 1
),
staff_choice AS (
  SELECT staff_id
  FROM public.staff
  WHERE store_id = (SELECT store_id FROM store_choice)
  ORDER BY staff_id
  LIMIT 1
),
films AS (
  SELECT f.film_id, f.rental_duration, f.rental_rate
  FROM public.film f
  WHERE f.title IN ('Shutter Island','Toma','Nebeska udica')
),
inv AS (
  SELECT DISTINCT ON (i.film_id) i.inventory_id, i.film_id
  FROM public.inventory i
  JOIN store_choice s ON s.store_id = i.store_id
  JOIN films f ON f.film_id = i.film_id
  ORDER BY i.film_id, i.inventory_id
)
INSERT INTO public.rental
  (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT (SELECT rent_ts FROM t),
       i.inventory_id,
       (SELECT customer_id FROM cust),
       (SELECT rent_ts FROM t) + (f.rental_duration || ' days')::interval,
       (SELECT staff_id FROM staff_choice),
       CURRENT_DATE
FROM inv i
JOIN films f ON f.film_id = i.film_id
WHERE NOT EXISTS (
  SELECT 1
  FROM public.rental r
  WHERE r.inventory_id = i.inventory_id
    AND r.customer_id  = (SELECT customer_id FROM cust)
    AND r.rental_date  = (SELECT rent_ts FROM t)
);

WITH t AS (
  SELECT TIMESTAMP '2017-03-15 10:00:00' AS rent_ts,
         TIMESTAMP '2017-03-15 10:05:00' AS pay_ts
),
cust AS (
  SELECT customer_id
  FROM public.customer
  WHERE first_name = 'Vlatko' AND last_name = 'Stojanovic'
  LIMIT 1
),
store_choice AS (
  SELECT store_id FROM public.store ORDER BY store_id LIMIT 1
),
staff_choice AS (
  SELECT staff_id
  FROM public.staff
  WHERE store_id = (SELECT store_id FROM store_choice)
  ORDER BY staff_id
  LIMIT 1
),
films AS (
  SELECT f.film_id, f.rental_rate
  FROM public.film f
  WHERE f.title IN ('Shutter Island','Toma','Nebeska udica')
),
inv AS (
  SELECT DISTINCT ON (i.film_id) i.inventory_id, i.film_id
  FROM public.inventory i
  JOIN store_choice s ON s.store_id = i.store_id
  JOIN films f ON f.film_id = i.film_id
  ORDER BY i.film_id, i.inventory_id
),
new_rentals AS (
  SELECT r.rental_id, r.inventory_id
  FROM public.rental r
  JOIN inv i ON i.inventory_id = r.inventory_id
  WHERE r.customer_id = (SELECT customer_id FROM cust)
    AND r.rental_date = (SELECT rent_ts FROM t)
)
INSERT INTO public.payment
  (customer_id, staff_id, rental_id, amount, payment_date)
SELECT (SELECT customer_id FROM cust),
       (SELECT staff_id FROM staff_choice),
       nr.rental_id,
       f.rental_rate,
       (SELECT pay_ts FROM t)
FROM new_rentals nr
JOIN public.inventory i ON i.inventory_id = nr.inventory_id
JOIN films f ON f.film_id = i.film_id
WHERE NOT EXISTS (
  SELECT 1
  FROM public.payment p
  WHERE p.rental_id    = nr.rental_id
    AND p.payment_date = (SELECT pay_ts FROM t)
);

COMMIT;

-- Verification:
SELECT r.rental_id, r.inventory_id, r.customer_id, r.rental_date, r.return_date
FROM public.rental r
JOIN public.customer c ON c.customer_id = r.customer_id
WHERE c.first_name='Vlatko' AND c.last_name='Stojanovic'
  AND r.rental_date = TIMESTAMP '2017-03-15 10:00:00'
ORDER BY r.rental_id;

SELECT p.payment_id, p.rental_id, p.amount, p.payment_date
FROM public.payment p
WHERE p.payment_date = TIMESTAMP '2017-03-15 10:05:00'
ORDER BY p.payment_id;


-- Task 1.7: Clean up synthetic rental and payment records

/*
 - It deletes payment and rental records that were created at those specific timestamps (2017-03-15 10:00:00 and 10:05:00).
 - It does not touch the customer or inventory tables — only temporary “simulation” records are removed.
*/

BEGIN;

WITH target_rentals AS (
  SELECT r.rental_id
  FROM public.rental r
  WHERE r.rental_date = TIMESTAMP '2017-03-15 10:00:00'
),
del_pay AS (
  DELETE FROM public.payment p
  WHERE p.rental_id IN (SELECT rental_id FROM target_rentals)
    AND p.payment_date = TIMESTAMP '2017-03-15 10:05:00'
  RETURNING payment_id
),
del_rent AS (
  DELETE FROM public.rental r
  WHERE r.rental_id IN (SELECT rental_id FROM target_rentals)
  RETURNING rental_id
)
SELECT 
  (SELECT COUNT(*) FROM del_pay)  AS payments_deleted,
  (SELECT COUNT(*) FROM del_rent) AS rentals_deleted;

COMMIT;

-- Verification:
SELECT COUNT(*) AS remaining_payments
FROM public.payment
WHERE payment_date = TIMESTAMP '2017-03-15 10:05:00';

SELECT COUNT(*) AS remaining_rentals
FROM public.rental
WHERE rental_date = TIMESTAMP '2017-03-15 10:00:00';