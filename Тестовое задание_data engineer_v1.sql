---  1.	Вывести средний чек в динамике (год–месяц) по магазинам
WITH prepare AS (
    SELECT с.Id,
            c.shopId, 
            c.salesRub, 
            YEAR(c.[date]) as Y, 
            MONTH(c.[date]) as M 
                FROM demodata.[check] as c
)
SELECT p.shopId AS 'ИД магазина',
        p.Id AS 'Чек',
        s.nameShop AS 'Магазин',
        ROUND(AVG(salesRub), 2) AS 'Средний чек', 
        CONCAT(Y, '-', M) AS 'Год-Месяц' 
            FROM prepare p
            
            JOIN demodata.shop s
            ON s.shopId = p.shopId

GROUP BY p.Id, s.nameShop, p.shopId, Y, M

ORDER BY s.nameShop, p.shopId, p.Id, Y,M
;


--- 2.	Вывести средний чек в динамике (год-месяц) по форматам (поле format)
WITH prepare AS (
    SELECT с.Id, 
            c.salesRub, 
            YEAR(c.[date]) as Y, 
            MONTH(c.[date]) as M, 
            ws.[format] 
                FROM demodata.[check] as c
                
                JOIN demodata.workSchedule ws
                ON ws.shopId = c.shopId    
)
SELECT p.format AS 'Формат', 
        p.Id AS 'Чек',             
        AVG(salesRub) AS 'Средняя стоимость', 
        CONCAT(Y, '-', M) AS 'Год-Месяц' 
            FROM prepare p

GROUP BY p.Id, p.format, Y, M

ORDER BY p.format, p.Id, Y,M
;


--- 3.	Рассчитать долю в продажах промо акций в динамике (год-месяц) (использовать promoShop и promo)
WITH promo_sku AS (
    SELECT c.sales, 
            YEAR(c.date) as Y, 
            MONTH(c.date) as M 
                FROM demodata.promo AS promo
                
                JOIN demodata.promoShop ps
                ON ps.promoId = promo.promoId

                JOIN [demodata].[shop] s
                ON s.storeId = ps.storeId

                JOIN demodata.[check] c
                ON c.shopId = s.shopId
                AND promo.skuId = c.skuId
    
    WHERE c.date BETWEEN promo.startDate AND promo.finishDate
), 
    sum_promo_sku AS (
        SELECT SUM(sales) sum_promo, 
                Y, 
                M 
                    FROM promo_sku
        
        GROUP BY Y,M
), 
    full_sales AS (
        SELECT ch.sales, 
                YEAR(ch.date) as Y, 
                MONTH(ch.date) as M 
                    FROM demodata.[check] ch
), 
    sum_full_sales AS (
        SELECT SUM(sales) sum_fp, 
                Y, 
                M 
                    FROM full_sales
        
        GROUP BY Y,M
), 
    calculate AS(
        SELECT  sps.Y, 
                sps.M, 
                sps.sum_promo / sfs.sum_fp * 100 as share
                    FROM sum_promo_sku sps
                    
                    JOIN sum_full_sales sfs
                    ON sps.Y = sfs.Y AND sps.M = sfs.M
)

SELECT CONCAT(Y, '-', M) AS 'Год-Месяц', 
        ROUND(share, 2) AS 'Доля, %' 
            FROM calculate
    
ORDER BY Y, M
;


--- 4.	Выровнять стоки (сейчас, если остатков нет, то ноль не пишется в БД, а нужно писать. Например 01.01.2021 – 10 02.01.2021 – 0 03.01.2021-10
WITH 
    UNIQ_skuId AS(
        SELECT DISTINCT skuId FROM demodata.stock s
),
   UNIQ_shopId AS (
        SELECT DISTINCT shopId FROM demodata.stock s
), 
    UNIQ_date AS (
        SELECT DISTINCT date FROM demodata.stock s
),  all_data AS (
        SELECT * FROM UNIQ_skuId us, UNIQ_shopId ush, UNIQ_date ud
)
SELECT ad.skuId, 
        ad.shopId, 
        ISNULL(s.stock, 0) as [stock], 
        ad.[date] 
            FROM all_data ad
            
            LEFT JOIN demodata.stock s 
            ON s.skuId = ad.skuId 
            AND s.[date] = ad.[date] 
            AND s.shopId = ad.shopId
;

--- 5.	Рассчитать динамику продаж (год-месяц) по level2 (Prod)
WITH prepare AS (
    SELECT p.id2, 
            c.skuId, 
            c.sales, 
            c.salesRub, 
            YEAR(date) as Y, 
            MONTH(date) as M 
                FROM demodata.[check] as c
                
                JOIN demodata.prod p
                ON p.skuId = c.skuId
),
    UNIQ_shopId AS (
        SELECT DISTINCT id2, 
                level2 
                    FROM demodata.prod
)
SELECT ush.level2, 
        ROUND(SUM(sales), 2) AS 'Кол-во продано', 
        ROUND(SUM(salesRub), 2) AS 'Сумма', 
        CONCAT(Y, '-', M) AS 'Год-Месяц' 
            FROM prepare p
                JOIN UNIQ_shopId ush 
                ON ush.id2 = p.id2

GROUP BY ush.level2, Y, M

ORDER BY ush.level2, Y, M
;


--- 6.	Выяснить долю остатков вне ассортиментной матрицы (AssortRetail – покажет какие товары в ассортименте, а какие нет)
WITH out_assort AS (
    SELECT SUM(st.stock) AS sum_out_stock, 
            st.shopId, 
            st.[date] 
                FROM demodata.assortRetail ar
                    
                    JOIN demodata.stock st
                    ON st.skuId = ar.skuId

                    JOIN demodata.shop sh
                    ON sh.shopId = st.shopId
                    AND sh.storeId = ar.storeId
    
    WHERE ar.[status] <> 1
    OR st.[date] NOT BETWEEN ar.startDate and ar.finishDate
    
    GROUP BY st.shopId, st.[date]
), 
    all_assort AS (
        SELECT SUM(st.stock) AS sum_all_stock, 
            st.shopId, 
            st.[date] 
                FROM demodata.assortRetail ar
                    JOIN demodata.stock st
                    ON st.skuId = ar.skuId

                    JOIN demodata.shop sh
                    ON sh.shopId = st.shopId
                    AND sh.storeId = ar.storeId

        GROUP BY st.shopId, st.[date]
)
SELECT aa.shopId AS 'ИД магазина', 
        s.nameShop AS 'Магазин',
        aa.[date] AS 'Дата', 
        ROUND(oa.sum_out_stock / aa.sum_all_stock * 100, 2) AS 'Доля, %' 
            FROM all_assort aa
    
            JOIN out_assort oa
            ON aa.[date] = oa.[date]
            AND aa.shopId = oa.shopId

            JOIN demodata.shop s
            ON s.shopId = aa.shopId

ORDER BY [Дата], [ИД магазина]
;
