<?php
// Serve pre-generated catalog HTML from the static cache
// Apache rewrites /board/catalog -> /board/catalog_serve.php
$board = basename(dirname($_SERVER['SCRIPT_FILENAME']));
$data_root = '/www/4chan.org/web/boards/' . $board . '/';
$gz_file = $data_root . 'catalog.html.gz';

if (file_exists($gz_file)) {
    $content = file_get_contents($gz_file);
    if ($content !== false && strlen($content) > 0) {
        // Check if client accepts gzip
        if (isset($_SERVER['HTTP_ACCEPT_ENCODING']) && strpos($_SERVER['HTTP_ACCEPT_ENCODING'], 'gzip') !== false) {
            header('Content-Type: text/html; charset=UTF-8');
            header('Content-Encoding: gzip');
            header('Content-Length: ' . strlen($content));
            echo $content;
        } else {
            // Decompress for clients that don't support gzip
            $html = gzdecode($content);
            header('Content-Type: text/html; charset=UTF-8');
            header('Content-Length: ' . strlen($html));
            echo $html;
        }
        exit;
    }
}

// Fallback: generate catalog on the fly
// This requires the full yotsuba environment
header('HTTP/1.1 404 Not Found');
header('Content-Type: text/html; charset=UTF-8');
echo '<html><body><h1>Catalog not available</h1><p>No cached catalog found for /' . htmlspecialchars($board) . '/. <a href="/' . htmlspecialchars($board) . '/">Return to board</a></p></body></html>';
