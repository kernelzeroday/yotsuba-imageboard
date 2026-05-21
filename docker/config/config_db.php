<?php
// Containerized config — values from environment
define('SQLHOST_GLOBAL', getenv('YOTSUBA_DB_HOST') ?: 'db');
define('SQLUSER_GLOBAL', getenv('YOTSUBA_DB_USER') ?: 'yotsuba');
define('SQLPASS_GLOBAL', getenv('YOTSUBA_DB_PASS') ?: 'yotsuba');
define('SQLDB_GLOBAL',  getenv('YOTSUBA_DB_GLOBAL') ?: 'yotsuba_global');

define('SQLUSER', SQLUSER_GLOBAL);
define('SQLPASS', SQLPASS_GLOBAL);

// Use PDO — modern, safer, works on PHP 5.6+
$use_pdo = true;
$using_pdo = true;
