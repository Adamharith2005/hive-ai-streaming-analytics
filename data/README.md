# Data

The dataset is not stored in this repository. Download it from Kaggle:

**AI-Stream Index 2026** by waddahali: <https://www.kaggle.com/datasets/waddahali/ai-stream-index-2026>

- File: `ai_stream_index_2026.csv`
- 10,000 rows × 16 columns, no missing values

## Columns

| Column (in Hive) | Type | Description | Values / range |
|---|---|---|---|
| `user_id` | STRING | Unique user identifier | USR-00001 to USR-10000 |
| `platform` | STRING | Streaming platform (partition key in `ai_stream_part`) | Netflix, YouTube, Prime Video, Disney+ AI, Apple TV+, TikTok |
| `subs_tier` | STRING | Subscription tier | Ad-Supported, Standard, Premium AI-Plus |
| `ai_feature_used` | STRING | Generative AI feature used | Personalized Story Ending, Mood-Based Playlist, Real-time Voice Dubbing, Virtual Background Sync, AI-Generated Summary |
| `user_mood_pre_watch` | STRING | Mood before the session | Happy, Energetic, Stressed, Anxious, Bored |
| `device_type` | STRING | Viewing device | AI-Integrated TV, Foldable Phone, Apple Vision Pro, Smart Glasses |
| `content_type` | STRING | Content category | Movies, Shorts, Education, Gaming |
| `region` | STRING | User region | North America, Europe, Asia Pacific, Latin America, Middle East & Africa |
| `data_priv_settings` | STRING | Data privacy level | Low, Medium, High |
| `engagement_score` | INT | Engagement level | 7–100 (mean 65.1) |
| `daily_view_time_min` | INT | Daily viewing time (minutes) | 5–277 (mean 117.5) |
| `churn_risk_prob` | DOUBLE | Modelled probability of churn | 0.0025–0.8637 (mean 0.27) |
| `monthly_subs_cost` | DOUBLE | Monthly cost (USD) | 0.00–34.99 (mean 12.92) |
| `ai_feature_satisfaction` | DOUBLE | Satisfaction with the AI feature | 1.0–10.0 (mean 6.98) |
| `content_items_watched` | INT | Content items watched | 1–81 (mean 13.7) |
| `weekly_sessions` | INT | Sessions per week | 1–12 (mean 4.0) |

## Preparing the file

The CSV uses Windows (CRLF) line endings. Strip them before loading, otherwise the last column loads as NULL:

```bash
sed -i 's/\r$//' ai_stream_index_2026.csv
wc -l ai_stream_index_2026.csv     # 10001 (header + 10,000 rows)
```

Then update the path in the `LOAD DATA LOCAL INPATH` statement in [`../sql/02_dml.hql`](../sql/02_dml.hql).
