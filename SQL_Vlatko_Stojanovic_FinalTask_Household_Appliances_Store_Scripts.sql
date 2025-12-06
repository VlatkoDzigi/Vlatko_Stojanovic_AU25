-- Task 3

-- CREATE DATABASE household_store_db;

DROP SCHEMA IF EXISTS household_store CASCADE;

CREATE SCHEMA household_store;

CREATE TABLE household_store.product_category (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR(100) NOT NULL,
    CONSTRAINT pk_product_category PRIMARY KEY (category_id),
    CONSTRAINT uq_product_category_name UNIQUE (name)
);

CREATE TABLE household_store.supplier (
    supplier_id   BIGINT GENERATED ALWAYS AS IDENTITY,
    supplier_name VARCHAR(150) NOT NULL,
    CONSTRAINT pk_supplier PRIMARY KEY (supplier_id)
);

CREATE TABLE household_store.customer (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    email       VARCHAR(255) NOT NULL,
    CONSTRAINT pk_customer PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_email UNIQUE (email)
);

CREATE TABLE household_store.employee (
    employee_id BIGINT GENERATED ALWAYS AS IDENTITY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    job_title   VARCHAR(100) NOT NULL,
    CONSTRAINT pk_employee PRIMARY KEY (employee_id)
);

CREATE TABLE household_store.product (
    product_id     BIGINT GENERATED ALWAYS AS IDENTITY,
    category_id    BIGINT NOT NULL,
    supplier_id    BIGINT NOT NULL,
    product_name   VARCHAR(150) NOT NULL,
    brand          VARCHAR(100) NOT NULL,
    unit_price     NUMERIC(10,2) NOT NULL,
    stock_quantity INTEGER NOT NULL,
    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES household_store.product_category (category_id),
    CONSTRAINT fk_product_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES household_store.supplier (supplier_id)
);

CREATE TABLE household_store.sales_order (
    order_id     BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id  BIGINT NOT NULL,
    employee_id  BIGINT NOT NULL,
    order_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    order_status VARCHAR(20) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    CONSTRAINT pk_sales_order PRIMARY KEY (order_id),
    CONSTRAINT fk_sales_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES household_store.customer (customer_id),
    CONSTRAINT fk_sales_order_employee
        FOREIGN KEY (employee_id)
        REFERENCES household_store.employee (employee_id)
);

CREATE TABLE household_store.sales_order_item (
    order_id   BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity   INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_total NUMERIC(12,2)
        GENERATED ALWAYS AS (quantity * unit_price) STORED,
    CONSTRAINT pk_sales_order_item PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_sales_order_item_order
        FOREIGN KEY (order_id)
        REFERENCES household_store.sales_order (order_id),
    CONSTRAINT fk_sales_order_item_product
        FOREIGN KEY (product_id)
        REFERENCES household_store.product (product_id)
);

ALTER TABLE household_store.sales_order
    ADD CONSTRAINT chk_sales_order_date_after_2024
    CHECK (order_date > DATE '2024-01-01');

ALTER TABLE household_store.sales_order
    ADD CONSTRAINT chk_sales_order_status_allowed
    CHECK (order_status IN ('PENDING', 'PAID', 'SHIPPED', 'CANCELLED'));

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_unit_price_non_negative
    CHECK (unit_price >= 0);

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_stock_quantity_non_negative
    CHECK (stock_quantity >= 0);

ALTER TABLE household_store.sales_order_item
    ADD CONSTRAINT chk_sales_order_item_quantity_positive
    CHECK (quantity > 0);

ALTER TABLE household_store.sales_order_item
    ADD CONSTRAINT chk_sales_order_item_unit_price_non_negative
    CHECK (unit_price >= 0);



-- Task 4

INSERT INTO household_store.product_category (name) VALUES
    ('Refrigerators'),
    ('Washing Machines'),
    ('Dishwashers'),
    ('Ovens'),
    ('Vacuum Cleaners'),
    ('Air Conditioners');

INSERT INTO household_store.supplier (supplier_name) VALUES
    ('Balkan Cooling d.o.o.'),
    ('Adriatic Appliances d.o.o.'),
    ('Danube Electronics d.o.o.'),
    ('Alps Home Supply GmbH'),
    ('Sava Whitegoods d.o.o.'),
    ('Dinaric Imports d.o.o.');

INSERT INTO household_store.customer (first_name, last_name, email) VALUES
    ('Marko',  'Petrovic',   'marko.petrovic@example.com'),
    ('Ivana',  'Kovacevic',  'ivana.kovacevic@example.com'),
    ('Stefan', 'Nikolic',    'stefan.nikolic@example.com'),
    ('Elena',  'Stojanov',   'elena.stojanov@example.com'),
    ('Luka',   'Djordjevic', 'luka.djordjevic@example.com'),
    ('Maja',   'Popovic',    'maja.popovic@example.com');

INSERT INTO household_store.employee (first_name, last_name, job_title) VALUES
    ('Ana',    'Jovanovic',  'Sales Representative'),
    ('Milan',  'Ilic',       'Sales Representative'),
    ('Jelena', 'Markovic',   'Store Manager'),
    ('Nemanja','Radic',      'Sales Representative'),
    ('Sara',   'Milosevic',  'Cashier'),
    ('Petar',  'Vasic',      'Sales Representative');

INSERT INTO household_store.product (
    category_id,
    supplier_id,
    product_name,
    brand,
    unit_price,
    stock_quantity
) VALUES
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Refrigerators'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Balkan Cooling d.o.o.'),
        'CoolFresh 300L Fridge',
        'Gorenje',
        450.00,
        20
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Washing Machines'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Adriatic Appliances d.o.o.'),
        'EcoWash 7kg Washer',
        'Beko',
        320.00,
        15
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Dishwashers'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Danube Electronics d.o.o.'),
        'SilentDry Dishwasher',
        'Bosch',
        380.00,
        10
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Ovens'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Alps Home Supply GmbH'),
        'TurboHeat Oven',
        'Whirlpool',
        290.00,
        8
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Vacuum Cleaners'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Sava Whitegoods d.o.o.'),
        'DustAway Vacuum',
        'Philips',
        150.00,
        25
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Air Conditioners'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Dinaric Imports d.o.o.'),
        'BreezeCool 12kBTU AC',
        'LG',
        500.00,
        12
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Refrigerators'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Balkan Cooling d.o.o.'),
        'MiniCool 150L Fridge',
        'Gorenje',
        300.00,
        18
    ),
    (
        (SELECT category_id FROM household_store.product_category WHERE name = 'Washing Machines'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Adriatic Appliances d.o.o.'),
        'EcoWash 9kg Washer',
        'Beko',
        400.00,
        9
    );

INSERT INTO household_store.sales_order (
    customer_id,
    employee_id,
    order_date,
    order_status,
    total_amount
) VALUES
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'marko.petrovic@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Ana' AND last_name = 'Jovanovic'),
        CURRENT_DATE - INTERVAL '10 days',
        'PAID',
        600.00
    ),
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'ivana.kovacevic@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Milan' AND last_name = 'Ilic'),
        CURRENT_DATE - INTERVAL '20 days',
        'SHIPPED',
        700.00
    ),
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'stefan.nikolic@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Jelena' AND last_name = 'Markovic'),
        CURRENT_DATE - INTERVAL '30 days',
        'PENDING',
        590.00
    ),
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'elena.stojanov@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Nemanja' AND last_name = 'Radic'),
        CURRENT_DATE - INTERVAL '40 days',
        'PAID',
        800.00
    ),
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'luka.djordjevic@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Sara' AND last_name = 'Milosevic'),
        CURRENT_DATE - INTERVAL '50 days',
        'CANCELLED',
        550.00
    ),
    (
        (SELECT customer_id FROM household_store.customer WHERE email = 'maja.popovic@example.com'),
        (SELECT employee_id FROM household_store.employee WHERE first_name = 'Petar' AND last_name = 'Vasic'),
        CURRENT_DATE - INTERVAL '60 days',
        'PAID',
        620.00
    );

INSERT INTO household_store.sales_order_item (
    order_id,
    product_id,
    quantity,
    unit_price
) VALUES
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'marko.petrovic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '10 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'CoolFresh 300L Fridge'),
        1,
        450.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'marko.petrovic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '10 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'DustAway Vacuum'),
        1,
        150.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'ivana.kovacevic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '20 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'EcoWash 7kg Washer'),
        1,
        320.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'ivana.kovacevic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '20 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'SilentDry Dishwasher'),
        1,
        380.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'stefan.nikolic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '30 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'TurboHeat Oven'),
        1,
        290.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'stefan.nikolic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '30 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'DustAway Vacuum'),
        2,
        150.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'elena.stojanov@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '40 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'BreezeCool 12kBTU AC'),
        1,
        500.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'elena.stojanov@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '40 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'MiniCool 150L Fridge'),
        1,
        300.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'luka.djordjevic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '50 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'EcoWash 9kg Washer'),
        1,
        400.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'luka.djordjevic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '50 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'DustAway Vacuum'),
        1,
        150.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'maja.popovic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '60 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'EcoWash 7kg Washer'),
        1,
        320.00
    ),
    (
        (SELECT so.order_id
         FROM household_store.sales_order so
         JOIN household_store.customer c ON so.customer_id = c.customer_id
         WHERE c.email = 'maja.popovic@example.com'
           AND so.order_date = CURRENT_DATE - INTERVAL '60 days'),
        (SELECT product_id FROM household_store.product WHERE product_name = 'MiniCool 150L Fridge'),
        1,
        300.00
    );



-- Task 5.1 

CREATE OR REPLACE FUNCTION household_store.update_sales_order_column(
    p_order_id BIGINT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql   TEXT;
    v_rows  INTEGER;
BEGIN
    IF p_column_name NOT IN ('order_status', 'total_amount', 'order_date') THEN
        RAISE EXCEPTION 'Column % is not allowed to be updated by this function', p_column_name;
    END IF;

    v_sql := format(
        'UPDATE household_store.sales_order SET %I = $1 WHERE order_id = $2',
        p_column_name
    );

    EXECUTE v_sql USING p_new_value, p_order_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE NOTICE 'No sales_order row found with order_id %', p_order_id;
    END IF;

    RETURN v_rows;
END;
$$;



-- Task 5.2 

CREATE OR REPLACE FUNCTION household_store.create_sales_order(
    p_customer_email        TEXT,
    p_employee_first_name   TEXT,
    p_employee_last_name    TEXT,
    p_order_date            DATE,
    p_order_status          VARCHAR,
    p_total_amount          NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id BIGINT;
    v_employee_id BIGINT;
    v_order_id    BIGINT;
BEGIN
    SELECT customer_id
    INTO v_customer_id
    FROM household_store.customer
    WHERE email = p_customer_email;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Customer with email % not found', p_customer_email;
    END IF;

    SELECT employee_id
    INTO v_employee_id
    FROM household_store.employee
    WHERE first_name = p_employee_first_name
      AND last_name  = p_employee_last_name;

    IF v_employee_id IS NULL THEN
        RAISE EXCEPTION 'Employee % % not found', p_employee_first_name, p_employee_last_name;
    END IF;

    INSERT INTO household_store.sales_order (
        customer_id,
        employee_id,
        order_date,
        order_status,
        total_amount
    )
    VALUES (
        v_customer_id,
        v_employee_id,
        p_order_date,
        p_order_status,
        p_total_amount
    )
    RETURNING order_id INTO v_order_id;

    RETURN v_order_id;
END;
$$;



-- Task 6

CREATE OR REPLACE VIEW household_store.v_latest_quarter_sales AS
WITH latest_quarter AS (
    SELECT date_trunc('quarter', MAX(order_date)) AS quarter_start
    FROM household_store.sales_order
),
quarter_orders AS (
    SELECT
        so.order_id,
        so.order_date,
        soi.product_id,
        soi.quantity,
        soi.line_total
    FROM household_store.sales_order so
    JOIN household_store.sales_order_item soi
        ON so.order_id = soi.order_id
    JOIN latest_quarter lq
        ON so.order_date >= lq.quarter_start
       AND so.order_date <  lq.quarter_start + INTERVAL '3 months'
)
SELECT
    to_char(lq.quarter_start, 'YYYY-"Q"Q') AS quarter_label,
    pc.name       AS category_name,
    p.product_name,
    SUM(qo.quantity)   AS total_quantity,
    SUM(qo.line_total) AS total_revenue
FROM quarter_orders qo
JOIN household_store.product p
    ON qo.product_id = p.product_id
JOIN household_store.product_category pc
    ON p.category_id = pc.category_id
JOIN latest_quarter lq ON TRUE
GROUP BY
    lq.quarter_start,
    pc.name,
    p.product_name
ORDER BY
    pc.name,
    p.product_name;



-- Task 7

CREATE ROLE household_store_manager
    LOGIN
    PASSWORD 'ManagerStrongPass123!';

GRANT CONNECT ON DATABASE household_store_db
    TO household_store_manager;

GRANT USAGE ON SCHEMA household_store
    TO household_store_manager;

GRANT SELECT ON ALL TABLES IN SCHEMA household_store
    TO household_store_manager;

ALTER DEFAULT PRIVILEGES IN SCHEMA household_store
    GRANT SELECT ON TABLES TO household_store_manager;
