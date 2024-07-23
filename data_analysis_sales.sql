-- Calculate Monthly Sales Growth Rate for Q1 2019

   WITH sales_by_month AS(
        SELECT month,
            SUM(cogs) AS total_monthly_sales
        FROM df_sales
        GROUP BY month
    )

    SELECT month,
        total_monthly_sales,
            CAST(
                COALESCE(
                        (total_monthly_sales - LAG(total_monthly_sales) OVER(ORDER BY month)) / LAG(total_monthly_sales) OVER(ORDER BY month) * 100 
                , 0) 
            AS INT) AS sales_growth_rate_perc
    FROM sales_by_month
    ORDER BY month


-- Calculate customer satisfaction score CSAT for Q1

    SELECT branch_city, csat_by_branch, csat_q1_2019
    FROM (
    SELECT
        branch_city,
            ROUND(
                SUM(CASE WHEN rating >= 6 THEN 1 ELSE 0 END) OVER(PARTITION BY branch_city) / CAST(COUNT(rating) OVER(PARTITION BY branch_city) AS FLOAT)  * 100
            , 0) AS csat_by_branch,
            ROUND(
                SUM(CASE WHEN rating >= 6 THEN 1 ELSE 0 END) OVER() / CAST(COUNT(rating) OVER() AS FLOAT)  * 100
            , 0) AS csat_q1_2019,
        ROW_NUMBER() OVER(PARTITION BY branch_city ORDER BY branch_city) AS rank
        FROM df_sales    
    ) csat
    WHERE rank = 1


-- Product Lines' Revenue and Best Performing Month in Q1
-- For each Product Line, which month had the highest sales and profit?

    WITH product_line_totals AS
        (
            SELECT
                product_line,
                month,
                SUM(cogs) AS total_sales,
                SUM(gross_profit) AS total_profit,
                SUM(quantity) AS total_quantity,
                DENSE_RANK() OVER(PARTITION BY product_line ORDER BY SUM(cogs) DESC) AS rank
            FROM df_sales
            GROUP BY product_line, month
        )

    SELECT
        product_line,
        month, 
        (CASE WHEN month = 1 THEN 'Jan'
              WHEN month = 2 THEN 'Feb'
              ELSE 'Mar' END) AS month_name,
        total_sales,
        total_profit,
        total_quantity
    FROM product_line_totals
    WHERE rank = 1
    ORDER BY total_sales DESC


-- Hourly Analysis of Customer Purchases 10am - 8pm

        WITH totals_by_hour AS(
        SELECT hour_24,
            SUM(cogs) AS total_sales,
            SUM(gross_profit) AS total_profit,
            SUM(quantity) AS total_quantity,
            COUNT(hour_24) AS clients_visited
        FROM df_sales
        GROUP BY hour_24
    ),
    gender_purchases_by_hour AS(
        SELECT hour_24,
            gender,
            COUNT(gender) AS total_gen,
            ROW_NUMBER() OVER(PARTITION BY hour_24 ORDER BY COUNT(gender) DESC) AS rn
        FROM df_sales
        GROUP BY hour_24, gender
    )

    SELECT tbh.hour_24,
        tbh.clients_visited,
        tbh.total_sales,
        tbh.total_profit,
        tbh.total_quantity,
        gp.gender AS gender_buying_more
    FROM totals_by_hour tbh 
    INNER JOIN gender_purchases_by_hour gp
    ON tbh.hour_24 = gp.hour_24
    WHERE gp.rn = 1
    ORDER BY tbh.total_sales DESC, tbh.total_quantity DESC


-- Comparative Analysis of Branch Performance
    -- Total units sold, revenue, average rating, average profit
    -- Most frequently used payment method
    -- Dominant gender

    WITH branch_comparison AS(
            SELECT branch_city,
            SUM(quantity) AS total_units_sold,
            SUM(cogs) AS total_revenue,
            SUM(gross_profit) AS total_profit,
            AVG(gross_profit) AS avg_profit,
            AVG(rating) AS avg_rating,
            SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) AS females,
            SUM(CASE WHEN gender = 'Male' THEN 1 ELSE 0 END) AS males
            FROM df_sales
        GROUP BY branch_city
    ),
        payment_methods AS(
            SELECT branch_city,
            payment,
            COUNT(payment) as tot_p,
            ROW_NUMBER() OVER(PARTITION BY branch_city ORDER BY COUNT(payment) DESC) AS row_n
            FROM df_sales
            GROUP BY branch_city, payment
    )

    SELECT bc.branch_city,
        bc.total_units_sold,
        CAST(bc.total_profit AS INT) AS total_profit,
        CAST(bc.total_revenue AS INT) AS total_revenue, 
        CAST(bc.avg_profit AS INT) AS avg_profit_dollars,
        CAST(bc.avg_rating AS INT) AS avg_rating,
        pm.payment,
        bc.females,
        bc.males
    FROM branch_comparison bc
    INNER JOIN payment_methods pm 
    ON bc.branch_city = pm.branch_city
    WHERE pm.row_n = 1
    ORDER BY 
        total_revenue DESC,
        avg_profit_dollars DESC,  
        total_units_sold DESC


-- Gender-Based Distribution of Payment Methods

    SELECT *,
        SUM(payment_method_count) OVER(PARTITION BY payment ORDER BY payment, payment_method_count ROWS UNBOUNDED PRECEDING) AS running_total,
        ROUND(
            (SUM(payment_method_count) OVER(ORDER BY payment, payment_method_count ROWS UNBOUNDED PRECEDING)
             / CAST(SUM(payment_method_count) OVER() AS FLOAT)) * 100 
        , 0) AS running_total_percentage
    FROM (
        SELECT payment,
            gender,
            COUNT(*) AS payment_method_count
        FROM df_sales
        GROUP BY payment, gender
    ) AS tot


-- Gender-Based Metrics Comparison
    -- Total Revenue
    -- Average Amount Spent
    -- Quantity Sold
    -- Average Quantity Bought per Visit
    -- Average Store Visit Time
    -- Average Customer Rating
    -- Number of Members vs. Non-Members

    SELECT  gender,
            SUM(cogs) AS total_revenue,
            CAST(ROUND(AVG(cogs), 0) AS INT) AS avg_spent_per_customer,
            SUM(quantity) AS total_qty,
            AVG(quantity) AS avg_qty,
            AVG(hour_24) AS avg_hour_at_store,
            CAST(ROUND(AVG(rating), 0) AS INT) AS avg_rating,
            SUM(CASE WHEN customer_type = 'Member' THEN 1 ELSE 0 END) AS Members,
            SUM(CASE WHEN customer_type = 'Normal' THEN 1 ELSE 0 END) AS NonMembers
    FROM df_sales
    GROUP BY gender
    ORDER BY SUM(cogs) DESC


