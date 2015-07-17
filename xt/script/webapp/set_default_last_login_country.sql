/* BAU to initialize data for CANDO-1699 */

/* done as two separate transactions to limit the amount
   of time the customer table could be locked for */

/* first, set last_login_country to the country
   from the most recent order they placed */

BEGIN WORK;

UPDATE customer AS c
  JOIN ( SELECT MAX(o.id)  AS order_id,
                    c2.id  AS customer_id
           FROM customer AS c2
           JOIN orders   AS o
             ON c2.id = o.customer_id
          GROUP BY c2.id
       ) AS mo
    ON c.id = mo.customer_id
   AND c.last_login_country IS NULL
  JOIN order_item AS oi
    ON mo.order_id = oi.order_id
  JOIN order_address AS oa
    ON oi.order_item_address = oa.id
   SET c.last_login_country = oa.country
     ;

COMMIT WORK;

/* then, for customers who haven't placed an order yet,
   default to their country of registration */

BEGIN WORK;

UPDATE customer
   SET last_login_country = registered_country_id
 WHERE last_login_country IS NULL
     ;

COMMIT WORK;
