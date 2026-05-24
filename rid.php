<?php

$title_dir = '/www/4chan.org/web/static/image/title';
$names = @file($title_dir . '/files.txt', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

if (!$names) {
	$arr = scandir($title_dir);
	$names = [];
	foreach ($arr as $fi) {
		if (preg_match("/\.(jpg|gif|png)$/i", $fi)) {
			$names[] = $fi;
		}
	}
	file_put_contents($title_dir . '/files.txt', implode("\n", $names));
}

if ($names) {
	header("Location: /static/image/title/" . trim($names[array_rand($names)]));
} else {
	http_response_code(404);
}
?>
