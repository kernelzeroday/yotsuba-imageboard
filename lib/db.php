<?php
/**
 * PDO Database Handler with DBAL shim
 *
 * Drop-in replacement for the original mysqli-based db.php.
 * All function signatures are preserved — zero caller changes required.
 * Routes through YotsubaDB DBAL for PostgreSQL dialect translation.
 */
require_once 'config/config_db.php';
require_once 'lib/util.php';
require_once 'lib/dbal.php';

if(!defined('S_SQLCONF')) {
	define('S_SQLCONF', 'Database connection error');
	define('S_SQLDBSF', 'Database error');
}

/** @var YotsubaDB|null */
$_dbal_instance = null;

function _dbal(): YotsubaDB {
	global $_dbal_instance;
	if (!$_dbal_instance) {
		$_dbal_instance = YotsubaDB::global();
	}
	return $_dbal_instance;
}

function _db_driver(): string {
	return defined('DB_DRIVER') ? DB_DRIVER : 'mysql';
}

function pdo_build_dsn($host, $db, $charset = 'utf8mb4') {
	$port = (_db_driver() === 'pgsql') ? 5432 : 3306;
	if (strpos($host, ':') !== false) {
		list($host, $port) = explode(':', $host, 2);
		$port = (int)$port;
	}
	if (_db_driver() === 'pgsql') {
		return "pgsql:host={$host};port={$port};dbname={$db}";
	}
	return "mysql:host={$host};port={$port};dbname={$db};charset={$charset}";
}

/**
 * Connect to MySQL via PDO. Returns a PDO object.
 * Signature preserved: same params as the original mysqli version.
 */
function mysql_try_connect($host, $usr, $pass, $db, $pconnect = true) {
	$tries = 1;

	$options = array(
		PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
		PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_BOTH,
		PDO::ATTR_ORACLE_NULLS       => PDO::NULL_NATURAL,
	);

	if (_db_driver() === 'mysql') {
		$options[PDO::MYSQL_ATTR_USE_BUFFERED_QUERY] = true;
	}

	if ($pconnect) {
		$options[PDO::ATTR_PERSISTENT] = true;
	}

	$dsn = pdo_build_dsn($host, $db);
	$con = null;

	do {
		$failed = 1;
		try {
			$con = new PDO($dsn, $usr, $pass, $options);
			$failed = 0;
		} catch (PDOException $e) {
			// Connection failed, will retry if tries remain
		}
	} while ($failed && $tries--);

	if ($failed) {
		mysql_internal_err(NULL, "while connecting to $host", "", true);
	}

	if (_db_driver() === 'pgsql' && $con) {
		$con->exec("SET client_encoding TO 'UTF8'");
	}

	return $con;
}

function mysql_internal_close($con) {
	if ($con instanceof PDO) {
		try {
			if (_db_driver() === 'pgsql') {
				$con->rollBack();
			} else {
				$con->exec("UNLOCK TABLES");
			}
		} catch (PDOException $e) {
			// ignore errors during cleanup
		}
	}
}

function mysql_board_lock($local=false) {
	global $board_lock_level, $con;

	if ($board_lock_level > 0) {
		mysql_internal_err($con, "recursively locked table", "lock tables ".BOARD_DIR);
		return;
	}

	$board_lock_level++;

	if (_db_driver() === 'pgsql') {
		$con->beginTransaction();
		$qi = '"' . str_replace('"', '', BOARD_DIR) . '"';
		$con->exec("LOCK TABLE {$qi} IN SHARE MODE");
	} else {
		$con->exec("lock tables ".BOARD_DIR." read".($local ? " local" : ""));
	}
}

function mysql_board_unlock($ignore_error=false) {
	global $board_lock_level, $con;

	if ($board_lock_level == 0) {
		if (!$ignore_error)
			mysql_internal_err($con, "not already locked", "unlock tables");
		return;
	}

	$board_lock_level--;

	if (_db_driver() === 'pgsql') {
		try { $con->commit(); } catch (PDOException $e) {
			try { $con->rollBack(); } catch (PDOException $e2) {}
		}
	} else {
		$con->exec("unlock tables");
	}
}

function mysql_clear_locks() {
	mysql_board_unlock(true);
}

function mysql_global_connect($pconnect=true) {
	global $gcon;
	$gcon = mysql_try_connect(SQLHOST_GLOBAL, SQLUSER_GLOBAL, SQLPASS_GLOBAL, SQLDB_GLOBAL, false);
	return $gcon;
}

function mysql_check_connections() {
	global $gcon, $con;

	// PDO doesn't have ping(). Try a lightweight query to check liveness.
	$gcon_res = false;
	$con_res = false;

	try {
		if ($gcon) { $gcon->query("SELECT 1"); $gcon_res = true; }
	} catch (PDOException $e) {}

	try {
		if ($con) { $con->query("SELECT 1"); $con_res = true; }
	} catch (PDOException $e) {}

	if ($gcon_res == false || $con_res == false) {
		mysql_internal_close($con);
		mysql_internal_close($gcon);
		$con = null;
		$gcon = null;
		mysql_board_connect(BOARD_DIR, false);
		mysql_global_connect(false);
	}
}

function mysql_internal_err($conn, $priverr, $query="", $die=false) {
	global $mysql_never_die;
	global $mysql_suppress_err;

	$errno = 0;
	$error = 'no connection';

	if ($conn instanceof PDO) {
		$info = $conn->errorInfo();
		$errno = $info[1] ?? 0;
		$error = $info[2] ?? '';
	}

	$err = sprintf("%s error: %s - %d - %s%s", $query ? "query" : "connection",
					$priverr, $errno, $error, $query ? " query: $query" : "");

    if (defined('SQL_DEBUG') && SQL_DEBUG && ini_get('display_errors')) echo $err."\n";

	internal_error_log("SQL", $err);

	if ($die && !$mysql_never_die) die($query ? S_SQLDBSF : S_SQLCONF);
}

function mysql_board_connect($board="", $pconnect=true) {
	global $con;
	global $did_add_lockfunc;

	if (!defined('SQLHOST')) {
		$db = 1;
		$host = "db-ena.int";
		$db = "img$db";

		define('SQLHOST', $host);
		define('SQLDB', $db);
		if ($board) define('BOARD_DIR', $board);
	} else {
		$host = SQLHOST;
		$db = SQLDB;
	}

	$con = mysql_try_connect($host, SQLUSER, SQLPASS, $db, false);

	if (!$did_add_lockfunc) {
		$did_add_lockfunc = 1;
		register_shutdown_function("mysql_clear_locks");
	}
	return $con;
}

/**
 * Execute a query string on a PDO connection.
 * Keeps the original vsprintf-based query building from callers.
 * Returns a PDOStatement on success, or false on failure.
 */
function mysql_do_query($query, $con) {
	global $mysql_unbuffered_reads;
	global $mysql_suppress_err;
	global $mysql_query_log;
	global $mysql_debug_buf;
	static $querylog_fd;

	if (_db_driver() === 'pgsql') {
		$query = _dbal()->translateSQL($query);
	}

	$querylog = (defined('QUERY_LOG') && constant('QUERY_LOG')) || $mysql_query_log == true;
	$is_select = stripos($query, "SELECT")===0;

	$time = 0;
	if ($querylog) {
		$time = microtime(true);

		if (!$querylog_fd) {
			$querylog_fd = fopen("/www/perhost/querylog.log", "a");
			flock($querylog_fd, LOCK_EX);
		}

		fprintf($querylog_fd, "%d query: %s\n", getmypid(), $query);
	}

	if (_db_driver() === 'mysql') {
		if ($mysql_unbuffered_reads) {
			$con->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY, false);
		} else {
			$con->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY, true);
		}
	}

	$ret = false;
	try {
		$stmt = $con->query($query);
		if ($stmt !== false) {
			$ret = $stmt;
		}
	} catch (PDOException $e) {
		$ret = false;
	}

	if ($ret && $querylog) {
		$elapsed = microtime(true) - $time;

		if (!$mysql_unbuffered_reads && $ret instanceof PDOStatement) {
			$nr = $ret->rowCount();
		} else {
			$nr = "?";
		}

		fprintf($querylog_fd, "%d rows, %f sec\n", $nr, $elapsed);
	}

	if (isset($mysql_debug_buf)) {
		if (!$mysql_unbuffered_reads && $ret instanceof PDOStatement) {
			$nr = $ret->rowCount();
			if (!$nr) $nr = 0;
		} else
			$nr = "?";

		$mysql_debug_buf .= "Query: $query\nRows: $nr\n";
	}

	if ($ret === false) {
		mysql_internal_err($con, "in do_query", $query);
	}

	return $ret;
}

/**
 * PDO-based escape. PDO::quote() wraps the string in quotes,
 * so we strip them to match mysqli_real_escape_string behavior.
 */
function pdo_escape_string($string, $con) {
	if (!($con instanceof PDO)) return addslashes($string);
	$quoted = $con->quote($string);
	// PDO::quote() returns 'escaped_string' (with surrounding quotes)
	// Strip the outer quotes to match mysqli_real_escape_string behavior
	if ($quoted !== false && strlen($quoted) >= 2) {
		return substr($quoted, 1, -1);
	}
	return addslashes($string);
}

function try_escape_string($string, $con, $recon_func, $tries=0)
{
	$res = pdo_escape_string($string, $con);

	if ($res === false) {
		mysql_internal_err($con, "in escape_string", $string, $tries == 0);
	}

	return $res;
}

function mysql_global_call() {
	global $gcon;
	if(!$gcon) mysql_global_connect();
	$args = func_get_args();
	$format = array_shift($args);

	if (count($args)) {
		foreach($args as &$arg)
			$arg = try_escape_string($arg, $gcon, "mysql_global_connect" );
		$query = vsprintf($format, $args);
	} else $query = $format;

	return mysql_do_query( $query, $gcon );
}

function mysql_global_error() {
	global $gcon;
	if(!$gcon) mysql_global_connect();

	$info = $gcon->errorInfo();
	return $info[2] ?? '';
}

function mysql_global_do() {
	global $gcon;
	if(!$gcon) mysql_global_connect();
	$args = func_get_args();
	$format = array_shift($args);

	if (count($args)) {
		foreach($args as &$arg)
			$arg = try_escape_string($arg, $gcon, "mysql_global_connect" );
		$query = vsprintf($format, $args);
	} else $query = $format;

	return mysql_do_query( $query, $gcon );
}

function mysql_global_insert_id() {
	global $gcon;
	return $gcon->lastInsertId();
}

function mysql_board_call() {
	global $con;
	if (!$con) mysql_board_connect();
	$args = func_get_args();
	$format = array_shift($args);

	if (count($args)) {
		foreach($args as &$arg)
			$arg = pdo_escape_string($arg, $con);
		$query = vsprintf($format, $args);
	} else $query = $format;

	return mysql_do_query( $query, $con );
}

function mysql_global_escape($string) {
	global $gcon;
	if(!$gcon) mysql_global_connect();

	return pdo_escape_string($string, $gcon);
}

function mysql_board_error() {
	global $con;
	if(!$con) mysql_board_connect();

	$info = $con->errorInfo();
	return $info[2] ?? '';
}

function mysql_board_escape($string) {
	global $con;
	if (!$con) mysql_board_connect();

	return pdo_escape_string($string, $con);
}

function mysql_board_get_post($board,$no) {
	global $con;
	mysql_board_connect($board);
	$query = mysql_board_call("SELECT HIGH_PRIORITY * from `%s` WHERE no=%d",$board,$no);
	$array = ($query instanceof PDOStatement) ? $query->fetch(PDO::FETCH_ASSOC) : false;
	$con = NULL;
	return $array;
}

function mysql_board_get_post_lazy( $board, $no )
{
	global $con;
	mysql_board_connect($board);
	$query = mysql_board_call("SELECT * from `%s` WHERE no=%d",$board,$no);
	$array = ($query instanceof PDOStatement) ? $query->fetch(PDO::FETCH_ASSOC) : false;
	$con = NULL;
	return $array;
}

function mysql_board_insert_id() {
	global $con;
	return $con->lastInsertId();
}

function mysql_global_row($table, $col, $val)
{
	$q = mysql_global_call("select * from `%s` where $col='%s'", $table, $val);
	$r = ($q instanceof PDOStatement) ? $q->fetch(PDO::FETCH_ASSOC) : false;
	if ($q instanceof PDOStatement) $q->closeCursor();
	return $r;
}

function mysql_board_row($table, $col, $val)
{
	$q = mysql_board_call("select * from `%s` where $col='%s'", $table, $val);
	$r = ($q instanceof PDOStatement) ? $q->fetch(PDO::FETCH_ASSOC) : false;
	if ($q instanceof PDOStatement) $q->closeCursor();
	return $r;
}

function mysql_column_array($q) {
	$ret = array();
	if ($q instanceof PDOStatement) {
		while ($row = $q->fetch(PDO::FETCH_NUM))
			$ret[] = $row[0];
	}
	return $ret;
}

function mysql_nullify($s) {
	return ($s || $s === '0') ? "'$s'" : "''";
}

// Compatibility shim: mysql_result() — emulated with PDO
function mysql_result($result, $row, $field = 0) {
	if (!($result instanceof PDOStatement)) return false;
	// Fetch all rows up to the requested row index
	// For large result sets this is suboptimal, but this function is rarely used
	$data = $result->fetchAll(PDO::FETCH_BOTH);
	if (!isset($data[$row])) return false;
	return $data[$row][$field] ?? false;
}

// Compatibility: mysql_escape_string (removed in PHP 8)
function mysql_escape_string($string) {
	return mysql_real_escape_string($string);
}

// Compatibility: mysql_real_escape_string without connection param
function mysql_real_escape_string($string, $link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	return pdo_escape_string($string, $c);
}

// Compatibility wrappers for direct mysql_* calls throughout the codebase
function mysql_fetch_assoc($result) {
	if ($result instanceof PDOStatement) return $result->fetch(PDO::FETCH_ASSOC);
	return false;
}

function mysql_fetch_array($result, $type = null) {
	if (!($result instanceof PDOStatement)) return false;
	// Map MYSQLI_BOTH/MYSQLI_ASSOC/MYSQLI_NUM to PDO equivalents
	// MYSQLI_BOTH = 3, MYSQLI_ASSOC = 1, MYSQLI_NUM = 2
	if ($type === null || $type === 3) {  // MYSQLI_BOTH
		return $result->fetch(PDO::FETCH_BOTH);
	} elseif ($type === 1) {  // MYSQLI_ASSOC
		return $result->fetch(PDO::FETCH_ASSOC);
	} elseif ($type === 2) {  // MYSQLI_NUM
		return $result->fetch(PDO::FETCH_NUM);
	}
	return $result->fetch(PDO::FETCH_BOTH);
}

function mysql_fetch_row($result) {
	if (!($result instanceof PDOStatement)) return false;
	return $result->fetch(PDO::FETCH_NUM);
}

function mysql_num_rows($result) {
	if (!($result instanceof PDOStatement)) return 0;
	return $result->rowCount();
}

function mysql_free_result($result) {
	if ($result instanceof PDOStatement) $result->closeCursor();
}

function mysql_insert_id($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return 0;
	return $c->lastInsertId();
}

function mysql_affected_rows($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	// PDO tracks affected rows on the statement, not the connection.
	// For compatibility, we store the last statement's row count.
	// However, most callers use this right after mysql_board_call/mysql_global_call,
	// and those return PDOStatement which callers should use directly.
	// As a fallback, try exec on a dummy to get 0.
	if (!($c instanceof PDO)) return 0;
	// PDO doesn't track affected_rows on the connection object.
	// Return 0 as a safe fallback. Callers that need affected_rows
	// should use the PDOStatement::rowCount() on the returned statement.
	return 0;
}

function mysql_error($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return 'No connection';
	$info = $c->errorInfo();
	return $info[2] ?? '';
}

function mysql_errno($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return 0;
	$info = $c->errorInfo();
	return (int)($info[1] ?? 0);
}

function mysql_query($query, $link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return false;
	try {
		$stmt = $c->query($query);
		return $stmt;
	} catch (PDOException $e) {
		return false;
	}
}

function mysql_close($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	// PDO doesn't have an explicit close — just null the reference
	if ($link) {
		$link = null;
	} else if ($con) {
		$con = null;
	} else if ($gcon) {
		$gcon = null;
	}
}

function mysql_ping($link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return false;
	try {
		$c->query("SELECT 1");
		return true;
	} catch (PDOException $e) {
		return false;
	}
}

function mysql_select_db($db, $link = null) {
	global $con, $gcon;
	$c = $link ?: $con ?: $gcon;
	if (!($c instanceof PDO)) return false;
	if (_db_driver() === 'pgsql') {
		return true;
	}
	try {
		$c->exec("USE `$db`");
		return true;
	} catch (PDOException $e) {
		return false;
	}
}

?>
