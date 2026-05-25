<?php
$path = $_SERVER['REQUEST_URI'] ?? '';
$path = parse_url($path, PHP_URL_PATH);
$path = urldecode($path);

$is_thumb = false;
if (preg_match('#^/images/([a-z0-9]+)/(.+)$#', $path, $m)) {
    $board = $m[1];
    $filename = $m[2];
} elseif (preg_match('#^/thumbs/([a-z0-9]+)/(.+)$#', $path, $m)) {
    $board = $m[1];
    $filename = $m[2];
    $is_thumb = true;
} else {
    http_response_code(404);
    exit;
}

if (!preg_match('/^(\d+)s?\.(jpg|jpeg|png|gif|webp|webm|pdf)$/i', $filename, $fm)) {
    http_response_code(404);
    exit;
}
$tim = $fm[1];

$host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
$port = getenv('YOTSUBA_PG_PORT') ?: '5432';
$user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
$pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
$name = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba';

$dsn = "pgsql:host={$host};port={$port};dbname={$name}";
$pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$col = $is_thumb ? 'thumb_data' : 'image_data';
$stmt = $pdo->prepare("SELECT {$col}, ext FROM posts WHERE board = ? AND tim = ? AND {$col} IS NOT NULL LIMIT 1");
$stmt->execute([$board, $tim]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row || !$row[$col]) {
    http_response_code(404);
    exit;
}

$data = is_resource($row[$col]) ? stream_get_contents($row[$col]) : $row[$col];
$ext = strtolower($is_thumb ? '.jpg' : $row['ext']);
$mime_map = [
    '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg',
    '.png' => 'image/png', '.gif' => 'image/gif',
    '.webp' => 'image/webp', '.webm' => 'video/webm',
    '.pdf' => 'application/pdf',
];

header('Content-Type: ' . ($mime_map[$ext] ?? 'application/octet-stream'));
header('Content-Length: ' . strlen($data));
header('Cache-Control: public, max-age=31536000, immutable');
echo $data;
