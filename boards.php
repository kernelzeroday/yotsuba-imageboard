<?php
require_once 'yotsuba_config.php';

header('Content-Type: application/json');
header('Cache-Control: public, max-age=60');

$db = YotsubaDB::global();
$res = $db->query("SELECT dir, name, title, description, section FROM {$db->qi('boardlist')} ORDER BY section, dir");

$boards = array();
$config_base = defined('YOTSUBA_DIR') ? YOTSUBA_DIR . '/config/boards/' : '/var/www/html/config/boards/';

while ($row = $res->fetch(PDO::FETCH_ASSOC)) {
    $board = array(
        'board' => $row['dir'],
        'title' => $row['name'],
        'meta_description' => $row['description'] ?: $row['title'] ?: '',
    );

    $ini_file = $config_base . $row['dir'] . '.config.ini';
    if (file_exists($ini_file)) {
        $ini = @parse_ini_file($ini_file);
        if ($ini) {
            if (isset($ini['CATEGORY'])) {
                $board['ws_board'] = ($ini['CATEGORY'] === 'ws') ? 1 : 0;
            }
            if (isset($ini['MAX_RES'])) $board['bump_limit'] = (int)$ini['MAX_RES'];
            if (isset($ini['MAX_IMGRES'])) $board['image_limit'] = (int)$ini['MAX_IMGRES'];
            if (isset($ini['MAX_COM_CHARS'])) $board['max_comment_chars'] = (int)$ini['MAX_COM_CHARS'];
            if (isset($ini['MAX_KB'])) $board['max_filesize'] = (int)$ini['MAX_KB'] * 1024;
            if (isset($ini['PAGE_MAX'])) $board['pages'] = (int)$ini['PAGE_MAX'];
            if (isset($ini['DEF_PAGES'])) $board['per_page'] = (int)$ini['DEF_PAGES'];
        }
    }

    $boards[] = $board;
}

echo json_encode(array('boards' => $boards), JSON_UNESCAPED_UNICODE);
