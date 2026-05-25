<?php

class YotsubaDB {
    private PDO $pdo;
    private string $driver;
    private static ?YotsubaDB $globalInstance = null;
    private static ?YotsubaDB $boardInstance = null;
    private int $lockLevel = 0;

    private function __construct(string $driver, PDO $pdo) {
        $this->driver = $driver;
        $this->pdo = $pdo;
    }

    public static function connect(string $driver, string $host, int $port, string $user, string $pass, string $db, bool $persistent = false): self {
        if ($driver === 'pgsql') {
            $dsn = "pgsql:host={$host};port={$port};dbname={$db}";
        } else {
            $dsn = "mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4";
        }

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_BOTH,
            PDO::ATTR_ORACLE_NULLS => PDO::NULL_NATURAL,
        ];

        if ($persistent) {
            $options[PDO::ATTR_PERSISTENT] = true;
        }

        if ($driver === 'mysql') {
            $options[PDO::MYSQL_ATTR_USE_BUFFERED_QUERY] = true;
        }

        $pdo = new PDO($dsn, $user, $pass, $options);

        if ($driver === 'pgsql') {
            $pdo->exec("SET client_encoding TO 'UTF8'");
        }

        return new self($driver, $pdo);
    }

    public static function global(): self {
        if (self::$globalInstance === null) {
            self::$globalInstance = self::connectFromConfig('global');
        }
        return self::$globalInstance;
    }

    public static function board(string $boardDir = ''): self {
        self::$boardInstance = self::connectFromConfig('board');
        return self::$boardInstance;
    }

    public static function resetGlobal(): void {
        self::$globalInstance = null;
    }

    public static function resetBoard(): void {
        if (self::$boardInstance) {
            self::$boardInstance->unlockTables();
        }
        self::$boardInstance = null;
    }

    private static function connectFromConfig(string $type): self {
        $driver = defined('DB_DRIVER') ? DB_DRIVER : 'mysql';

        if ($type === 'global') {
            $host = defined('SQLHOST_GLOBAL') ? SQLHOST_GLOBAL : 'db';
            $user = defined('SQLUSER_GLOBAL') ? SQLUSER_GLOBAL : 'yotsuba';
            $pass = defined('SQLPASS_GLOBAL') ? SQLPASS_GLOBAL : 'yotsuba';
            $db   = defined('SQLDB_GLOBAL')   ? SQLDB_GLOBAL   : 'yotsuba_global';
        } else {
            $host = defined('SQLHOST') ? SQLHOST : 'db';
            $user = defined('SQLUSER') ? SQLUSER : 'yotsuba';
            $pass = defined('SQLPASS') ? SQLPASS : 'yotsuba';
            $db   = defined('SQLDB')   ? SQLDB   : 'yotsuba_global';
        }

        $port = ($driver === 'pgsql') ? 5432 : 3306;
        if (strpos($host, ':') !== false) {
            list($host, $port) = explode(':', $host, 2);
            $port = (int)$port;
        }

        return self::connect($driver, $host, $port, $user, $pass, $db);
    }

    public function getDriver(): string {
        return $this->driver;
    }

    public function getPdo(): PDO {
        return $this->pdo;
    }

    // -----------------------------------------------------------------------
    // Query execution
    // -----------------------------------------------------------------------

    public function query(string $sql, array $params = []): PDOStatement {
        if ($this->driver === 'pgsql') {
            $sql = $this->translateSQL($sql);
        }

        $stmt = $this->pdo->prepare($sql);

        foreach ($params as $i => $val) {
            $key = is_int($i) ? $i + 1 : $i;
            if (is_int($val)) {
                $stmt->bindValue($key, $val, PDO::PARAM_INT);
            } elseif (is_null($val)) {
                $stmt->bindValue($key, null, PDO::PARAM_NULL);
            } else {
                $stmt->bindValue($key, (string)$val, PDO::PARAM_STR);
            }
        }

        $stmt->execute();
        return $stmt;
    }

    public function exec(string $sql): int {
        if ($this->driver === 'pgsql') {
            $sql = $this->translateSQL($sql);
            if (preg_match('/^\s*SET\s+(read_buffer_size|sort_buffer_size|net_write_timeout|wait_timeout|sql_mode)\b/i', $sql)) {
                return 0;
            }
        }
        return $this->pdo->exec($sql);
    }

    public function lastInsertId(?string $sequence = null): string {
        if ($this->driver === 'pgsql' && $sequence) {
            return $this->pdo->lastInsertId($sequence);
        }
        return $this->pdo->lastInsertId();
    }

    public function lastInsertIdForTable(string $table, string $column = 'no'): string {
        if ($this->driver === 'pgsql') {
            return $this->lastInsertId("{$table}_{$column}_seq");
        }
        return $this->lastInsertId();
    }

    // -----------------------------------------------------------------------
    // Identifier quoting
    // -----------------------------------------------------------------------

    public function qi(string $name): string {
        return $this->quoteIdentifier($name);
    }

    public function quoteIdentifier(string $name): string {
        $name = str_replace(['`', '"'], '', $name);
        if ($this->driver === 'pgsql') {
            return '"' . $name . '"';
        }
        return '`' . $name . '`';
    }

    // -----------------------------------------------------------------------
    // Table locking
    // -----------------------------------------------------------------------

    public function lockTable(string $table, string $mode = 'WRITE'): void {
        if ($this->lockLevel > 0) {
            return;
        }
        $this->lockLevel++;

        $quoted = $this->quoteIdentifier($table);
        if ($this->driver === 'pgsql') {
            $this->pdo->beginTransaction();
            $pgMode = ($mode === 'READ') ? 'SHARE' : 'EXCLUSIVE';
            $this->pdo->exec("LOCK TABLE {$quoted} IN {$pgMode} MODE");
        } else {
            $this->pdo->exec("LOCK TABLES {$quoted} {$mode}");
        }
    }

    public function unlockTables(): void {
        if ($this->lockLevel === 0) {
            return;
        }
        $this->lockLevel--;

        if ($this->driver === 'pgsql') {
            try {
                $this->pdo->commit();
            } catch (PDOException $e) {
                try { $this->pdo->rollBack(); } catch (PDOException $e2) {}
            }
        } else {
            $this->pdo->exec("UNLOCK TABLES");
        }
    }

    public function clearLocks(): void {
        if ($this->lockLevel > 0) {
            $this->lockLevel = 0;
            if ($this->driver === 'pgsql') {
                try { $this->pdo->rollBack(); } catch (PDOException $e) {}
            } else {
                try { $this->pdo->exec("UNLOCK TABLES"); } catch (PDOException $e) {}
            }
        }
    }

    // -----------------------------------------------------------------------
    // Transactions
    // -----------------------------------------------------------------------

    public function beginTransaction(): bool {
        return $this->pdo->beginTransaction();
    }

    public function commit(): bool {
        return $this->pdo->commit();
    }

    public function rollBack(): bool {
        return $this->pdo->rollBack();
    }

    // -----------------------------------------------------------------------
    // Connection health
    // -----------------------------------------------------------------------

    public function ping(): bool {
        try {
            $this->pdo->query("SELECT 1");
            return true;
        } catch (PDOException $e) {
            return false;
        }
    }

    // -----------------------------------------------------------------------
    // Query builder helpers — return [sql, params] tuples
    // -----------------------------------------------------------------------

    public function buildSelect(string $table, array $cols = ['*'], array $where = [], array $order = [], int $limit = 0, int $offset = 0): array {
        $q = $this->quoteIdentifier($table);
        $colStr = implode(', ', array_map(function($c) {
            return $c === '*' ? '*' : $this->quoteIdentifier($c);
        }, $cols));

        $sql = "SELECT {$colStr} FROM {$q}";
        $params = [];

        if ($where) {
            $clauses = [];
            foreach ($where as $col => $val) {
                $op = '=';
                if (preg_match('/^(.+?)\s*(>=|<=|!=|<>|>|<|LIKE)$/i', $col, $m)) {
                    $col = $m[1];
                    $op = strtoupper($m[2]);
                }
                $clauses[] = $this->quoteIdentifier($col) . " {$op} ?";
                $params[] = $val;
            }
            $sql .= ' WHERE ' . implode(' AND ', $clauses);
        }

        if ($order) {
            $orderClauses = [];
            foreach ($order as $col => $dir) {
                $orderClauses[] = $this->quoteIdentifier($col) . ' ' . (strtoupper($dir) === 'DESC' ? 'DESC' : 'ASC');
            }
            $sql .= ' ORDER BY ' . implode(', ', $orderClauses);
        }

        if ($limit > 0) {
            $sql .= " LIMIT {$limit}";
            if ($offset > 0) {
                $sql .= " OFFSET {$offset}";
            }
        }

        return [$sql, $params];
    }

    public function buildInsert(string $table, array $data): array {
        $q = $this->quoteIdentifier($table);
        $cols = [];
        $placeholders = [];
        $params = [];

        foreach ($data as $col => $val) {
            $cols[] = $this->quoteIdentifier($col);
            $placeholders[] = '?';
            $params[] = $val;
        }

        $sql = "INSERT INTO {$q} (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $placeholders) . ")";
        return [$sql, $params];
    }

    public function buildUpdate(string $table, array $data, array $where): array {
        $q = $this->quoteIdentifier($table);
        $setClauses = [];
        $params = [];

        foreach ($data as $col => $val) {
            $setClauses[] = $this->quoteIdentifier($col) . ' = ?';
            $params[] = $val;
        }

        $sql = "UPDATE {$q} SET " . implode(', ', $setClauses);

        if ($where) {
            $whereClauses = [];
            foreach ($where as $col => $val) {
                $op = '=';
                if (preg_match('/^(.+?)\s*(>=|<=|!=|<>|>|<)$/i', $col, $m)) {
                    $col = $m[1];
                    $op = $m[2];
                }
                $whereClauses[] = $this->quoteIdentifier($col) . " {$op} ?";
                $params[] = $val;
            }
            $sql .= ' WHERE ' . implode(' AND ', $whereClauses);
        }

        return [$sql, $params];
    }

    public function buildDelete(string $table, array $where): array {
        $q = $this->quoteIdentifier($table);
        $clauses = [];
        $params = [];

        foreach ($where as $col => $val) {
            $op = '=';
            if (preg_match('/^(.+?)\s*(>=|<=|!=|<>|>|<)$/i', $col, $m)) {
                $col = $m[1];
                $op = $m[2];
            }
            $clauses[] = $this->quoteIdentifier($col) . " {$op} ?";
            $params[] = $val;
        }

        $sql = "DELETE FROM {$q} WHERE " . implode(' AND ', $clauses);
        return [$sql, $params];
    }

    public function buildUpsert(string $table, array $data, $conflictKey, array $updateExprs): array {
        [$insertSql, $params] = $this->buildInsert($table, $data);

        if (is_string($conflictKey)) {
            $conflictKey = [$conflictKey];
        }

        if ($this->driver === 'pgsql') {
            $conflictCols = implode(', ', array_map([$this, 'quoteIdentifier'], $conflictKey));
            $updateParts = [];
            foreach ($updateExprs as $col => $expr) {
                if (is_int($col)) {
                    $updateParts[] = $expr;
                } else {
                    $updateParts[] = $this->quoteIdentifier($col) . ' = ' . $expr;
                }
            }
            $insertSql .= " ON CONFLICT ({$conflictCols}) DO UPDATE SET " . implode(', ', $updateParts);
        } else {
            $updateParts = [];
            foreach ($updateExprs as $col => $expr) {
                if (is_int($col)) {
                    $updateParts[] = $expr;
                } else {
                    $updateParts[] = "`{$col}` = {$expr}";
                }
            }
            $insertSql .= " ON DUPLICATE KEY UPDATE " . implode(', ', $updateParts);
        }

        return [$insertSql, $params];
    }

    // -----------------------------------------------------------------------
    // Dialect helpers for common SQL expressions
    // -----------------------------------------------------------------------

    public function now(): string {
        return 'NOW()';
    }

    public function dateInterval(string $from, int $n, string $unit): string {
        $unit = strtoupper($unit);
        if ($this->driver === 'pgsql') {
            return "{$from} - INTERVAL '{$n} {$unit}'";
        }
        return "DATE_SUB({$from}, INTERVAL {$n} {$unit})";
    }

    public function dateAdd(string $from, int $n, string $unit): string {
        $unit = strtoupper($unit);
        if ($this->driver === 'pgsql') {
            return "{$from} + INTERVAL '{$n} {$unit}'";
        }
        return "DATE_ADD({$from}, INTERVAL {$n} {$unit})";
    }

    public function unixTimestamp(string $col = ''): string {
        if ($this->driver === 'pgsql') {
            if ($col) {
                return "EXTRACT(EPOCH FROM {$col})::INTEGER";
            }
            return "EXTRACT(EPOCH FROM NOW())::INTEGER";
        }
        return $col ? "UNIX_TIMESTAMP({$col})" : "UNIX_TIMESTAMP()";
    }

    public function fromUnixtime(string $expr): string {
        if ($this->driver === 'pgsql') {
            return "TO_TIMESTAMP({$expr})";
        }
        return "FROM_UNIXTIME({$expr})";
    }

    public function ifExpr(string $cond, string $trueVal, string $falseVal): string {
        if ($this->driver === 'pgsql') {
            return "CASE WHEN {$cond} THEN {$trueVal} ELSE {$falseVal} END";
        }
        return "IF({$cond}, {$trueVal}, {$falseVal})";
    }

    public function groupConcat(string $expr, string $separator = ','): string {
        if ($this->driver === 'pgsql') {
            return "STRING_AGG({$expr}::TEXT, '{$separator}')";
        }
        return "GROUP_CONCAT({$expr})";
    }

    public function groupConcatDistinct(string $expr, string $separator = ','): string {
        if ($this->driver === 'pgsql') {
            return "STRING_AGG(DISTINCT {$expr}::TEXT, '{$separator}')";
        }
        return "GROUP_CONCAT(DISTINCT {$expr})";
    }

    public function concat(string ...$parts): string {
        if ($this->driver === 'pgsql') {
            return implode(' || ', $parts);
        }
        return 'CONCAT(' . implode(', ', $parts) . ')';
    }

    // -----------------------------------------------------------------------
    // SQL dialect translation (for shim layer — translates MySQL SQL to PG)
    // -----------------------------------------------------------------------

    public function translateSQL(string $sql): string {
        if ($this->driver !== 'pgsql') {
            return $sql;
        }

        // Backticks → double-quotes
        $sql = str_replace('`', '"', $sql);

        // Quote column names that conflict with PG reserved words/syntax
        $sql = preg_replace('/(?<!["\w])4pass_id(?!["\w])/', '"4pass_id"', $sql);

        // Strip MySQL query hints
        $sql = preg_replace('/\bHIGH_PRIORITY\b/i', '', $sql);
        $sql = preg_replace('/\bSQL_CACHE\b/i', '', $sql);
        $sql = preg_replace('/\bSQL_NO_CACHE\b/i', '', $sql);

        // TIMESTAMPDIFF(UNIT, start, end) → EXTRACT(EPOCH FROM (end - start))::INTEGER / divisor
        $sql = preg_replace_callback(
            '/\bTIMESTAMPDIFF\s*\(\s*(\w+)\s*,\s*(.+?)\s*,\s*(\w+)\s*\)/i',
            function($m) {
                $unit = strtoupper($m[1]);
                $divisor = match($unit) {
                    'SECOND' => 1,
                    'MINUTE' => 60,
                    'HOUR' => 3600,
                    'DAY' => 86400,
                    default => 1,
                };
                return "EXTRACT(EPOCH FROM ({$m[3]} - ({$m[2]})))::INTEGER / {$divisor}";
            },
            $sql
        );

        // DATE_SUB(expr, INTERVAL n UNIT) → expr - INTERVAL 'n UNIT'
        $sql = preg_replace_callback(
            '/\bDATE_SUB\s*\(\s*(.+?)\s*,\s*INTERVAL\s+(\d+)\s+(\w+)\s*\)/i',
            function($m) { return "({$m[1]} - INTERVAL '{$m[2]} {$m[3]}')"; },
            $sql
        );

        // DATE_ADD(expr, INTERVAL n UNIT) → expr + INTERVAL 'n UNIT'
        $sql = preg_replace_callback(
            '/\bDATE_ADD\s*\(\s*(.+?)\s*,\s*INTERVAL\s+(\d+)\s+(\w+)\s*\)/i',
            function($m) { return "({$m[1]} + INTERVAL '{$m[2]} {$m[3]}')"; },
            $sql
        );

        // Bare INTERVAL n UNIT → INTERVAL 'n UNIT' (PG requires quoted interval)
        $sql = preg_replace(
            "/\\bINTERVAL\\s+(?!')\\s*(\\d+)\\s+(SECOND|MINUTE|HOUR|DAY|WEEK|MONTH|YEAR)\\b/i",
            "INTERVAL '\\1 \\2'",
            $sql
        );

        // UNIX_TIMESTAMP() → EXTRACT(EPOCH FROM NOW())::INTEGER (no-arg form first)
        $sql = preg_replace('/\bUNIX_TIMESTAMP\s*\(\s*\)/i', "EXTRACT(EPOCH FROM NOW())::INTEGER", $sql);

        // UNIX_TIMESTAMP(col) → EXTRACT(EPOCH FROM col)::INTEGER
        $sql = preg_replace_callback(
            '/\bUNIX_TIMESTAMP\s*\(\s*([^)]+)\s*\)/i',
            function($m) {
                return "EXTRACT(EPOCH FROM {$m[1]})::INTEGER";
            },
            $sql
        );

        // FROM_UNIXTIME(n) → TO_TIMESTAMP(n)
        $sql = preg_replace('/\bFROM_UNIXTIME\s*\(/i', 'TO_TIMESTAMP(', $sql);

        // IF(cond, a, b) → CASE WHEN cond THEN a ELSE b END
        $sql = preg_replace_callback(
            '/\bIF\s*\(\s*(.+?)\s*,\s*(.+?)\s*,\s*(.+?)\s*\)/i',
            function($m) { return "CASE WHEN {$m[1]} THEN {$m[2]} ELSE {$m[3]} END"; },
            $sql
        );

        // GROUP_CONCAT(DISTINCT expr) → STRING_AGG(DISTINCT expr::TEXT, ',')
        $sql = preg_replace_callback(
            '/\bGROUP_CONCAT\s*\(\s*DISTINCT\s+(.+?)\s*\)/i',
            function($m) { return "STRING_AGG(DISTINCT ({$m[1]})::TEXT, ',')"; },
            $sql
        );

        // GROUP_CONCAT(expr) → STRING_AGG(expr::TEXT, ',')
        $sql = preg_replace_callback(
            '/\bGROUP_CONCAT\s*\(\s*(.+?)\s*\)/i',
            function($m) { return "STRING_AGG(({$m[1]})::TEXT, ',')"; },
            $sql
        );

        // Strip LIMIT from UPDATE/DELETE (PG doesn't support it)
        $sql = preg_replace('/^(\s*UPDATE\b.+?)\s+LIMIT\s+\d+/is', '$1', $sql);
        $sql = preg_replace('/^(\s*DELETE\b.+?)\s+LIMIT\s+\d+/is', '$1', $sql);

        // LIMIT offset, count → LIMIT count OFFSET offset
        $sql = preg_replace_callback(
            '/\bLIMIT\s+(\d+)\s*,\s*(\d+)/i',
            function($m) { return "LIMIT {$m[2]} OFFSET {$m[1]}"; },
            $sql
        );

        // INSERT IGNORE INTO ... → INSERT INTO ... ON CONFLICT DO NOTHING
        if (preg_match('/\bINSERT\s+IGNORE\b/i', $sql)) {
            $sql = preg_replace('/\bINSERT\s+IGNORE\b/i', 'INSERT', $sql);
            $sql = rtrim($sql, "; \t\n\r") . ' ON CONFLICT DO NOTHING';
        }

        // LOCK TABLES ... → no-op for PG (handled by lockTable method)
        $sql = preg_replace('/\bLOCK\s+TABLES?\s+.+?(READ|WRITE)\s*(LOCAL)?/i', '-- LOCK TABLE (no-op, handled by DBAL)', $sql);

        // UNLOCK TABLES → no-op
        $sql = preg_replace('/\bUNLOCK\s+TABLES?\b/i', '-- UNLOCK TABLES (no-op)', $sql);

        // SHOW TABLES LIKE 'x' → query information_schema
        $sql = preg_replace_callback(
            "/\bSHOW\s+TABLES\s+LIKE\s+'(.+?)'/i",
            function($m) { return "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '{$m[1]}'"; },
            $sql
        );

        // Clean up extra spaces
        $sql = preg_replace('/\s+/', ' ', $sql);

        return trim($sql);
    }

    // -----------------------------------------------------------------------
    // Error info
    // -----------------------------------------------------------------------

    public function errorInfo(): array {
        return $this->pdo->errorInfo();
    }

    public function errorCode(): string {
        return $this->pdo->errorCode();
    }
}
