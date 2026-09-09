<?php

require_once __DIR__ . '/lib/source_attachment.php';

$path = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
$path = rawurldecode((string)$path);

if (!preg_match('#^/source/([a-z0-9]+)/([1-9][0-9]*)/[^/]+$#', $path, $matches)) {
    http_response_code(404);
    exit;
}

$board = $matches[1];
$postNo = (int)$matches[2];

$driver = getenv('YOTSUBA_DB_DRIVER') ?: 'pgsql';

try {
    if ($driver === 'pgsql') {
        $host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
        $port = getenv('YOTSUBA_PG_PORT') ?: '5432';
        $user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
        $pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
        $name = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba';
        $pdo = new PDO(
            "pgsql:host={$host};port={$port};dbname={$name}",
            $user,
            $pass,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $stmt = $pdo->prepare(
            'SELECT source_filename, source_ext, source_fsize, source_data '
            . 'FROM posts WHERE board = ? AND no = ? AND source_data IS NOT NULL LIMIT 1'
        );
        $stmt->execute([$board, $postNo]);
    } else {
        $host = getenv('YOTSUBA_DB_HOST') ?: 'db';
        $port = getenv('YOTSUBA_DB_PORT') ?: '3306';
        $user = getenv('YOTSUBA_DB_USER') ?: 'yotsuba';
        $pass = getenv('YOTSUBA_DB_PASS') ?: 'yotsuba';
        $name = getenv('YOTSUBA_DB_NAME') ?: 'yotsuba_global';
        $pdo = new PDO(
            "mysql:host={$host};port={$port};dbname={$name};charset=utf8mb4",
            $user,
            $pass,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $stmt = $pdo->prepare(
            "SELECT source_filename, source_ext, source_fsize, source_data "
            . "FROM `{$board}` WHERE no = ? AND source_data IS NOT NULL LIMIT 1"
        );
        $stmt->execute([$postNo]);
    }
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
} catch (Throwable $error) {
    error_log('[source] ' . $error->getMessage());
    http_response_code(500);
    exit;
}

if (!$row || !array_key_exists('source_data', $row) || $row['source_data'] === null) {
    http_response_code(404);
    exit;
}

$data = is_resource($row['source_data'])
    ? stream_get_contents($row['source_data'])
    : $row['source_data'];
$data = is_string($data) ? $data : '';
$displayName = $row['source_filename'] . $row['source_ext'];
$asciiName = preg_replace('/[^A-Za-z0-9._-]/', '_', $displayName) ?: 'source.txt';

header('Content-Type: application/octet-stream');
header('Content-Length: ' . strlen($data));
header('Content-Disposition: attachment; filename="' . $asciiName
    . '"; filename*=UTF-8\'\'' . rawurlencode($displayName));
header('X-Content-Type-Options: nosniff');
header("Content-Security-Policy: sandbox; default-src 'none'");
header('Cache-Control: public, max-age=31536000, immutable');
echo $data;
