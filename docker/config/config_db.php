<?php
define('SQLHOST_GLOBAL', getenv('LOCALCHAN_DB_HOST') ?: 'db');
define('SQLUSER_GLOBAL', getenv('LOCALCHAN_DB_USER') ?: 'localchan');
define('SQLPASS_GLOBAL', getenv('LOCALCHAN_DB_PASS') ?: 'localchan');
define('SQLDB_GLOBAL',  getenv('LOCALCHAN_DB_NAME') ?: 'localchan');

define('SQLUSER', SQLUSER_GLOBAL);
define('SQLPASS', SQLPASS_GLOBAL);

$use_pdo = true;
$using_pdo = true;
