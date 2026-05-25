<?php
/**
 * Re-CLIP: Batch tag all existing images with CLIP descriptions.
 * Run inside the web container: php /var/www/html/docker/reclip.php
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

$stmt = $pdo->query("SELECT no, board, tim, ext FROM posts WHERE ext IS NOT NULL AND ext != '' AND (clip_desc IS NULL OR clip_desc = '') ORDER BY no");
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$total = count($rows);
echo "Found {$total} images to process\n";

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
        fprintf(STDERR, "[%d/%d] SKIP %s/%d — file not found: %s\n", $done, $total, $board, $no, basename($file_path));
        continue;
    }

    $data = file_get_contents($file_path);
    if (!$data) {
        $skipped++;
        $done++;
        fprintf(STDERR, "[%d/%d] SKIP %s/%d — empty file\n", $done, $total, $board, $no);
        continue;
    }

    $ch = curl_init("http://{$clip_host}:{$clip_port}/predict");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $data,
        CURLOPT_HTTPHEADER => ['Content-Type: application/octet-stream'],
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_USERAGENT => 'yotsuba/reclip',
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
    if (!$result) {
        $errors++;
        $done++;
        fprintf(STDERR, "[%d/%d] ERROR %s/%d — bad JSON\n", $done, $total, $board, $no);
        continue;
    }

    $nsfw = isset($result['nsfw']) ? (float)$result['nsfw'] : 0;
    $desc = isset($result['description']) ? substr($result['description'], 0, 500) : '';

    $upd = $pdo->prepare("UPDATE posts SET clip_nsfw = ?, clip_desc = ? WHERE no = ? AND board = ?");
    $upd->execute([$nsfw, $desc, $no, $board]);

    $done++;
    echo sprintf("[%d/%d] OK %s/%d — nsfw=%.3f desc=%s\n", $done, $total, $board, $no, $nsfw, substr($desc, 0, 60));
}

echo "\nDone: {$done} processed, {$errors} errors, {$skipped} skipped (file not found)\n";
