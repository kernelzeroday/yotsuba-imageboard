<?php
/**
 * Batch-embed: Generate CLIP vectors for all existing images missing clip_vector.
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

$images_dir = '/www/4chan.org/web/images';

$stmt = $pdo->query("SELECT no, board, tim, ext FROM posts WHERE ext IS NOT NULL AND ext != '' AND clip_vector IS NULL ORDER BY no");
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$total = count($rows);
echo "Found {$total} images to embed\n";

$done = 0;
$errors = 0;
$skipped = 0;

foreach ($rows as $row) {
    $no = $row['no'];
    $board = $row['board'];
    $tim = $row['tim'];
    $ext = $row['ext'];

    $file_path = "{$images_dir}/{$board}/{$tim}{$ext}";

    if (!file_exists($file_path)) {
        $skipped++;
        $done++;
        if ($done % 50 === 0 || $done === $total) {
            fprintf(STDERR, "[%d/%d] progress — %d ok, %d skip, %d err\n", $done, $total, $done - $skipped - $errors, $skipped, $errors);
        }
        continue;
    }

    $data = file_get_contents($file_path);
    if (!$data || strlen($data) < 100) {
        $skipped++;
        $done++;
        continue;
    }

    $boundary = '----ReEmbed' . uniqid();
    $body = "--{$boundary}\r\n"
        . "Content-Disposition: form-data; name=\"file\"; filename=\"image{$ext}\"\r\n"
        . "Content-Type: application/octet-stream\r\n\r\n"
        . $data . "\r\n"
        . "--{$boundary}--\r\n";

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
    $upd = $pdo->prepare("UPDATE posts SET clip_vector = ?::vector WHERE no = ? AND board = ?");
    $upd->execute([$vec_str, $no, $board]);

    $done++;
    if ($done % 10 === 0 || $done === $total) {
        echo sprintf("[%d/%d] %s/%d embedded (512-dim)\n", $done, $total, $board, $no);
    }
}

echo "\nDone: {$done} processed, {$errors} errors, {$skipped} skipped (file not found)\n";

$embedded = $pdo->query("SELECT COUNT(*) FROM posts WHERE clip_vector IS NOT NULL")->fetchColumn();
echo "Total posts with embeddings: {$embedded}\n";
