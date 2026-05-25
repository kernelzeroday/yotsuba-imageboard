<?php
$tag_slug = $_GET['tag'] ?? '';
$tag = str_replace('-', ' ', urldecode($tag_slug));

if (!$tag) {
    $mode = 'index';
} else {
    $mode = 'tag';
}

$host = getenv('YOTSUBA_PG_HOST') ?: 'pgdb';
$port = getenv('YOTSUBA_PG_PORT') ?: '5432';
$user = getenv('YOTSUBA_PG_USER') ?: 'yotsuba';
$pass = getenv('YOTSUBA_PG_PASS') ?: 'yotsuba';
$name = getenv('YOTSUBA_PG_NAME') ?: 'yotsuba';

$dsn = "pgsql:host={$host};port={$port};dbname={$name}";
$pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

if ($mode === 'index') {
    $stmt = $pdo->query("SELECT clip_desc, clip_text_desc FROM posts WHERE (clip_desc IS NOT NULL AND clip_desc != '') OR (clip_text_desc IS NOT NULL AND clip_text_desc != '')");
    $tag_counts = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        foreach (['clip_desc', 'clip_text_desc'] as $col) {
            if (empty($row[$col])) continue;
            $tags = array_map('trim', explode(',', $row[$col]));
            foreach ($tags as $t) {
                if ($t === '') continue;
                $tag_counts[$t] = ($tag_counts[$t] ?? 0) + 1;
            }
        }
    }
    arsort($tag_counts);
    render_index($tag_counts);
} else {
    $stmt = $pdo->prepare(
        "SELECT no, board, sub, com, tim, ext, tn_w, tn_h, fsize, time, clip_desc, clip_text_desc, resto, name
         FROM posts
         WHERE (clip_desc LIKE ? OR clip_text_desc LIKE ?) AND filedeleted = 0
         ORDER BY time DESC
         LIMIT 200"
    );
    $stmt->execute(["%{$tag}%", "%{$tag}%"]);
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $related = [];
    if ($posts) {
        $matched_nos = array_map(function($p) { return (int)$p['no']; }, $posts);
        $ph = implode(',', array_fill(0, count($matched_nos), '?'));
        $avg_stmt = $pdo->prepare(
            "SELECT AVG(clip_vector) as avg_vec FROM posts WHERE no IN($ph) AND clip_vector IS NOT NULL"
        );
        $avg_stmt->execute($matched_nos);
        $avg_row = $avg_stmt->fetch(PDO::FETCH_ASSOC);
        if ($avg_row && $avg_row['avg_vec']) {
            $exclude_ph = implode(',', array_fill(0, count($matched_nos), '?'));
            $rel_stmt = $pdo->prepare(
                "SELECT no, board, sub, com, tim, ext, tn_w, tn_h, fsize, time, clip_desc, clip_text_desc, resto, name,
                        clip_vector <=> ?::vector AS distance
                 FROM posts
                 WHERE clip_vector IS NOT NULL AND no NOT IN($exclude_ph) AND filedeleted = 0
                 ORDER BY clip_vector <=> ?::vector
                 LIMIT 20"
            );
            $params = array_merge([$avg_row['avg_vec']], $matched_nos, [$avg_row['avg_vec']]);
            $rel_stmt->execute($params);
            $related = $rel_stmt->fetchAll(PDO::FETCH_ASSOC);
        }
    }
    render_tagboard($tag, $posts, $related);
}

function tag_slug($tag) {
    return str_replace(' ', '-', trim($tag));
}

function render_index($tag_counts) {
    $title = 'Tag Index';
    $body = '<div class="tagIndex">';
    $body .= '<h2>All Tags</h2>';
    $body .= '<div class="tagCloud">';
    $max = max($tag_counts ?: [1]);
    foreach ($tag_counts as $tag => $count) {
        $slug = tag_slug($tag);
        $size = max(14, min(48, 14 + (34 * $count / $max)));
        $body .= '<a href="/tag/' . htmlspecialchars($slug) . '" class="tagLink" style="font-size:' . $size . 'px">'
            . htmlspecialchars($tag) . ' <span class="tagCount">(' . $count . ')</span></a> ';
    }
    $body .= '</div>';
    $body .= '<hr>';
    $body .= '<h3>Tags by Count</h3>';
    $body .= '<table class="tagTable"><thead><tr><th>Tag</th><th>Posts</th></tr></thead><tbody>';
    foreach ($tag_counts as $tag => $count) {
        $slug = tag_slug($tag);
        $body .= '<tr><td><a href="/tag/' . htmlspecialchars($slug) . '">' . htmlspecialchars($tag) . '</a></td>';
        $body .= '<td>' . $count . '</td></tr>';
    }
    $body .= '</tbody></table>';
    $body .= '</div>';
    render_page($title, $body);
}

function render_tagboard($tag, $posts, $related = []) {
    $title = htmlspecialchars($tag);
    $count = count($posts);

    $body = '<div class="tagBoard">';
    $body .= '<h2><a href="/tags">Tags</a> &rsaquo; ' . $title . '</h2>';
    $body .= '<p class="tagMeta">' . $count . ' post' . ($count !== 1 ? 's' : '') . ' tagged with <strong>' . $title . '</strong></p>';
    $body .= '<hr>';
    $body .= '<div class="tagCatalog">';

    foreach ($posts as $post) {
        $no = (int)$post['no'];
        $board = htmlspecialchars($post['board']);
        $tim = htmlspecialchars($post['tim']);
        $ext = htmlspecialchars($post['ext']);
        $tn_w = (int)$post['tn_w'];
        $tn_h = (int)$post['tn_h'];
        $fsize = (int)$post['fsize'];
        $thread = $post['resto'] ? (int)$post['resto'] : $no;
        $sub = $post['sub'] ? htmlspecialchars($post['sub']) : '';
        $com = $post['com'] ? html_entity_decode(strip_tags($post['com']), ENT_QUOTES | ENT_HTML5, 'UTF-8') : '';
        if (mb_strlen($com) > 150) $com = mb_substr($com, 0, 150) . '...';
        $com = htmlspecialchars($com, ENT_NOQUOTES, 'UTF-8');

        $thread_url = "/{$board}/thread/{$thread}" . ($post['resto'] ? "#p{$no}" : '');
        $thumb_url = "/thumbs/{$board}/{$tim}s.jpg";
        $img_url = "/images/{$board}/{$tim}{$ext}";

        $size_str = $fsize > 1048576 ? round($fsize / 1048576, 1) . ' MB' : round($fsize / 1024) . ' KB';

        $tags_html = '';
        $all_tag_links = [];
        foreach (['clip_desc', 'clip_text_desc'] as $tcol) {
            if (!empty($post[$tcol])) {
                $tags = array_map('trim', explode(',', $post[$tcol]));
                foreach ($tags as $t) {
                    if ($t === '') continue;
                    $slug = tag_slug($t);
                    $all_tag_links[] = '<a href="/tag/' . htmlspecialchars($slug) . '" class="inlineTag">' . htmlspecialchars($t) . '</a>';
                }
            }
        }
        if ($all_tag_links) {
            $tags_html = '<div class="postTags">' . implode(', ', $all_tag_links) . '</div>';
        }

        $has_file = ($ext && $fsize > 0);

        $body .= '<div class="tagCard">';
        if ($has_file) {
            $body .= '<a href="' . $thread_url . '" class="cardThumb">';
            if ($tn_w && $tn_h) {
                $body .= '<img src="' . $thumb_url . '" width="' . $tn_w . '" height="' . $tn_h . '" loading="lazy">';
            }
            $body .= '</a>';
        }
        $body .= '<div class="cardMeta">';
        $body .= '<a href="' . $thread_url . '" class="cardLink">/' . $board . '/ No.' . $no . '</a>';
        if ($sub) $body .= '<div class="cardSub">' . $sub . '</div>';
        if ($has_file) {
            $body .= '<div class="cardInfo">' . $size_str . ' ' . strtoupper(ltrim($ext, '.')) . '</div>';
        } else {
            $body .= '<div class="cardInfo">Text post</div>';
        }
        if ($com) $body .= '<div class="cardCom">' . $com . '</div>';
        $body .= $tags_html;
        $body .= '</div>';
        $body .= '</div>';
    }

    $body .= '</div>';

    if ($related) {
        $body .= '<hr><h3>Semantically Related Posts</h3>';
        $body .= '<div class="tagCatalog">';
        foreach ($related as $post) {
            $no = (int)$post['no'];
            $board = htmlspecialchars($post['board']);
            $tim = htmlspecialchars($post['tim']);
            $ext = htmlspecialchars($post['ext']);
            $tn_w = (int)$post['tn_w'];
            $tn_h = (int)$post['tn_h'];
            $fsize = (int)$post['fsize'];
            $thread = $post['resto'] ? (int)$post['resto'] : $no;
            $com = $post['com'] ? html_entity_decode(strip_tags($post['com']), ENT_QUOTES | ENT_HTML5, 'UTF-8') : '';
            if (mb_strlen($com) > 150) $com = mb_substr($com, 0, 150) . '...';
            $com = htmlspecialchars($com, ENT_NOQUOTES, 'UTF-8');
            $dist = isset($post['distance']) ? number_format((float)$post['distance'], 4) : '';

            $thread_url = "/{$board}/thread/{$thread}" . ($post['resto'] ? "#p{$no}" : '');
            $thumb_url = "/thumbs/{$board}/{$tim}s.jpg";
            $has_file = ($ext && $fsize > 0);

            $body .= '<div class="tagCard">';
            if ($has_file) {
                $body .= '<a href="' . $thread_url . '" class="cardThumb">';
                if ($tn_w && $tn_h) {
                    $body .= '<img src="' . $thumb_url . '" width="' . $tn_w . '" height="' . $tn_h . '" loading="lazy">';
                }
                $body .= '</a>';
            }
            $body .= '<div class="cardMeta">';
            $body .= '<a href="' . $thread_url . '" class="cardLink">/' . $board . '/ No.' . $no . '</a>';
            if ($dist) $body .= '<div class="cardInfo">distance: ' . $dist . '</div>';
            if ($com) $body .= '<div class="cardCom">' . $com . '</div>';
            $all_tag_links = [];
            foreach (['clip_desc', 'clip_text_desc'] as $tcol) {
                if (!empty($post[$tcol])) {
                    foreach (array_map('trim', explode(',', $post[$tcol])) as $t) {
                        if ($t === '') continue;
                        $all_tag_links[] = '<a href="/tag/' . htmlspecialchars(tag_slug($t)) . '" class="inlineTag">' . htmlspecialchars($t) . '</a>';
                    }
                }
            }
            if ($all_tag_links) $body .= '<div class="postTags">' . implode(', ', $all_tag_links) . '</div>';
            $body .= '</div></div>';
        }
        $body .= '</div>';
    }

    $body .= '</div>';
    render_page("Tag: {$title}", $body);
}

function render_page($title, $body) {
    $css = <<<'CSS'
<style>
body { font-family: arial, helvetica, sans-serif; font-size: 13px; background: #EEF2FF; color: #000; margin: 0; padding: 0; }
a { color: #34345C; text-decoration: none; }
a:hover { color: #DD0000; }
.pageHeader { background: #D6DAF0; border-bottom: 1px solid #B7C5D9; padding: 8px 16px; }
.pageHeader h1 { margin: 0; font-size: 20px; display: inline; }
.pageHeader .navLinks { float: right; margin-top: 4px; }
.pageContent { max-width: 1200px; margin: 0 auto; padding: 16px; }
h2 { font-size: 18px; color: #34345C; margin: 0 0 8px; }
h3 { font-size: 14px; margin: 16px 0 8px; }
.tagMeta { color: #666; margin: 0 0 8px; }
.tagCloud { line-height: 2.2; }
.tagCloud .tagLink { display: inline-block; padding: 2px 8px; margin: 2px; background: #D6DAF0; border-radius: 3px; }
.tagCloud .tagLink:hover { background: #B7C5D9; }
.tagCount { font-size: 11px; color: #666; }
.tagTable { border-collapse: collapse; width: 100%; max-width: 600px; }
.tagTable th, .tagTable td { padding: 4px 12px; border-bottom: 1px solid #D6DAF0; text-align: left; }
.tagTable th { background: #D6DAF0; font-weight: bold; }
.tagCatalog { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 12px; }
.tagCard { background: #D6DAF0; border: 1px solid #B7C5D9; border-radius: 4px; overflow: hidden; }
.tagCard:hover { border-color: #34345C; }
.cardThumb { display: block; text-align: center; background: #C5CAE0; min-height: 100px; }
.cardThumb img { max-width: 100%; height: auto; display: block; margin: 0 auto; }
.cardMeta { padding: 6px 8px; }
.cardLink { font-weight: bold; font-size: 12px; }
.cardSub { font-weight: bold; color: #0F0C5D; margin-top: 2px; font-size: 12px; }
.cardInfo { font-size: 11px; color: #666; margin-top: 2px; }
.cardCom { font-size: 12px; color: #333; margin-top: 4px; word-break: break-word; }
.postTags { margin-top: 4px; font-size: 11px; }
.inlineTag { background: #EEF2FF; padding: 1px 4px; border-radius: 2px; }
.inlineTag:hover { background: #B7C5D9; }
hr { border: none; border-top: 1px solid #B7C5D9; margin: 12px 0; }
</style>
CSS;

    echo <<<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{$title} - 4chan Tagboard</title>
<link rel="shortcut icon" href="/static/image/favicon-ws.ico">
{$css}
</head>
<body>
<div class="pageHeader">
<h1><a href="/tags">Tagboard</a></h1>
<span class="navLinks">
[<a href="/">Home</a>]
[<a href="/tags">All Tags</a>]
</span>
</div>
<div class="pageContent">
{$body}
</div>
</body>
</html>
HTML;
}
