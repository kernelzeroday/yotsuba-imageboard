<?php
/**
 * Batch import: Store existing filesystem images into PostgreSQL BYTEA columns.
 * Run inside the web container: php /var/www/html/docker/reimport_images.php
 */

$pg_host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
$pg_port = getenv('YOTSUBA_PG_PORT') ?: '5432';
$pg_user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
$pg_pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
$pg_db   = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba';

$dsn = "pgsql:host={$pg_host};port={$pg_port};dbname={$pg_db}";
$pdo = new PDO($dsn, $pg_user, $pg_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$images_dir = '/www/4chan.org/web/images';
$thumbs_dir = '/www/4chan.org/web/thumbs';

$stmt = $pdo->query("SELECT no, board, tim, ext FROM posts WHERE ext IS NOT NULL AND ext != '' AND image_data IS NULL ORDER BY no");
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$total = count($rows);
echo "Found {$total} posts to import images for\n";

$done = 0;
$imported = 0;
$skipped = 0;
$bytes_total = 0;

$upd = $pdo->prepare("UPDATE posts SET image_data = ?, thumb_data = ? WHERE no = ? AND board = ?");

foreach ($rows as $row) {
    $no = $row['no'];
    $board = $row['board'];
    $tim = $row['tim'];
    $ext = $row['ext'];

    $img_path = "{$images_dir}/{$board}/{$tim}{$ext}";
    $thumb_path = "{$thumbs_dir}/{$board}/{$tim}s.jpg";

    if (!file_exists($img_path)) {
        $skipped++;
        $done++;
        continue;
    }

    $img_data = file_get_contents($img_path);
    if (!$img_data) {
        $skipped++;
        $done++;
        continue;
    }

    $thumb_data = file_exists($thumb_path) ? file_get_contents($thumb_path) : null;

    $upd->bindValue(1, $img_data, PDO::PARAM_LOB);
    $upd->bindValue(2, $thumb_data, $thumb_data ? PDO::PARAM_LOB : PDO::PARAM_NULL);
    $upd->bindValue(3, $no, PDO::PARAM_INT);
    $upd->bindValue(4, $board, PDO::PARAM_STR);
    $upd->execute();

    $bytes_total += strlen($img_data) + ($thumb_data ? strlen($thumb_data) : 0);
    $imported++;
    $done++;

    if ($done % 20 === 0 || $done === $total) {
        $mb = round($bytes_total / 1048576, 1);
        echo sprintf("[%d/%d] %s/%d — %d imported, %d skip, %.1f MB stored\n", $done, $total, $board, $no, $imported, $skipped, $mb);
    }
}

echo sprintf("\nDone: %d imported, %d skipped, %.1f MB total\n", $imported, $skipped, $bytes_total / 1048576);

$with_images = $pdo->query("SELECT COUNT(*) FROM posts WHERE image_data IS NOT NULL")->fetchColumn();
echo "Total posts with stored images: {$with_images}\n";
