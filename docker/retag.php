#!/usr/bin/env php
<?php
$pg_host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
$pg_port = getenv('YOTSUBA_PG_PORT') ?: '5432';
$pg_user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
$pg_pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
$pg_db   = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba_dev';

$clip_host = getenv('TENSORCHAN_HOST') ?: 'clip';
$clip_port = getenv('TENSORCHAN_PORT') ?: '8501';

$dsn = "pgsql:host={$pg_host};port={$pg_port};dbname={$pg_db}";
$pdo = new PDO($dsn, $pg_user, $pg_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$forceAll = in_array('--force', $argv);
$batchSize = 50;

// --- Phase 1: Image posts (iblip tags via BLIP + NSFW score) ---
echo "=== Phase 1: Image posts (iblip) ===\n";

$where = $forceAll
    ? "WHERE image_data IS NOT NULL AND LENGTH(image_data) > 100"
    : "WHERE image_data IS NOT NULL AND LENGTH(image_data) > 100 AND (clip_desc = '' OR clip_desc IS NULL)";

$total = (int)$pdo->query("SELECT COUNT(*) FROM posts {$where}")->fetchColumn();
echo "Image posts to process: {$total}\n";

$imgUpdate = $pdo->prepare(
    "UPDATE posts SET clip_nsfw = ?, clip_anime = ?, clip_caption = ?, clip_desc = ? WHERE board = ? AND no = ?"
);

$processed = 0;
$errors = 0;
$offset = 0;

while ($offset < $total) {
    $rows = $pdo->query(
        "SELECT board, no, image_data FROM posts {$where} ORDER BY no ASC LIMIT {$batchSize} OFFSET {$offset}"
    );

    foreach ($rows as $row) {
        $board = $row['board'];
        $no = $row['no'];
        $imageData = $row['image_data'];

        if (is_resource($imageData)) {
            $imageData = stream_get_contents($imageData);
        }

        if (!$imageData || strlen($imageData) < 100) {
            $processed++;
            continue;
        }

        $ch = curl_init("http://{$clip_host}:{$clip_port}/predict");
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $imageData,
            CURLOPT_HTTPHEADER => ['Content-Type: application/octet-stream'],
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 60,
        ]);

        $resp = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($resp === false || $httpCode >= 300) {
            echo "  [{$board}/{$no}] ERROR: HTTP {$httpCode}\n";
            $errors++;
            $processed++;
            continue;
        }

        $result = json_decode($resp, true);
        if (!$result || !isset($result['nsfw'])) {
            echo "  [{$board}/{$no}] ERROR: bad response\n";
            $errors++;
            $processed++;
            continue;
        }

        $nsfw = (float)$result['nsfw'];
        $anime = (float)($result['anime'] ?? 0);
        $caption = substr($result['caption'] ?? '', 0, 1000);
        $desc = substr($result['description'] ?? '', 0, 500);

        $imgUpdate->execute([$nsfw, $anime, $caption, $desc, $board, $no]);

        $processed++;
        echo "  [{$board}/{$no}] iblip:{$desc} nsfw:{$nsfw} anime:{$anime}\n";

        if ($processed % 25 === 0) {
            echo "--- Image progress: {$processed}/{$total} (errors: {$errors}) ---\n";
        }
    }

    $offset += $batchSize;
}

echo "Image posts done: {$processed}, Errors: {$errors}\n\n";

// --- Phase 2: All posts with text — toxicity, AI score, tblip tags ---
echo "=== Phase 2: Text moderation + tblip tags ===\n";

$textWhere = $forceAll
    ? "WHERE com != '' AND LENGTH(com) >= 10"
    : "WHERE com != '' AND LENGTH(com) >= 10 AND clip_text_desc = '' AND clip_toxicity = 0 AND clip_ai_score = 0";

$textCount = (int)$pdo->query("SELECT COUNT(*) FROM posts {$textWhere}")->fetchColumn();
echo "Text posts to process: {$textCount}\n";

$textUpdate = $pdo->prepare(
    "UPDATE posts SET clip_toxicity = ?, clip_ai_score = ?, clip_severe_toxicity = ?, clip_obscene = ?, clip_threat = ?, clip_insult = ?, clip_identity_attack = ?, clip_sexual_explicit = ?, clip_text_desc = ? WHERE board = ? AND no = ?"
);

$textProcessed = 0;
$textErrors = 0;
$textOffset = 0;

while ($textOffset < $textCount) {
    $rows = $pdo->query(
        "SELECT board, no, com FROM posts {$textWhere} ORDER BY no ASC LIMIT {$batchSize} OFFSET {$textOffset}"
    );

    foreach ($rows as $row) {
        $board = $row['board'];
        $no = $row['no'];
        $plain = html_entity_decode(strip_tags($row['com']), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        if (strlen($plain) < 10) {
            $textProcessed++;
            continue;
        }

        // Moderate text (toxicity + AI score)
        $ch = curl_init("http://{$clip_host}:{$clip_port}/moderate");
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['text' => $plain]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 30,
        ]);
        $resp = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $toxicity = 0;
        $aiScore = 0;
        $severeToxicity = 0;
        $obscene = 0;
        $threat = 0;
        $insult = 0;
        $identityAttack = 0;
        $sexualExplicit = 0;
        if ($resp && $httpCode < 300) {
            $mod = json_decode($resp, true);
            if ($mod) {
                $toxicity = (float)($mod['toxicity'] ?? 0);
                $aiScore = (float)($mod['ai_score'] ?? 0);
                $severeToxicity = (float)($mod['severe_toxicity'] ?? 0);
                $obscene = (float)($mod['obscene'] ?? 0);
                $threat = (float)($mod['threat'] ?? 0);
                $insult = (float)($mod['insult'] ?? 0);
                $identityAttack = (float)($mod['identity_attack'] ?? 0);
                $sexualExplicit = (float)($mod['sexual_explicit'] ?? 0);
            }
        }

        // Extract keywords (tblip)
        $ch2 = curl_init("http://{$clip_host}:{$clip_port}/extract_keywords");
        curl_setopt_array($ch2, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['text' => $plain, 'max_keywords' => 10]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 30,
        ]);
        $resp2 = curl_exec($ch2);
        curl_close($ch2);

        $textDesc = '';
        if ($resp2) {
            $kw = json_decode($resp2, true);
            if ($kw && isset($kw['keywords'])) {
                $textDesc = substr(implode(', ', $kw['keywords']), 0, 500);
            }
        }

        $textUpdate->execute([$toxicity, $aiScore, $severeToxicity, $obscene, $threat, $insult, $identityAttack, $sexualExplicit, $textDesc, $board, $no]);
        $textProcessed++;

        echo "  [{$board}/{$no}] tblip:{$textDesc} toxic:{$toxicity} severe:{$severeToxicity} obscene:{$obscene} threat:{$threat} insult:{$insult} identity:{$identityAttack} sexual:{$sexualExplicit} ai:{$aiScore}\n";

        if ($textProcessed % 25 === 0) {
            echo "--- Text progress: {$textProcessed}/{$textCount} ---\n";
        }
    }

    $textOffset += $batchSize;
}

echo "Text posts done: {$textProcessed}\n\n";

// --- Phase 3: Context scoring for replies ---
echo "=== Phase 3: Context scoring for replies ===\n";

$ctxWhere = $forceAll
    ? "WHERE resto > 0 AND com != '' AND LENGTH(com) >= 10"
    : "WHERE resto > 0 AND com != '' AND LENGTH(com) >= 10 AND clip_context_toxicity = 0";

$ctxCount = (int)$pdo->query("SELECT COUNT(*) FROM posts {$ctxWhere}")->fetchColumn();
echo "Replies to context-score: {$ctxCount}\n";

$ctxUpdate = $pdo->prepare(
    "UPDATE posts SET clip_context_toxicity = ? WHERE board = ? AND no = ?"
);

$opCache = [];

$ctxProcessed = 0;
$ctxErrors = 0;
$ctxOffset = 0;

while ($ctxOffset < $ctxCount) {
    $rows = $pdo->query(
        "SELECT board, no, resto, com FROM posts {$ctxWhere} ORDER BY no ASC LIMIT {$batchSize} OFFSET {$ctxOffset}"
    )->fetchAll(PDO::FETCH_ASSOC);

    foreach ($rows as $row) {
        $board = $row['board'];
        $no = $row['no'];
        $resto = (int)$row['resto'];
        $plain = html_entity_decode(strip_tags($row['com']), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        if (strlen($plain) < 10) {
            $ctxProcessed++;
            continue;
        }

        // Get OP text (cached)
        $opKey = "{$board}:{$resto}";
        if (!isset($opCache[$opKey])) {
            $opRow = $pdo->query("SELECT com FROM posts WHERE board = '{$board}' AND no = {$resto}")->fetch(PDO::FETCH_ASSOC);
            $opCache[$opKey] = $opRow ? html_entity_decode(trim(strip_tags($opRow['com'])), ENT_QUOTES | ENT_HTML5, 'UTF-8') : '';
        }
        $opText = $opCache[$opKey];

        // Build context: [OP] + [Reply]
        $parts = [];
        if ($opText) {
            $parts[] = '[OP]: ' . mb_substr($opText, 0, 200);
        }

        // Parse >>NNN references
        if (preg_match_all('/&gt;&gt;(\d+)/', $row['com'], $m)) {
            $quoteNos = array_unique(array_slice($m[1], 0, 3));
            if ($quoteNos) {
                $ph = implode(',', $quoteNos);
                $qRows = $pdo->query("SELECT no, com FROM posts WHERE board = '{$board}' AND no IN({$ph})")->fetchAll(PDO::FETCH_ASSOC);
                $perQuote = (int)(150 / count($quoteNos));
                foreach ($qRows as $qr) {
                    $qtxt = html_entity_decode(trim(strip_tags($qr['com'])), ENT_QUOTES | ENT_HTML5, 'UTF-8');
                    if ($qtxt) $parts[] = '[>>' . $qr['no'] . ']: ' . mb_substr($qtxt, 0, $perQuote);
                }
            }
        }

        $parts[] = '[Reply]: ' . mb_substr($plain, 0, 150);

        if (count($parts) < 2) {
            $ctxProcessed++;
            continue;
        }

        $contextStr = implode("\n", $parts);

        // Call /moderate_context
        $ch = curl_init("http://{$clip_host}:{$clip_port}/moderate_context");
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['text' => $plain, 'context' => $contextStr]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 30,
        ]);
        $resp = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $ctxToxicity = 0;
        if ($resp && $httpCode < 300) {
            $mod = json_decode($resp, true);
            if ($mod && isset($mod['context']['toxicity'])) {
                $ctxToxicity = (float)$mod['context']['toxicity'];
            }
        } else {
            $ctxErrors++;
        }

        $ctxUpdate->execute([$ctxToxicity, $board, $no]);
        $ctxProcessed++;

        $delta = isset($mod['delta']['toxicity']) ? sprintf('%+.4f', $mod['delta']['toxicity']) : 'n/a';
        echo "  [{$board}/{$no}] ctx_toxic:{$ctxToxicity} delta:{$delta}\n";

        if ($ctxProcessed % 25 === 0) {
            echo "--- Context progress: {$ctxProcessed}/{$ctxCount} (errors: {$ctxErrors}) ---\n";
        }
    }

    $ctxOffset += $batchSize;
}

echo "Context scoring done: {$ctxProcessed}, Errors: {$ctxErrors}\n";
echo "\nAll retagging complete.\n";
