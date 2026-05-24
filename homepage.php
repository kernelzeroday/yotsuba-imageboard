<?
require_once '/var/www/html/yotsuba_config.php';
require_once 'lib/db.php';

$section_order = array(
    'jpculture' => array('label' => 'Japanese Culture', 'sections' => array(1), 'nsfw' => false),
    'vidya'     => array('label' => 'Video Games',      'sections' => array(2), 'nsfw' => false),
    'interests' => array('label' => 'Interests',        'sections' => array(3), 'nsfw' => false),
    'creative'  => array('label' => 'Creative',         'sections' => array(4), 'nsfw' => false),
    'other'     => array('label' => 'Other',            'sections' => array(5, 6), 'nsfw' => false),
    'misc'      => array('label' => 'Misc.',            'sections' => array(5), 'nsfw' => true),
    'adult'     => array('label' => 'Adult',            'sections' => array(7, 8), 'nsfw' => true),
);

$db = YotsubaDB::global();

$boards_by_section = array();
$res = $db->query("SELECT dir, name, section FROM {$db->qi('boardlist')} WHERE hidden = 0 ORDER BY section, dir");
while ($row = $res->fetch(PDO::FETCH_ASSOC)) {
    $s = (int)$row['section'];
    $boards_by_section[$s][] = $row;
}

$blotter_entries = array();
$bres = $db->query("SELECT message, created FROM {$db->qi('blotter')} ORDER BY id DESC LIMIT 5");
while ($brow = $bres->fetch(PDO::FETCH_ASSOC)) {
    $blotter_entries[] = $brow;
}

$news_entries = array();
$nres = $db->query("SELECT id, subject, author, body, created FROM {$db->qi('news_entries')} ORDER BY created DESC LIMIT 10");
while ($nrow = $nres->fetch(PDO::FETCH_ASSOC)) {
    $news_entries[] = $nrow;
}

$banner_files = glob('/www/4chan.org/web/static/image/title/*');
$banner_url = '';
if ($banner_files) {
    $pick = $banner_files[array_rand($banner_files)];
    $banner_url = '/static/image/title/' . basename($pick);
}

$total_posts = 0;
$boards_res = $db->query("SELECT dir FROM {$db->qi('boardlist')} WHERE hidden = 0 ORDER BY dir");
$board_dirs = array();
while ($brow = $boards_res->fetch(PDO::FETCH_ASSOC)) {
    $board_dirs[] = $brow['dir'];
}

foreach ($board_dirs as $bd) {
    try {
        $cnt = $db->query("SELECT COUNT(*) FROM {$db->qi($bd)}");
        $total_posts += (int)$cnt->fetchColumn();
    } catch (PDOException $e) {}
}

$sfw_sections = array(1, 2, 3, 4);
$nsfw_other = array(5, 6);
$nsfw_adult = array(7, 8);

$latest_posts = array();
foreach ($board_dirs as $bd) {
    try {
        $lres = $db->query(
            "SELECT no, sub, com, name, time, resto FROM {$db->qi($bd)} ORDER BY no DESC LIMIT 5"
        );
        while ($lr = $lres->fetch(PDO::FETCH_ASSOC)) {
            $lr['board'] = $bd;
            $latest_posts[] = $lr;
        }
    } catch (PDOException $e) {}
}
usort($latest_posts, function($a, $b) { return $b['time'] - $a['time']; });
$latest_posts = array_slice($latest_posts, 0, 15);
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="4chan is a simple image-based bulletin board where anyone can post comments and share images anonymously.">
<title>4chan</title>
<link rel="shortcut icon" href="/static/image/favicon.ico">
<link rel="stylesheet" type="text/css" href="/static/css/frontpage.12.css">
</head>
<body>
<div id="doc">
  <div id="hd">
    <div id="logo-fp">
      <a href="/" title="Home"><img alt="4chan" src="<?= $banner_url ?: '/static/image/fp/logo-transparent.png' ?>" width="300" height="120"></a>
    </div>
  </div>
<div id="bd">
  <div class="box-outer" id="announce">
    <div class="box-inner">
      <div class="boxbar">
        <h2>What is 4chan?</h2>
      </div>
      <div class="boxcontent">
        <div id="wot-cnt"><p>4chan is a simple image-based bulletin board where anyone can post comments and share images. There are boards dedicated to a variety of topics, from Japanese animation and culture to videogames, music, and photography. Users do not need to register an account before participating in the community. Feel free to click on a board below that interests you and jump right in!</p><br><p>Be sure to familiarize yourself with the <a href="/rules">Rules</a> before posting, and read the <a href="/faq" title="Frequently Asked Questions">FAQ</a> if you wish to learn more about how to use the site.</p></div>
      </div>
    </div>
  </div>

<div class="box-outer top-box" id="boards">
  <div class="box-inner">
    <div class="boxbar">
      <h2>Boards</h2>
    </div>
    <div class="boxcontent">
      <div class="column">
<h3 style="text-decoration: underline; display: inline;">Japanese Culture</h3>
<ul>
<?
if (isset($boards_by_section[1])):
    foreach ($boards_by_section[1] as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endif; ?>
</ul>
<h3 style="text-decoration: underline; display: inline;">Video Games</h3>
<ul>
<?
if (isset($boards_by_section[2])):
    foreach ($boards_by_section[2] as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endif; ?>
</ul>
</div>
      <div class="column">
<h3 style="text-decoration: underline; display: inline;">Interests</h3>
<ul>
<?
if (isset($boards_by_section[3])):
    foreach ($boards_by_section[3] as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endif; ?>
</ul>
</div>
      <div class="column">
<h3 style="text-decoration: underline; display: inline;">Creative</h3>
<ul>
<?
if (isset($boards_by_section[4])):
    foreach ($boards_by_section[4] as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endif; ?>
</ul>
</div>
      <div class="column">
<h3 style="text-decoration: underline; display: inline;">Other</h3>
<ul>
<?
$other_boards = array();
if (isset($boards_by_section[5])) {
    foreach ($boards_by_section[5] as $b) {
        if (in_array($b['dir'], array('b','r9k','pol','bant','soc','s4s'))) continue;
        $other_boards[] = $b;
    }
}
if (isset($boards_by_section[6])) {
    foreach ($boards_by_section[6] as $b) {
        $other_boards[] = $b;
    }
}
foreach ($other_boards as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<? endforeach; ?>
</ul>
<h3 style="text-decoration: underline; display: inline;">Misc.</h3> <h3 style="display: inline;"><span class="warning" title="Not Safe For Work"><sup style="vertical-align: text-bottom;">(NSFW)</sup></span></h3>
<ul>
<?
$misc_dirs = array('b','r9k','pol','bant','soc','s4s');
if (isset($boards_by_section[5])):
    foreach ($boards_by_section[5] as $b):
        if (!in_array($b['dir'], $misc_dirs)) continue;
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endif; ?>
</ul>
</div>
      <div class="column">
<h3 style="text-decoration: underline; display: inline;">Adult</h3> <h3 style="display: inline;"><span class="warning" title="Not Safe For Work"><sup style="vertical-align: text-bottom;">(NSFW)</sup></span></h3>
<ul>
<?
$adult_sections = array(7, 8);
foreach ($adult_sections as $sec):
    if (!isset($boards_by_section[$sec])) continue;
    foreach ($boards_by_section[$sec] as $b):
?>
<li><a href="/<?= htmlspecialchars($b['dir']) ?>/" class="boardlink"><?= htmlspecialchars($b['name']) ?></a></li>
<?  endforeach; endforeach; ?>
</ul>
</div>
<br class="clear-bug">
    </div>
  </div>
</div>

<? if (!empty($news_entries)): ?>
<div class="box-outer top-box" id="site-news">
  <div class="box-inner">
    <div class="boxbar">
      <h2>News</h2>
    </div>
    <div class="boxcontent">
<? foreach ($news_entries as $nentry): ?>
      <div class="news-entry" style="margin-bottom: 1em; padding-bottom: 1em; border-bottom: 1px dashed #ccc;">
        <h3 style="margin: 0 0 .25em 0; font-size: 110%; font-weight: bold;"><?= htmlspecialchars($nentry['subject']) ?></h3>
        <div class="news-meta" style="color: #707070; font-size: 90%; margin-bottom: .5em;">
          by <span style="color: #117743; font-weight: bold;"><?= htmlspecialchars($nentry['author']) ?></span>
          &mdash; <?= date('m/d/y(D)H:i', strtotime($nentry['created'])) ?>
        </div>
        <div class="news-body"><?= nl2br(str_replace('\n', "\n", $nentry['body'])) ?></div>
      </div>
<? endforeach; ?>
    </div>
  </div>
</div>
<? endif; ?>

<? if (!empty($blotter_entries)): ?>
<div class="box-outer top-box" id="blotter">
  <div class="box-inner">
    <div class="boxbar">
      <h2>Blotter</h2>
    </div>
    <div class="boxcontent">
<? foreach ($blotter_entries as $entry): ?>
      <p><strong><?= date('m/d/y', strtotime($entry['created'])) ?></strong> &mdash; <?= $entry['message'] ?></p>
<? endforeach; ?>
    </div>
  </div>
</div>
<? endif; ?>

<? if (!empty($latest_posts)): ?>
<div class="box-outer top-box" id="latest-posts">
  <div class="box-inner">
    <div class="boxbar">
      <h2>Latest Posts</h2>
    </div>
    <div class="boxcontent">
      <table style="width:100%;border-collapse:collapse;">
      <tr style="border-bottom:1px solid #ccc;"><th style="text-align:left;padding:2px 6px;">Board</th><th style="text-align:left;padding:2px 6px;">Post</th><th style="text-align:left;padding:2px 6px;">Date</th></tr>
<? foreach ($latest_posts as $lp):
    $lp_board = htmlspecialchars($lp['board']);
    $lp_no = (int)$lp['no'];
    $lp_resto = (int)$lp['resto'];
    $lp_thread = $lp_resto ? $lp_resto : $lp_no;
    $lp_link = "/{$lp_board}/thread/{$lp_thread}#p{$lp_no}";
    $lp_text = '';
    if ($lp['sub']) {
        $lp_text = strip_tags($lp['sub']);
    } elseif ($lp['com']) {
        $lp_text = strip_tags(str_replace('<br>', ' ', $lp['com']));
    }
    if (mb_strlen($lp_text) > 80) $lp_text = mb_substr($lp_text, 0, 80) . '...';
    if (!$lp_text) $lp_text = 'No.' . $lp_no;
    $lp_date = date('m/d H:i', $lp['time']);
?>
      <tr style="border-bottom:1px solid #eee;"><td style="padding:2px 6px;"><a href="/<?= $lp_board ?>/">>/<?= $lp_board ?>/</a></td><td style="padding:2px 6px;"><a href="<?= $lp_link ?>"><?= htmlspecialchars($lp_text) ?></a></td><td style="padding:2px 6px;white-space:nowrap;"><?= $lp_date ?></td></tr>
<? endforeach; ?>
      </table>
    </div>
  </div>
</div>
<? endif; ?>

<div class="box-outer top-box" id="site-stats">
  <div class="box-inner">
    <div class="boxbar">
      <h2>Stats</h2>
    </div>
    <div class="boxcontent">
      <div class="stat-cell"><b>Total Posts:</b> <?= number_format($total_posts) ?></div>
<div class="stat-cell"><b>Active Boards:</b> <?= count($board_dirs) ?></div>
<div class="stat-cell"><b>Status:</b> Online</div>
    </div>
  </div>
</div>

</div>
<div id="ft"><ul><li class="fill">
</li><li class="first"><a href="/">Home</a></li>
<li><a href="/blotter">News</a></li>
<li><a href="/faq">FAQ</a></li>
<li><a href="/rules">Rules</a></li>
<li><a href="/advertise">Advertise</a></li>
</ul>
<br class="clear-bug">
<div id="copyright"><a href="/faq#what4chan">About</a> &bull; <a href="/feedback">Feedback</a> &bull; <a href="/legal">Legal</a> &bull; <a href="/contact">Contact</a><br><br>
    Copyright &copy; 2003-2025 4chan community support LLC. All rights reserved.
    </div>
  </div>
</div>

</body>
</html>
