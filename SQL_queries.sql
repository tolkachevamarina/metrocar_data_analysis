/*
==================================================================================================
This section contains SQL queries used to calculate key business metrics
and analyze the customer journey within the ride-sharing platform.
==================================================================================================
*/  


/* 
--------------------------------------------------------------------------------------------------
Ride Funnel Analysis
--------------------
This query builds a ride funnel from the initial request to leaving a review. 
It helps identify conversion rates and potential drop-off points throughout the customer journey.
-------------------------------------------------------------------------------------------------- 
*/

WITH rides_table AS (
    SELECT
        rr.ride_id,
        request_ts,
        accept_ts,
        pickup_ts,
        dropoff_ts,
        cancel_ts,
        purchase_amount_usd,
        charge_status,
        rating
    FROM public.ride_requests rr
    LEFT JOIN public.transactions t
        ON rr.ride_id = t.ride_id
    LEFT JOIN public.signups s
        ON rr.user_id = s.user_id
    LEFT JOIN public.app_downloads ad
        ON s.session_id = ad.app_download_key
    LEFT JOIN public.reviews r
        ON rr.ride_id = r.ride_id
)

SELECT 'Request' AS funnel_stage,
       COUNT(request_ts) AS rides
FROM rides_table
WHERE request_ts IS NOT NULL

UNION ALL

SELECT 'Accepted',
       COUNT(accept_ts)
FROM rides_table
WHERE accept_ts IS NOT NULL

UNION ALL

SELECT 'Completed',
       COUNT(pickup_ts)
FROM rides_table
WHERE pickup_ts IS NOT NULL

UNION ALL

SELECT 'Payment',
       COUNT(purchase_amount_usd)
FROM rides_table
WHERE charge_status = 'Approved'

UNION ALL

SELECT 'Review',
       COUNT(rating)
FROM rides_table;


/* 
--------------------------------------------------------------------------------------------------
Average Driver Acceptance Time
------------------------------
This query calculates the average time (in minutes) between a ride request and driver acceptance.
-------------------------------------------------------------------------------------------------- 
*/

WITH diff_table AS (
    SELECT
        ride_id,
        request_ts,
        accept_ts,
        EXTRACT(EPOCH FROM (accept_ts - request_ts)) / 60 AS minutes_diff
    FROM public.ride_requests
)

SELECT
    ROUND(AVG(minutes_diff), 2) AS avg_wait_time
FROM diff_table
WHERE minutes_diff IS NOT NULL;


/* 
--------------------------------------------------------------------------------------------------
Average Driver Pickup Time
--------------------------
This query calculates the average waiting time (in minutes) between a driver accepting a ride
request and arriving at the pickup location.
-------------------------------------------------------------------------------------------------- 
*/


WITH diff_table AS (
    SELECT
        ride_id,
        accept_ts,
        pickup_ts,
        EXTRACT(EPOCH FROM (pickup_ts - accept_ts)) / 60 AS minutes_diff
    FROM public.ride_requests
)

SELECT
    ROUND(AVG(minutes_diff), 2) AS avg_wait_time
FROM diff_table
WHERE minutes_diff IS NOT NULL;


/* 
--------------------------------------------------------------------------------------------------
Average Completed Rides per User
--------------------------------
This metric calculates the average number of successfully completed rides per user. 
Only rides that were not canceled (`cancel_ts IS NULL`) are included in the calculation.
-------------------------------------------------------------------------------------------------- 
*/

WITH nmb_table AS (
    SELECT
        user_id,
        COUNT(*) AS nmb_of_rides
    FROM public.ride_requests
    WHERE cancel_ts IS NULL
    GROUP BY user_id
)

SELECT
    ROUND(AVG(nmb_of_rides), 2) AS avg_nmb_rides_by_user
FROM nmb_table;


/* 
--------------------------------------------------------------------------------------------------
Distribution of Ratings
-----------------------
This query shows the number of reviews for each rating value, helping to understand the overall 
distribution of customer satisfaction scores.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    rating,
    COUNT(*) AS nmb_of_ratings
FROM public.reviews
GROUP BY rating
ORDER BY nmb_of_ratings DESC;


/* 
--------------------------------------------------------------------------------------------------
User Funnel
-----------
This query shows the number of users at each stage of the funnel, helping to understand user 
progression and identify potential drop-off points.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    funnel_name,
    SUM(number_of_users) AS users
FROM public.funnel_analysis
GROUP BY funnel_name
ORDER BY users DESC;


/* 
--------------------------------------------------------------------------------------------------
Revenue by Hour
---------------
This query calculates total revenue generated in each hour of the day based on approved 
transactions, helping to identify peak earning periods.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    EXTRACT(HOUR FROM request_ts) AS hour,
    SUM(purchase_amount_usd) AS total_amount
FROM public.ride_requests rr
JOIN public.transactions tr
    ON rr.ride_id = tr.ride_id
WHERE charge_status = 'Approved'
GROUP BY hour
ORDER BY total_amount DESC;


/* 
--------------------------------------------------------------------------------------------------
Revenue by Day of Week
----------------------
This query calculates total revenue for each day of the week based on approved transactions, 
helping to identify which days generate the highest income.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    EXTRACT(ISODOW FROM request_ts) AS weekday,
    SUM(purchase_amount_usd) AS total_amount
FROM public.ride_requests rr
JOIN public.transactions tr
    ON rr.ride_id = tr.ride_id
WHERE charge_status = 'Approved'
GROUP BY weekday
ORDER BY total_amount DESC;


/* 
--------------------------------------------------------------------------------------------------
Number of Users by Age Group and Platform
------------------------------------------
This query shows how users are distributed across different age ranges and platforms, 
helping to understand audience composition and platform preference.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    age_range,
    platform,
    COUNT(*) AS nmb_of_users
FROM public.signups s
JOIN app_downloads ad
    ON s.session_id = ad.app_download_key
GROUP BY age_range, platform
ORDER BY nmb_of_users DESC;


/* 
--------------------------------------------------------------------------------------------------
Revenue by Platform
-------------------
This query calculates total revenue generated by each platform, helping to identify which 
platform drives the most value.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    SUM(purchase_amount_usd) AS total_amount,
    platform
FROM public.ride_requests rr
LEFT JOIN public.transactions t
    ON rr.ride_id = t.ride_id
LEFT JOIN public.signups s
    ON rr.user_id = s.user_id
LEFT JOIN public.app_downloads ad
    ON s.session_id = ad.app_download_key
WHERE charge_status = 'Approved'
GROUP BY platform
ORDER BY total_amount DESC;


/* 
--------------------------------------------------------------------------------------------------
Completed vs Canceled Rides
---------------------------
This query compares the number of completed rides versus canceled rides, providing an 
overview of overall ride success rate.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    COUNT(rr.ride_id) AS nmb_request_rides,
    SUM(CASE WHEN request_ts IS NOT NULL AND cancel_ts IS NULL THEN 1 END) AS successful_rides,
    SUM(CASE WHEN cancel_ts IS NOT NULL THEN 1 END) AS cancel_rides
FROM public.ride_requests rr
LEFT JOIN public.transactions t
    ON rr.ride_id = t.ride_id
LEFT JOIN public.signups s
    ON rr.user_id = s.user_id
LEFT JOIN public.app_downloads ad
    ON s.session_id = ad.app_download_key;


/* 
--------------------------------------------------------------------------------------------------
Ride Requests vs Cancellations by Hour
--------------------------------------
This query analyzes how ride requests and cancellations are distributed across different hours 
of the day, helping to identify peak activity and cancellation patterns.
-------------------------------------------------------------------------------------------------- 
*/

SELECT
    EXTRACT(HOUR FROM request_ts) AS hour,
    COUNT(*) AS nmb_request,
    COUNT(CASE WHEN cancel_ts IS NOT NULL THEN 1 END) AS nmb_canceled
FROM public.ride_requests rr
LEFT JOIN public.transactions t
    ON rr.ride_id = t.ride_id
LEFT JOIN public.signups s
    ON rr.user_id = s.user_id
LEFT JOIN public.app_downloads ad
    ON s.session_id = ad.app_download_key
GROUP BY hour
ORDER BY hour;
