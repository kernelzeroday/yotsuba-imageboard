<?php
/**
 * Batch-embed: Generate CLIP vectors for all existing images missing clip_vector.
 * Reads image data from PG BYTEA column (no filesystem dependency).
 * Run inside the web container: php /var/www/html/docker/reembed.php
 */

$pg_host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
$pg_port = getenv('YOTSUBA_PG_PORT') ?: '5432';
$pg_user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
$pg_pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
$pg_db   = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba';

$clip_host = getenv('YOTSUBA_CLIP_HOST') ?: 'clip';
$clip_port = getenv('YOTSUBA_CLIP_PORT') ?: '8501';

$dsn = "pgsql:host={$pg_host};port={$pg_port};dbname={$pg_db}";
$pdo = new PDO($dsn, $pg_user, $pg_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$stmt = $pdo->query("SELECT no, board, ext FROM posts WHERE ext IS NOT NULL AND ext != '' AND clip_vector IS NULL AND image_data IS NOT NULL ORDER BY no");
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$total = count($rows);
echo "Found {$total} images to embed\n";

$fetch = $pdo->prepare("SELECT image_data FROM posts WHERE no = ? AND board = ?");
$upd = $pdo->prepare("UPDATE posts SET clip_vector = ?::vector WHERE no = ? AND board = ?");

$done = 0;
$errors = 0;

foreach ($rows as $row) {
    $no = $row['no'];
    $board = $row['board'];
    $ext = $row['ext'];

    $fetch->execute([$no, $board]);
    $img_row = $fetch->fetch(PDO::FETCH_ASSOC);
    $data = $img_row ? $img_row['image_data'] : null;

    if (is_resource($data)) $data = stream_get_contents($data);

    if (!$data || strlen($data) < 100) {
        $errors++;
        $done++;
        continue;
    }

    $boundary = '----ReEmbed' . uniqid();
    $body = "--{$boundary}\r\n"
        . "Content-Disposition: form-data; name=\"file\"; filename=\"image{$ext}\"\r\n"
        . "Content-Type: application/octet-stream\r\n\r\n"
        . $data . "\r\n"
        . "--{$boundary}--\r\n";
    unset($data);

    $ch = curl_init("http://{$clip_host}:{$clip_port}/embed");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_HTTPHEADER => ["Content-Type: multipart/form-data; boundary={$boundary}"],
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_USERAGENT => 'yotsuba/reembed',
    ]);
    unset($body);

    $resp = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($resp === false || $http_code !== 200) {
        $errors++;
        $done++;
        fprintf(STDERR, "[%d/%d] ERROR %s/%d — HTTP %d\n", $done, $total, $board, $no, $http_code);
        continue;
    }

    $result = json_decode($resp, true);
    if (!$result || !isset($result['embedding'])) {
        $errors++;
        $done++;
        fprintf(STDERR, "[%d/%d] ERROR %s/%d — no embedding in response\n", $done, $total, $board, $no);
        continue;
    }

    $vec_str = '[' . implode(',', $result['embedding']) . ']';
    $upd->execute([$vec_str, $no, $board]);

    $done++;
    if ($done % 10 === 0 || $done === $total) {
        echo sprintf("[%d/%d] %s/%d embedded (512-dim)\n", $done, $total, $board, $no);
    }
}

echo "\nDone: {$done} processed, {$errors} errors\n";

$embedded = $pdo->query("SELECT COUNT(*) FROM posts WHERE clip_vector IS NOT NULL")->fetchColumn();
echo "Total posts with embeddings: {$embedded}\n";
