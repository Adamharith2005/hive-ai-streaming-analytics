-- =====================================================================
-- Hive analytics on the AI Stream Index 2026 dataset
-- 01_ddl.hql : database, tables and view (run first)
-- Tested on Hadoop 3.5.0 + Hive 4.0.0 (Beeline), Java 17
-- =====================================================================

-- ---------------------------------------------------------------------
-- DDL 1 : Create and select the database
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ai_stream_db
COMMENT 'AI Stream Index 2026 - AI features on streaming platforms';
USE ai_stream_db;
SHOW DATABASES;

-- ---------------------------------------------------------------------
-- DDL 2 : Staging table (plain text, matches the CSV, skips header row)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_stream_raw (
  user_id                     STRING,
  platform                    STRING,
  subs_tier           STRING,
  ai_feature_used             STRING,
  user_mood_pre_watch         STRING,
  device_type                 STRING,
  content_type                STRING,
  region                      STRING,
  data_priv_settings        STRING,
  engagement_score            INT,
  daily_view_time_min      INT,
  churn_risk_prob      DOUBLE,
  monthly_subs_cost   DOUBLE,
  ai_feature_satisfaction     DOUBLE,
  content_items_watched       INT,
  weekly_sessions             INT
)
COMMENT 'Raw staging table loaded from CSV'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');
DESCRIBE ai_stream_raw;

-- ---------------------------------------------------------------------
-- DDL 3 : Optimised table - ORC format, partitioned by platform
-- (partition column is NOT listed among the normal columns)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_stream_part (
  user_id                     STRING,
  subs_tier           STRING,
  ai_feature_used             STRING,
  user_mood_pre_watch         STRING,
  device_type                 STRING,
  content_type                STRING,
  region                      STRING,
  data_priv_settings        STRING,
  engagement_score            INT,
  daily_view_time_min      INT,
  churn_risk_prob      DOUBLE,
  monthly_subs_cost   DOUBLE,
  ai_feature_satisfaction     DOUBLE,
  content_items_watched       INT,
  weekly_sessions             INT
)
COMMENT 'ORC copy of the data, partitioned by streaming platform'
PARTITIONED BY (platform STRING)
STORED AS ORC;

-- ---------------------------------------------------------------------
-- DDL 4 : ALTER - add a derived column for engagement band
-- ---------------------------------------------------------------------
ALTER TABLE ai_stream_part
ADD COLUMNS (engagement_band STRING COMMENT 'Low <40, Medium 40-69, High >=70');
DESCRIBE FORMATTED ai_stream_part;

-- ---------------------------------------------------------------------
-- DDL 5 : View of high churn-risk users (probability > 0.5)
-- ---------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_high_churn AS
SELECT user_id, platform, subs_tier, data_priv_settings,
       ai_feature_used, engagement_score, churn_risk_prob,
       monthly_subs_cost
FROM ai_stream_part
WHERE churn_risk_prob > 0.5;
SHOW TABLES;
