-- Task 2: 

-- 2.1 Create login user "rentaluser" with password "rentalpassword"
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rentaluser'
    ) THEN
        CREATE ROLE rentaluser
            LOGIN
            PASSWORD 'rentalpassword';
    END IF;
END
$$;

-- Allow rentaluser to connect to dvdrental database
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;



-- 2.2 Grant SELECT permission on the "customer" table to rentaluser
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Optional test:
-- SET ROLE rentaluser;
-- SELECT * FROM public.customer LIMIT 10;
-- RESET ROLE;



-- 2.3 Create group role "rental" and add "rentaluser" to that group
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rental'
    ) THEN
        CREATE ROLE rental;
    END IF;
END
$$;

GRANT rental TO rentaluser;



-- 2.4 Grant INSERT and UPDATE on the "rental" table to the "rental" group
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- Allow group "rental" to use rental_id sequence (needed for INSERT)
GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;

-- Optional test as rentaluser:
-- SET ROLE rentaluser;
-- INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
-- VALUES (CURRENT_TIMESTAMP, 1, 1, CURRENT_TIMESTAMP + INTERVAL '3 days', 1);
--
-- UPDATE public.rental
--    SET return_date = CURRENT_TIMESTAMP
--  WHERE rental_id = (
--        SELECT MAX(rental_id) FROM public.rental
--      );
-- RESET ROLE;



-- 2.5 Revoke INSERT from the "rental" group on the "rental" table
REVOKE INSERT ON TABLE public.rental FROM rental;

-- Optional negative test:
-- SET ROLE rentaluser;
-- INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
-- VALUES (CURRENT_TIMESTAMP, 1, 1, CURRENT_TIMESTAMP + INTERVAL '3 days', 1);
-- RESET ROLE;



-- 2.6 Create a personalized role for a customer with payments and rentals
DO $$
DECLARE
    v_customer_id integer;
    v_first_name  text;
    v_last_name   text;
    v_role_name   text;
BEGIN
    -- Pick one customer who has both rentals and payments
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name
    INTO
        v_customer_id,
        v_first_name,
        v_last_name
    FROM public.customer c
    WHERE EXISTS (
              SELECT 1
              FROM public.rental r
              WHERE r.customer_id = c.customer_id
          )
      AND EXISTS (
              SELECT 1
              FROM public.payment p
              WHERE p.customer_id = c.customer_id
          )
    ORDER BY c.customer_id
    LIMIT 1;

    -- Build role name: client_{first_name}_{last_name}
    v_role_name := format(
        'client_%s_%s',
        replace(v_first_name, ' ', ''),
        replace(v_last_name,  ' ', '')
    );

    -- Create the role only if it does not exist yet
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = v_role_name
    ) THEN
        EXECUTE format('CREATE ROLE %I LOGIN', v_role_name);
    END IF;
END
$$;



-- Task 3

DO $$
DECLARE
    v_customer_id integer;
    v_role_name   text;
BEGIN
    -- Find the personalized client_* role and its customer_id
    SELECT
        c.customer_id,
        r.rolname
    INTO
        v_customer_id,
        v_role_name
    FROM public.customer c
    JOIN pg_roles r
      ON lower(r.rolname) = lower(
             format(
                 'client_%s_%s',
                 replace(c.first_name, ' ', ''),
                 replace(c.last_name,  ' ', '')
             )
         )
    WHERE r.rolname LIKE 'client_%'
    ORDER BY c.customer_id
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Client role not found. Run Task 2.6 first.';
    END IF;

    -- Enable row-level security on rental and payment
    EXECUTE 'ALTER TABLE public.rental  ENABLE ROW LEVEL SECURITY';
    EXECUTE 'ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY';

    -- Make script re-runnable
    EXECUTE 'DROP POLICY IF EXISTS rental_client_rls  ON public.rental';
    EXECUTE 'DROP POLICY IF EXISTS payment_client_rls ON public.payment';

    -- Policy: client_* can SELECT only their own rows in rental
    EXECUTE format(
        'CREATE POLICY rental_client_rls ON public.rental
           FOR SELECT
           TO %I
           USING (customer_id = %s);',
        v_role_name,
        v_customer_id
    );

    -- Policy: client_* can SELECT only their own rows in payment
    EXECUTE format(
        'CREATE POLICY payment_client_rls ON public.payment
           FOR SELECT
           TO %I
           USING (customer_id = %s);',
        v_role_name,
        v_customer_id
    );

    -- Grant SELECT so the policies actually apply
    EXECUTE format('GRANT SELECT ON public.rental  TO %I;', v_role_name);
    EXECUTE format('GRANT SELECT ON public.payment TO %I;', v_role_name);
END
$$;



-- Simple test queries:

-- 1) Check which client_* role was created:
--    SELECT rolname FROM pg_roles WHERE rolname LIKE 'client_%';

-- 2) As that user, verify that only their own rows are visible:
--    SET ROLE "client_First_Last";   -- replace with real role name from step 1
--    SELECT DISTINCT customer_id FROM public.rental;
--    SELECT DISTINCT customer_id FROM public.payment;
--    RESET ROLE;