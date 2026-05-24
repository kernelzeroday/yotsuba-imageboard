# YotsubaDB — DBAL API Reference

Custom database abstraction layer for MySQL/PostgreSQL dual-driver support.

## Connection

```php
// Singleton accessors (read config from constants defined in config_db.php)
$db = YotsubaDB::global();   // global connection (boardlist, bans, mod_users, etc.)
$db = YotsubaDB::board();    // board connection (per-board post tables)

// Manual connection
$db = YotsubaDB::connect('pgsql', 'localhost', 5432, 'user', 'pass', 'dbname');

// Inspect
$db->getDriver();  // 'mysql' or 'pgsql'
$db->getPdo();     // underlying PDO instance
$db->ping();       // true if connection alive
```

## Query Execution

```php
// Prepared statement with positional params
$res = $db->query("SELECT * FROM {$db->qi('posts')} WHERE no = ? AND board = ?", [123, 'g']);
$row = $res->fetch(PDO::FETCH_ASSOC);

// DDL or statements that don't return rows
$affected = $db->exec("TRUNCATE TABLE {$db->qi('cache')}");

// Last insert ID
$id = $db->lastInsertId();                     // MySQL: auto-detect
$id = $db->lastInsertIdForTable('posts', 'no'); // PG: uses {table}_{col}_seq
```

## Identifier Quoting

```php
$db->qi('tablename')           // MySQL: `tablename`, PG: "tablename"
$db->quoteIdentifier('int')    // same (qi is shorthand) — critical for reserved words
```

Board names like `int`, `out`, `test`, `all` are PostgreSQL reserved words. Always use `$db->qi()` for table/column names in queries.

## Table Locking

```php
$db->lockTable('posts', 'WRITE');  // MySQL: LOCK TABLES, PG: BEGIN + LOCK TABLE IN EXCLUSIVE MODE
// ... do work ...
$db->unlockTables();               // MySQL: UNLOCK TABLES, PG: COMMIT
$db->clearLocks();                 // force-release (rollback on PG)
```

Locking is reentrant-safe: nested `lockTable()` calls are no-ops.

## Transactions

```php
$db->beginTransaction();
$db->commit();
$db->rollBack();
```

## Query Builder

All builders return `[$sql, $params]` tuples — pass to `$db->query()`:

```php
// SELECT
[$sql, $params] = $db->buildSelect('posts', ['no', 'com'], ['resto' => 42], ['no' => 'ASC'], 10, 0);
$res = $db->query($sql, $params);

// INSERT
[$sql, $params] = $db->buildInsert('posts', ['com' => 'hello', 'name' => 'Anonymous']);
$db->query($sql, $params);

// UPDATE
[$sql, $params] = $db->buildUpdate('posts', ['com' => 'edited'], ['no' => 123]);
$db->query($sql, $params);

// DELETE
[$sql, $params] = $db->buildDelete('posts', ['no' => 123]);
$db->query($sql, $params);

// UPSERT (ON DUPLICATE KEY / ON CONFLICT)
[$sql, $params] = $db->buildUpsert(
    'md5',
    ['md5' => 'abc123', 'count' => 1],
    'md5',                              // conflict column(s)
    ['count' => 'EXCLUDED.count + 1']   // PG uses EXCLUDED, MySQL uses VALUES()
);
$db->query($sql, $params);
```

WHERE clauses support operators via key suffix:

```php
$db->buildSelect('posts', ['*'], [
    'no >='  => 100,
    'no <='  => 200,
    'board'  => 'g',
    'com LIKE' => '%test%',
]);
```

## Dialect Helpers

Generate driver-appropriate SQL expressions:

```php
$db->now()                              // NOW()
$db->dateInterval('NOW()', 3, 'DAY')    // MySQL: DATE_SUB(NOW(), INTERVAL 3 DAY)
                                        // PG: NOW() - INTERVAL '3 DAY'
$db->dateAdd('NOW()', 7, 'DAY')         // MySQL: DATE_ADD(...), PG: + INTERVAL
$db->unixTimestamp('created')           // MySQL: UNIX_TIMESTAMP(created)
                                        // PG: EXTRACT(EPOCH FROM created)::INTEGER
$db->fromUnixtime('1234567890')         // MySQL: FROM_UNIXTIME(...), PG: TO_TIMESTAMP(...)
$db->ifExpr('x > 0', "'yes'", "'no'")  // MySQL: IF(...), PG: CASE WHEN ... END
$db->groupConcat('board')              // MySQL: GROUP_CONCAT(board)
                                        // PG: STRING_AGG(board::TEXT, ',')
$db->groupConcatDistinct('board')       // with DISTINCT
$db->concat("'prefix_'", 'col')        // MySQL: CONCAT(...), PG: || operator
```

## SQL Translation Pipeline

The `translateSQL()` method (used automatically by the shim layer and by `query()`/`exec()` when driver=pgsql) applies these regex transformations:

| MySQL | PostgreSQL |
|-------|-----------|
| `` `name` `` | `"name"` |
| `HIGH_PRIORITY` / `SQL_CACHE` / `SQL_NO_CACHE` | stripped |
| `DATE_SUB(x, INTERVAL n UNIT)` | `(x - INTERVAL 'n UNIT')` |
| `DATE_ADD(x, INTERVAL n UNIT)` | `(x + INTERVAL 'n UNIT')` |
| `UNIX_TIMESTAMP(col)` | `EXTRACT(EPOCH FROM col)::INTEGER` |
| `FROM_UNIXTIME(n)` | `TO_TIMESTAMP(n)` |
| `IF(cond, a, b)` | `CASE WHEN cond THEN a ELSE b END` |
| `GROUP_CONCAT(expr)` | `STRING_AGG(expr::TEXT, ',')` |
| `GROUP_CONCAT(DISTINCT expr)` | `STRING_AGG(DISTINCT expr::TEXT, ',')` |
| `LIMIT offset, count` | `LIMIT count OFFSET offset` |
| `LOCK TABLES ... WRITE` | no-op (handled by `lockTable()`) |
| `UNLOCK TABLES` | no-op (handled by `unlockTables()`) |
| `SHOW TABLES LIKE 'x'` | `SELECT tablename FROM pg_tables ...` |
| `SET read_buffer_size=...` | silently skipped |

## Migration Pattern

Converting a legacy `mysql_*_call()` site to DBAL:

```php
// Before
$res = mysql_global_call("SELECT * FROM `banned_users` WHERE host='%s' AND active=1", $host);
$row = mysql_fetch_assoc($res);
$count = mysql_num_rows($res);

// After
$db = YotsubaDB::global();
$res = $db->query("SELECT * FROM {$db->qi('banned_users')} WHERE host = ? AND active = 1", [$host]);
$row = $res->fetch(PDO::FETCH_ASSOC);
$count = $res->rowCount();
```

| Legacy | DBAL |
|--------|------|
| `mysql_global_call($sql, ...)` | `YotsubaDB::global()->query($sql, [...])` |
| `mysql_board_call($sql, ...)` | `YotsubaDB::board()->query($sql, [...])` |
| `mysql_fetch_assoc($res)` | `$res->fetch(PDO::FETCH_ASSOC)` |
| `mysql_fetch_row($res)` | `$res->fetch(PDO::FETCH_NUM)` |
| `mysql_num_rows($res)` | `$res->rowCount()` |
| `mysql_free_result($res)` | `$res->closeCursor()` |
| `mysql_insert_id()` | `$db->lastInsertId()` |
| `mysql_board_lock($table)` | `$db->lockTable($table)` |
| `mysql_board_unlock()` | `$db->unlockTables()` |
| `mysql_real_escape_string($v)` | use `?` placeholder |
| `mysql_result($res, 0, 0)` | `$res->fetchColumn()` |

## Configuration

Driver is set via `DB_DRIVER` constant in `config/config_db.php` (generated by `docker/entrypoint.sh` from the `YOTSUBA_DB_DRIVER` env var):

```php
define('DB_DRIVER', 'pgsql');  // or 'mysql'
```

Switch in `docker-compose.dev.yml`:
```yaml
environment:
  - YOTSUBA_DB_DRIVER=pgsql  # or mysql
```
