<?
$pages = array(
    'blotter' => array('title' => 'Blotter', 'db' => true),
    'faq' => array('title' => 'Frequently Asked Questions'),
    'rules' => array('title' => 'Rules'),
    'legal' => array('title' => 'Legal'),
    'contact' => array('title' => 'Contact'),
    'feedback' => array('title' => 'Feedback'),
    'advertise' => array('title' => 'Advertise'),
    'search' => array('title' => 'Search'),
);

$page = basename($_SERVER['REQUEST_URI']);
$page = preg_replace('/\?.*/', '', $page);
if (!isset($pages[$page])) $page = 'faq';
$info = $pages[$page];

if (!empty($info['db'])) {
    require_once '/var/www/html/yotsuba_config.php';
    require_once 'lib/db.php';
}
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>4chan - <?= htmlspecialchars($info['title']) ?></title>
<style>
body { background: #FFFFEE; font-family: arial, helvetica, sans-serif; margin: 0; }
.boardlist { background: #D6DAF0; border-bottom: 1px solid #B7C5D9; padding: 4px; font-size: 12px; text-align: center; }
.content { max-width: 800px; margin: 0 auto; padding: 20px; }
h1 { font-size: 24px; color: #AF0A0F; }
h2 { font-size: 16px; color: #AF0A0F; border-bottom: 1px solid #D9BFB7; padding-bottom: 4px; }
a { color: #34345C; }
.footer { text-align: center; font-size: 11px; color: #999; margin: 30px 0 10px; padding: 10px; border-top: 1px solid #D9BFB7; }
.info-links { text-align: center; font-size: 12px; margin: 10px 0; }
.blotter-entry { margin: 8px 0; padding: 8px; background: #F0E0D6; }
.blotter-date { color: #789922; font-size: 12px; }
.rule { margin: 6px 0; }
.rule b { color: #117743; }
#search-form input[type=text] { width: 400px; padding: 6px; font-size: 14px; }
#search-form input[type=submit] { padding: 6px 20px; }
</style>
</head>
<body>
<div class="boardlist">
[<a href="/">Home</a>]
[<a href="/b/">Random</a>]
[<a href="/faq">FAQ</a>]
[<a href="/rules">Rules</a>]
</div>
<div class="content">
<h1><?= htmlspecialchars($info['title']) ?></h1>
<?
switch ($page):
case 'blotter':
    $db = YotsubaDB::global();
    $res = $db->query("SELECT message, created FROM {$db->qi('blotter')} ORDER BY id DESC LIMIT 20");
    if ($res && $res->rowCount() > 0):
        while ($row = $res->fetch(PDO::FETCH_ASSOC)):
?>
<div class="blotter-entry">
<span class="blotter-date"><?= htmlspecialchars($row['created']) ?></span><br>
<?= $row['message'] ?>
</div>
<?
        endwhile;
    else:
        echo '<p>No blotter entries.</p>';
    endif;
    break;

case 'faq':
?>
<h2>What is 4chan?</h2>
<p>4chan is a simple image-based bulletin board where anyone can post comments and share images anonymously.</p>
<h2>How do I post?</h2>
<p>Click [Reply] on a thread to post a reply, or use the form at the top of a board page to create a new thread. You must include an image when creating a new thread.</p>
<h2>Do I need to register?</h2>
<p>No. Anyone can post on 4chan without registering an account.</p>
<h2>What are tripcodes?</h2>
<p>A tripcode is a hashed password appended to the user's name. Put a # in the name field followed by a password to generate one (e.g., "User#password").</p>
<h2>Why was my post deleted?</h2>
<p>Posts that violate the rules are deleted by moderators. See the <a href="/rules">Rules</a> page for details.</p>
<?
    break;

case 'rules':
?>
<h2>Global Rules</h2>
<div class="rule"><b>1.</b> You will not upload, post, discuss, request, or link to anything that violates local or United States law.</div>
<div class="rule"><b>2.</b> You will immediately cease and not continue to access the site if you are under the age of 18.</div>
<div class="rule"><b>3.</b> You will not post any of the following outside of /b/: Trolls, flames, racism, off-topic replies, uncalled for catchphrases, macro image replies, indecipherable text, or similar.</div>
<div class="rule"><b>4.</b> No spamming or flooding of any kind.</div>
<div class="rule"><b>5.</b> No advertising or affiliate links.</div>
<div class="rule"><b>6.</b> Boards have their own specific rules and guidelines — check the board page before posting.</div>
<p><i>These are simplified rules for a local instance. See the original 4chan rules page for the full text.</i></p>
<?
    break;

case 'legal':
?>
<p>This is a local development/research instance of the 4chan imageboard engine.</p>
<p>4chan and the Yotsuba engine are the property of 4chan LLC.</p>
<?
    break;

case 'contact':
?>
<h2>Contact</h2>
<p>This is a local instance. There is no one to contact.</p>
<?
    break;

case 'feedback':
?>
<h2>Feedback</h2>
<p>This is a local instance.</p>
<?
    break;

case 'advertise':
?>
<h2>Advertise on 4chan</h2>
<p>This is a local instance. Advertising is not available.</p>
<?
    break;

case 'search':
?>
<h2>Search</h2>
<form id="search-form" action="/search" method="get">
<input type="text" name="q" placeholder="Search posts..." value="<?= htmlspecialchars($_GET['q'] ?? '') ?>">
<input type="submit" value="Search">
</form>
<p><i>Search is not yet implemented in this local instance.</i></p>
<?
    break;

endswitch;
?>

<div class="info-links">
<a href="/">Home</a> |
<a href="/faq">FAQ</a> |
<a href="/rules">Rules</a> |
<a href="/legal">Legal</a> |
<a href="/contact">Contact</a>
</div>
<div class="footer">4chan Yotsuba</div>
</div>
</body>
</html>
