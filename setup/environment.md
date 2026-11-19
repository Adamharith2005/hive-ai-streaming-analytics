# Environment setup and troubleshooting

## Stack

| Component | Version |
|---|---|
| OS | Ubuntu (VirtualBox VM, 4 GB+ RAM recommended) |
| Java | OpenJDK 17 |
| Hadoop | 3.5.0, single-node (pseudo-distributed) |
| Hive | 4.0.0, Beeline in embedded mode, Derby metastore |
| Execution | MapReduce in local mode |

## Starting the environment

```bash
start-dfs.sh
start-yarn.sh
jps                                 # NameNode, DataNode, SecondaryNameNode, ResourceManager, NodeManager
hdfs dfsadmin -safemode leave

cd ~/hive                           # the folder that contains metastore_db
beeline -u jdbc:hive2://            # press Enter for username and password
```

Session settings, which must be re-applied after every reconnect:

```sql
USE ai_stream_db;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.execution.engine=mr;
SET mapreduce.framework.name=local;
```

---

## Troubleshooting log

### 1. `hive` opens Beeline with "No current connection"
In Hive 4 the old Hive CLI was removed, and `hive` starts Beeline. Beeline must be connected to a HiveServer2. In embedded mode:
```bash
beeline -u jdbc:hive2://
```
The Derby metastore lives in the folder where `schematool -initSchema` was run. Beeline must be started from that same folder, otherwise the tables seem to disappear.

### 2. `Error caching map.xml` (return code 1 from MapRedTask)
**Symptom:** simple `SELECT … LIMIT` queries worked, but anything that launched a MapReduce job (`COUNT(*)`, `GROUP BY`, `INSERT`) failed.

**Cause:** Hive serialises the query plan (`map.xml`) with Kryo, which uses reflection into JDK internals. Java 17's module system blocks that access.

**First attempt (failed):** install Java 8. HDFS then refused to start with
`UnsupportedClassVersionError … class file version 61.0`, because this Hadoop build was compiled for Java 17.

**Fix:** stay on Java 17 and open the required modules to Hive. Append to `~/hive/conf/hive-env.sh`:
```bash
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS \
 --add-opens=java.base/java.lang=ALL-UNNAMED \
 --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
 --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
 --add-opens=java.base/java.util=ALL-UNNAMED \
 --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
 --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
 --add-opens=java.base/java.util.regex=ALL-UNNAMED \
 --add-opens=java.base/java.net=ALL-UNNAMED \
 --add-opens=java.base/java.nio=ALL-UNNAMED \
 --add-opens=java.base/java.io=ALL-UNNAMED \
 --add-opens=java.base/java.text=ALL-UNNAMED \
 --add-opens=java.base/java.time=ALL-UNNAMED \
 --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
 --add-opens=java.sql/java.sql=ALL-UNNAMED"
```
Then run MapReduce in local mode (`SET mapreduce.framework.name=local;`), so the job runs inside the same JVM and inherits these flags.

### 3. Return code 2 from MapRedTask after many queries
The job compiled but crashed mid-run after several jobs in one long session. Restarting Beeline (a fresh JVM) and re-applying the `SET` options fixed it. If it shows `OutOfMemoryError`, start Beeline with `export HADOOP_HEAPSIZE=2048`.

### 4. `Invalid SessionHandle`
The embedded HiveServer2 session expired after the VM was left idle. `!quit`, reconnect and re-run the session settings. The tables and data are unaffected.

### 5. Last column loaded as NULL
The CSV had Windows `CRLF` line endings, so `\r` stuck to the last field and `INT` parsing failed. Fix before loading:
```bash
sed -i 's/\r$//' ai_stream_index_2026.csv
file ai_stream_index_2026.csv     # should no longer say "with CRLF line terminators"
```

### 6. 10,001 rows instead of 10,000
`TBLPROPERTIES ('skip.header.line.count'='1')` did not take effect, so the header row was read as data. It was removed during the ORC insert with:
```sql
WHERE user_id <> 'User_ID'
```

### 7. `ParseException … near '.' '.'`
Caused by copying a query back out of the terminal, which pastes Beeline's `. . . . . . . . >` continuation prompts into the SQL. Use the Up arrow to recall a query, or copy from the `.hql` files.
