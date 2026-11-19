-- =====================================================================
-- Hive analytics on the AI Stream Index 2026 dataset
-- 02_dml.hql : load, transform and analyse (run after 01_ddl.hql)
-- =====================================================================

-- Session settings (re-run after every reconnect)
USE ai_stream_db;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.execution.engine=mr;
SET mapreduce.framework.name=local;

-- ---------------------------------------------------------------------
-- DML 1 : Load the local CSV file into the staging table
-- (change the path to wherever the cleaned file is in your VM)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INPATH '/path/to/ai_stream_index_2026.csv'
OVERWRITE INTO TABLE ai_stream_raw;

SELECT * FROM ai_stream_raw LIMIT 5;
SELECT COUNT(*) AS total_rows FROM ai_stream_raw;   -- 10001: header row still counted

-- ---------------------------------------------------------------------
-- DML 2 : Populate the partitioned ORC table (dynamic partitioning)
-- Column order must match the table; partition column goes LAST.
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE ai_stream_part PARTITION (platform)
SELECT
  user_id, subs_tier, ai_feature_used, user_mood_pre_watch,
  device_type, content_type, region, data_priv_settings,
  engagement_score, daily_view_time_min, churn_risk_prob,
  monthly_subs_cost, ai_feature_satisfaction,
  content_items_watched, weekly_sessions,
  CASE
    WHEN engagement_score >= 70 THEN 'High'
    WHEN engagement_score >= 40 THEN 'Medium'
    ELSE 'Low'
  END AS engagement_band,
  platform
FROM ai_stream_raw
WHERE user_id <> 'User_ID';   -- drop CSV header row (skip.header.line.count was not applied)

SHOW PARTITIONS ai_stream_part;                       -- 6 partitions
SELECT COUNT(*) AS total_rows FROM ai_stream_part;    -- 10000

-- ---------------------------------------------------------------------
-- DML 3 : Platform overview - users, engagement, churn, cost
-- ---------------------------------------------------------------------
SELECT platform,
       COUNT(*)                                   AS users,
       ROUND(AVG(engagement_score), 2)            AS avg_engagement,
       ROUND(AVG(daily_view_time_min), 1)      AS avg_daily_minutes,
       ROUND(AVG(churn_risk_prob), 4)      AS avg_churn_risk,
       ROUND(AVG(monthly_subs_cost), 2)   AS avg_cost_usd
FROM ai_stream_part
GROUP BY platform
ORDER BY avg_churn_risk DESC;

-- ---------------------------------------------------------------------
-- DML 4 : Which AI feature gives the highest satisfaction?
-- ---------------------------------------------------------------------
SELECT ai_feature_used,
       COUNT(*)                                  AS users,
       ROUND(AVG(ai_feature_satisfaction), 2)    AS avg_satisfaction,
       ROUND(AVG(engagement_score), 2)           AS avg_engagement,
       ROUND(AVG(churn_risk_prob), 4)     AS avg_churn_risk
FROM ai_stream_part
GROUP BY ai_feature_used
ORDER BY avg_satisfaction DESC;

-- ---------------------------------------------------------------------
-- DML 5 : Subscription tier - revenue and behaviour
-- ---------------------------------------------------------------------
SELECT subs_tier,
       COUNT(*)                                    AS users,
       ROUND(SUM(monthly_subs_cost), 2)    AS total_monthly_revenue_usd,
       ROUND(AVG(monthly_subs_cost), 2)    AS avg_cost_usd,
       ROUND(AVG(weekly_sessions), 2)              AS avg_weekly_sessions,
       ROUND(AVG(churn_risk_prob), 4)       AS avg_churn_risk
FROM ai_stream_part
GROUP BY subs_tier
ORDER BY total_monthly_revenue_usd DESC;

-- ---------------------------------------------------------------------
-- DML 6 : Top content type per region and its share of items watched
--         (window functions: SUM() OVER and ROW_NUMBER() OVER)
-- ---------------------------------------------------------------------
SELECT region, content_type, total_items, users, pct_of_region
FROM (
  SELECT region, content_type, total_items, users,
         ROUND(100.0 * total_items / SUM(total_items) OVER (PARTITION BY region), 2) AS pct_of_region,
         ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_items DESC)          AS rn
  FROM (
    SELECT region, content_type,
           SUM(content_items_watched) AS total_items,
           COUNT(*)                   AS users
    FROM ai_stream_part
    GROUP BY region, content_type
  ) a
) t
WHERE rn = 1
ORDER BY total_items DESC;

-- ---------------------------------------------------------------------
-- DML 7 : Mood before watching vs viewing time (HAVING filter)
-- ---------------------------------------------------------------------
SELECT user_mood_pre_watch,
       COUNT(*)                                AS users,
       ROUND(AVG(daily_view_time_min), 1)   AS avg_daily_minutes,
       ROUND(AVG(engagement_score), 2)         AS avg_engagement
FROM ai_stream_part
GROUP BY user_mood_pre_watch
HAVING COUNT(*) > 100
ORDER BY avg_daily_minutes DESC;

-- ---------------------------------------------------------------------
-- DML 8 : Engagement band distribution per device (pivot with CASE)
-- ---------------------------------------------------------------------
SELECT device_type,
       SUM(CASE WHEN engagement_band = 'High'   THEN 1 ELSE 0 END) AS high_engaged,
       SUM(CASE WHEN engagement_band = 'Medium' THEN 1 ELSE 0 END) AS medium_engaged,
       SUM(CASE WHEN engagement_band = 'Low'    THEN 1 ELSE 0 END) AS low_engaged,
       ROUND(100.0 * SUM(CASE WHEN engagement_band = 'High' THEN 1 ELSE 0 END)
             / COUNT(*), 2)                                         AS pct_high
FROM ai_stream_part
GROUP BY device_type
ORDER BY pct_high DESC;

-- ---------------------------------------------------------------------
-- DML 9 : High-churn share by privacy setting (view JOIN totals)
-- ---------------------------------------------------------------------
SELECT t.data_priv_settings,
       t.total_users,
       COALESCE(h.high_churn_users, 0)                         AS high_churn_users,
       ROUND(100.0 * COALESCE(h.high_churn_users, 0)
             / t.total_users, 2)                               AS pct_high_churn
FROM (SELECT data_priv_settings, COUNT(*) AS total_users
      FROM ai_stream_part GROUP BY data_priv_settings) t
LEFT JOIN
     (SELECT data_priv_settings, COUNT(*) AS high_churn_users
      FROM v_high_churn GROUP BY data_priv_settings) h
  ON t.data_priv_settings = h.data_priv_settings
ORDER BY pct_high_churn DESC;

-- ---------------------------------------------------------------------
-- DML 10 : Correlation between usage metrics and churn, per platform
-- ---------------------------------------------------------------------
SELECT platform,
       ROUND(CORR(engagement_score, churn_risk_prob), 4)        AS corr_engagement_churn,
       ROUND(CORR(ai_feature_satisfaction, churn_risk_prob), 4) AS corr_satisfaction_churn,
       ROUND(CORR(daily_view_time_min, engagement_score), 4)        AS corr_viewtime_engagement
FROM ai_stream_part
GROUP BY platform
ORDER BY platform;
