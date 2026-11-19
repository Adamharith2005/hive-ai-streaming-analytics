# Generative AI in Streaming Platforms: Analytics with Apache Hive

HiveQL analysis of 10,000 streaming users, looking at how generative AI features relate to engagement, satisfaction, revenue and churn risk. Runs on single-node Hadoop.

## Key findings
- **Mood drives viewing time:** bored and stressed users watch about 165 min/day, almost twice as long as others (~88 min).
- **One AI feature stands out:** *Personalized Story Ending* has the highest satisfaction (7.27) and the lowest churn risk (0.22 vs ~0.28).
- **Premium AI-Plus** brings in ~54% of revenue from 25% of users.
- **Shorts** make up ~85% of items watched in every region.
- **Churn doesn't correlate with any single metric** (all \|r\| < 0.06).

*The dataset is synthetic, so these results demonstrate the method rather than real market behaviour.*

## Pipeline
```
CSV ──LOAD DATA──► ai_stream_raw (TEXTFILE)
                       │ INSERT OVERWRITE + dynamic partitions + CASE banding
                       ▼
                   ai_stream_part (ORC, partitioned by platform) - view + 10 analytical queries
```
**Techniques:** ORC, partitioning, `ALTER TABLE`, views, `HAVING`, window functions, `SUM(CASE …)` pivots, `LEFT JOIN`, `CORR()`.

## Repo
| Path | Contents |
|---|---|
| [`sql/`](sql/) | `01_ddl.hql` (tables, view) and `02_dml.hql` (load, ETL, analysis) |
| [`screenshots/`](screenshots/) | Beeline output for every query |
| [`data/`](data/README.md) | Dataset link, column descriptions, prep steps |
| [`setup/`](setup/environment.md) | Environment setup and troubleshooting log |

## Run
```bash
beeline -u jdbc:hive2:// -f sql/01_ddl.hql
beeline -u jdbc:hive2:// -f sql/02_dml.hql   # set the CSV path in LOAD DATA first
```

## Challenges solved
Fixed Hive 4 failing on Java 17 (`Error caching map.xml`) with `--add-opens` JVM flags, CRLF line endings turning the last column into NULLs and a header row that `skip.header.line.count` didn't remove.

**Dataset:** [AI-Stream Index 2026](https://www.kaggle.com/datasets/waddahali/ai-stream-index-2026) (Kaggle)
