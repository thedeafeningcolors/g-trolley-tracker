-- Resume metrics for the G Trolley Tracker. Written 2026-09-04.
-- Run in the Supabase SQL Editor. Highlight ONE query at a time and press Run
-- (the editor only shows the last result when you run the whole file).
--
-- How the site measures visits (netlify/functions/log-visit.js + app.js):
--   * one row per browser tab session (a refresh does not add a row), so "sessions" = visits
--   * visitor_id is a random id saved in the browser, so "unique visitors" = unique browsers
--   * tracking began 2026-01-19; the iPhone app has never logged here (Apple reports its own numbers)
--   * no clicks or taps are tracked, only the visit itself, the time, and phone vs desktop
--
-- To leave your own visits out: on the live site open the browser console, run
--   localStorage.getItem('visitor_id')
-- and add   AND visitor_id <> 'paste-it-here'   to the WHERE clauses below.

-- ============================================================
-- Query 1: Headline scorecard. One table, every headline number.
-- ============================================================
WITH v AS (
    SELECT visitor_id, visited_at, is_mobile,
           (visited_at AT TIME ZONE 'America/New_York')::date AS d
    FROM page_views
),
per_visitor AS (
    SELECT visitor_id, COUNT(*) AS sessions, MIN(d) AS first_day, MAX(d) AS last_day
    FROM v
    WHERE visitor_id IS NOT NULL
    GROUP BY visitor_id
)
SELECT 1 AS ord, 'Total visits, all time' AS metric, COUNT(*)::text AS value FROM v
UNION ALL SELECT 2,  'Unique visitors, all time', COUNT(*)::text FROM per_visitor
UNION ALL SELECT 3,  'Visits, last 30 days', COUNT(*)::text FROM v WHERE visited_at >= now() - interval '30 days'
UNION ALL SELECT 4,  'Unique visitors, last 30 days', COUNT(DISTINCT visitor_id)::text FROM v WHERE visited_at >= now() - interval '30 days'
UNION ALL SELECT 5,  'Average visits per day, last 30 days', ROUND(COUNT(*) / 30.0, 1)::text FROM v WHERE visited_at >= now() - interval '30 days'
UNION ALL SELECT 6,  'Returning visitors (2+ visits)', COUNT(*) FILTER (WHERE sessions >= 2)::text FROM per_visitor
UNION ALL SELECT 7,  'Returning visitor share (%)', ROUND(100.0 * COUNT(*) FILTER (WHERE sessions >= 2) / NULLIF(COUNT(*), 0), 1)::text FROM per_visitor
UNION ALL SELECT 8,  'Visitors who came back on a later day', COUNT(*) FILTER (WHERE last_day > first_day)::text FROM per_visitor
UNION ALL SELECT 9,  'Regulars (10+ visits)', COUNT(*) FILTER (WHERE sessions >= 10)::text FROM per_visitor
UNION ALL SELECT 10, 'Visits from phones (%)', ROUND(100.0 * COUNT(*) FILTER (WHERE is_mobile) / NULLIF(COUNT(*), 0), 1)::text FROM v
UNION ALL SELECT 11, 'Busiest single day', (SELECT d::text || ' (' || COUNT(*) || ' visits)' FROM v GROUP BY d ORDER BY COUNT(*) DESC LIMIT 1)
UNION ALL SELECT 12, 'Days with at least one visit', COUNT(DISTINCT d)::text FROM v
UNION ALL SELECT 13, 'First recorded visit', MIN(d)::text FROM v
UNION ALL SELECT 14, 'Days of tracking so far', (CURRENT_DATE - MIN(d))::text FROM v
ORDER BY ord;

-- ============================================================
-- Query 2: Month-by-month growth. New vs returning visitors each month.
-- ============================================================
WITH v AS (
    SELECT visitor_id,
           date_trunc('month', visited_at AT TIME ZONE 'America/New_York') AS m
    FROM page_views
    WHERE visitor_id IS NOT NULL
),
first_m AS (
    SELECT visitor_id, MIN(m) AS first_month FROM v GROUP BY visitor_id
)
SELECT to_char(v.m, 'YYYY-MM')                                                AS month,
       COUNT(*)                                                               AS visits,
       COUNT(DISTINCT v.visitor_id)                                           AS unique_visitors,
       COUNT(DISTINCT v.visitor_id) FILTER (WHERE f.first_month = v.m)        AS new_visitors,
       COUNT(DISTINCT v.visitor_id) FILTER (WHERE f.first_month < v.m)        AS returning_visitors
FROM v
JOIN first_m f USING (visitor_id)
GROUP BY v.m
ORDER BY v.m;

-- ============================================================
-- Query 3: Stickiness. How many visits each visitor makes.
-- ============================================================
WITH per_visitor AS (
    SELECT visitor_id, COUNT(*) AS sessions
    FROM page_views
    WHERE visitor_id IS NOT NULL
    GROUP BY visitor_id
)
SELECT CASE WHEN sessions = 1              THEN '1 visit'
            WHEN sessions BETWEEN 2 AND 4  THEN '2 to 4 visits'
            WHEN sessions BETWEEN 5 AND 9  THEN '5 to 9 visits'
            WHEN sessions BETWEEN 10 AND 24 THEN '10 to 24 visits'
            ELSE '25+ visits' END                                             AS bucket,
       COUNT(*)                                                               AS visitors,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                     AS pct_of_visitors,
       SUM(sessions)                                                          AS visits,
       ROUND(100.0 * SUM(sessions) / SUM(SUM(sessions)) OVER (), 1)           AS pct_of_visits
FROM per_visitor
GROUP BY 1
ORDER BY MIN(sessions);

-- ============================================================
-- Query 4: When riders check. Weekday pattern, Eastern time.
-- (Swap 'Dy' and ISODOW for 'HH24' and HOUR to get the hour-of-day version.)
-- ============================================================
SELECT to_char(visited_at AT TIME ZONE 'America/New_York', 'Dy')             AS weekday,
       COUNT(*)                                                               AS visits,
       ROUND(COUNT(*)::numeric
             / COUNT(DISTINCT (visited_at AT TIME ZONE 'America/New_York')::date), 1)
                                                                              AS visits_per_day
FROM page_views
GROUP BY 1, EXTRACT(ISODOW FROM visited_at AT TIME ZONE 'America/New_York')
ORDER BY EXTRACT(ISODOW FROM visited_at AT TIME ZONE 'America/New_York');

-- ============================================================
-- Query 5: Demand follows service. Visits on trolley days vs bus-only days.
-- Uses the daily_trolley_share view (data from Feb 2026 on).
-- ============================================================
WITH daily AS (
    SELECT (visited_at AT TIME ZONE 'America/New_York')::date AS d,
           COUNT(*)                    AS visits,
           COUNT(DISTINCT visitor_id)  AS visitors
    FROM page_views
    GROUP BY 1
)
SELECT CASE WHEN s.is_true_trolley_day THEN 'Trolley day (PCCs ran most of the day)'
            WHEN s.pcc_samples > 0     THEN 'Partial trolley day'
            ELSE                            'Bus-only day' END                 AS day_type,
       COUNT(*)                                                               AS days,
       ROUND(AVG(COALESCE(d.visits, 0)), 1)                                   AS avg_visits_per_day,
       ROUND(AVG(COALESCE(d.visitors, 0)), 1)                                 AS avg_visitors_per_day
FROM daily_trolley_share s
LEFT JOIN daily d ON d.d = s.service_date
WHERE s.service_date >= '2026-02-01'
  AND s.service_date < CURRENT_DATE
GROUP BY 1
ORDER BY 3 DESC;

-- ============================================================
-- Query 6: The paid iPhone app and the data pipeline behind both.
-- ============================================================
SELECT 1 AS ord, 'iPhone app: phones opted in to trolley alerts' AS metric, COUNT(*)::text AS value FROM push_subscriptions WHERE enabled
UNION ALL SELECT 2,  'iPhone app: saved stop alerts', COUNT(*)::text FROM push_stop_alerts WHERE enabled
UNION ALL SELECT 3,  'iPhone app: daily trolley alerts sent', COUNT(*)::text FROM push_alerts_sent
UNION ALL SELECT 4,  'iPhone app: phone notifications delivered', COALESCE(SUM(recipients), 0)::text FROM push_alerts_sent
UNION ALL SELECT 5,  'iPhone app: stop alerts delivered', COUNT(*)::text FROM push_stop_alerts_sent
UNION ALL SELECT 6,  'Tracker: 5-minute service samples collected', COUNT(*)::text FROM pcc_samples
UNION ALL SELECT 7,  'Tracker: individual vehicle observations', COUNT(*)::text FROM pcc_observations
UNION ALL SELECT 8,  'Tracker: days of continuous collection', COUNT(DISTINCT (sampled_at AT TIME ZONE 'America/New_York')::date)::text FROM pcc_samples
UNION ALL SELECT 9,  'Tracker: first sample', MIN(sampled_at AT TIME ZONE 'America/New_York')::date::text FROM pcc_samples
UNION ALL SELECT 10, 'Tracker: distinct PCC cars seen', COUNT(*)::text FROM vehicle_alltime_stats
UNION ALL SELECT 11, 'Tracker: PCC trips logged', COALESCE(SUM(total_trips), 0)::text FROM vehicle_alltime_stats
ORDER BY ord;
