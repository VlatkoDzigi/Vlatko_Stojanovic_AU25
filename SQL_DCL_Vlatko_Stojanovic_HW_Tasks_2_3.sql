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

-- Optional test (run manually):
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

-- rental group also needs SELECT on rental for the UPDATE test query
GRANT SELECT ON TABLE public.rental TO rental;

-- Allow group "rental" to use rental_id sequence (needed for INSERT)
GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;

-- Optional test as rentaluser (run manually):
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

-- Optional negative test (run manually, will fail with permission error):
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

-- Enable row-level security on rental and payment tables
ALTER TABLE public.rental  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Re-create policies so the script is re-runnable
DROP POLICY IF EXISTS rental_client_rls  ON public.rental;
DROP POLICY IF EXISTS payment_client_rls ON public.payment;

-- Policy: 
-- - non client_* roles see all rows
-- - client_* roles see only rows for their own customer_id
CREATE POLICY rental_client_rls ON public.rental
FOR SELECT
USING (
    NOT current_user LIKE 'client_%'
    OR customer_id = (
        SELECT c.customer_id
        FROM public.customer c
        WHERE lower(
                format(
                    'client_%s_%s',
                    replace(c.first_name, ' ', ''),
                    replace(c.last_name,  ' ', '')
                )
              ) = lower(current_user)
        LIMIT 1
    )
);

CREATE POLICY payment_client_rls ON public.payment
FOR SELECT
USING (
    NOT current_user LIKE 'client_%'
    OR customer_id = (
        SELECT c.customer_id
        FROM public.customer c
        WHERE lower(
                format(
                    'client_%s_%s',
                    replace(c.first_name, ' ', ''),
                    replace(c.last_name,  ' ', '')
                )
              ) = lower(current_user)
        LIMIT 1
    )
);

-- Create client_{first}_{last} roles for every customer with rental & payment
-- history and grant them SELECT on rental and payment
DO $$
DECLARE
    rec_customer RECORD;
    v_role_name  text;
BEGIN
    FOR rec_customer IN
        SELECT c.customer_id, c.first_name, c.last_name
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
    LOOP
        v_role_name := format(
            'client_%s_%s',
            replace(rec_customer.first_name, ' ', ''),
            replace(rec_customer.last_name,  ' ', '')
        );

        -- Create role if it does not exist yet
        IF NOT EXISTS (
            SELECT 1
            FROM pg_roles
            WHERE rolname = v_role_name
        ) THEN
            EXECUTE format('CREATE ROLE %I LOGIN;', v_role_name);
        END IF;

        -- Grant SELECT so RLS policies can apply
        EXECUTE format('GRANT SELECT ON public.rental  TO %I;', v_role_name);
        EXECUTE format('GRANT SELECT ON public.payment TO %I;', v_role_name);
    END LOOP;
END
$$;



-- Simple test queries:

-- 1) Check which client_* roles were created:
--    SELECT rolname FROM pg_roles WHERE rolname LIKE 'client_%' ORDER BY rolname;

-- 2) Pick one of them and verify that this user sees only their own rows:
--    SET ROLE "client_First_Last";   -- replace with real role name from step 1
--    SELECT DISTINCT customer_id FROM public.rental;
--    SELECT DISTINCT customer_id FROM public.payment;
--    RESET ROLE;
