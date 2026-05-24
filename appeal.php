<?
// Ban Appeal submission page
// Allows banned users to submit an appeal for their active ban

include_once "yotsuba_config.php";
require_once 'lib/db.php';

if (!defined('SQLLOGBAN')) define('SQLLOGBAN', 'banned_users');

$ip = $_SERVER['REMOTE_ADDR'];

// Get global DB via DBAL
$db = YotsubaDB::global();

// Find active bans for this IP
$query = $db->query(
  "SELECT no, board, global, reason, admin,
  UNIX_TIMESTAMP(now) as starts_on,
  UNIX_TIMESTAMP(length) as ends_on
  FROM " . $db->qi(SQLLOGBAN) . "
  WHERE active = 1 AND host = ?
  ORDER BY no DESC", [$ip]
);

$bans = array();
while ($row = $query->fetch(PDO::FETCH_ASSOC)) {
  $bans[] = $row;
}

// --- Handle appeal submission ---
$message = '';
$message_type = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['submit_appeal'])) {
  if (empty($bans)) {
    $message = 'You are not currently banned.';
    $message_type = 'error';
  } else {
    $ban_id = (int)$_POST['ban_id'];
    $appeal_text = trim($_POST['appeal_text']);

    // Validate ban_id belongs to this IP
    $valid_ban = false;
    foreach ($bans as $b) {
      if ((int)$b['no'] === $ban_id) {
        $valid_ban = true;
        break;
      }
    }

    if (!$valid_ban) {
      $message = 'Invalid ban selected.';
      $message_type = 'error';
    } else if (strlen($appeal_text) < 5) {
      $message = 'Appeal text is too short (minimum 5 characters).';
      $message_type = 'error';
    } else if (strlen($appeal_text) > 2000) {
      $message = 'Appeal text is too long (maximum 2000 characters).';
      $message_type = 'error';
    } else {
      // Check for existing pending appeal on this ban
      $existing = $db->query(
        "SELECT id FROM {$db->qi('ban_appeals')} WHERE ban_id = ? AND ip = ? AND status = 'pending' LIMIT 1",
        [$ban_id, $ip]
      );

      if ($existing->rowCount() > 0) {
        $message = 'You already have a pending appeal for this ban. Please wait for a moderator to review it.';
        $message_type = 'warning';
      } else {
        $result = $db->query(
          "INSERT INTO {$db->qi('ban_appeals')} (ban_id, ip, appeal_text) VALUES (?, ?, ?)",
          [$ban_id, $ip, $appeal_text]
        );

        if ($result) {
          $message = 'Your appeal has been submitted and will be reviewed by a moderator.';
          $message_type = 'success';
        } else {
          $message = 'Failed to submit appeal. Please try again later.';
          $message_type = 'error';
        }
      }
    }
  }
}

// --- Check for previous appeals ---
$past_appeals = array();
if (!empty($bans)) {
  $ban_ids = array();
  foreach ($bans as $b) {
    $ban_ids[] = (int)$b['no'];
  }
  $ban_ids_str = implode(',', $ban_ids);

  $appeals_q = $db->query(
    "SELECT * FROM {$db->qi('ban_appeals')} WHERE ban_id IN ($ban_ids_str) AND ip = ? ORDER BY created_at DESC",
    [$ip]
  );

  while ($row = $appeals_q->fetch(PDO::FETCH_ASSOC)) {
    $past_appeals[] = $row;
  }
}

// --- Render page ---
?>
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-type" content="text/html; charset=utf-8">
<title>Ban Appeal</title>
<style type="text/css">
body {
  font-family: arial, helvetica, sans-serif;
  font-size: 13px;
  background: #EEF2FF;
  color: #000;
  margin: 0;
  padding: 20px;
}
h2 {
  color: #AF0A0F;
  font-size: 18px;
  margin-bottom: 5px;
}
h3 {
  color: #34345C;
  font-size: 14px;
  margin: 15px 0 8px;
}
.container {
  max-width: 700px;
  margin: 0 auto;
}
.msg-success {
  background: #D4EDDA;
  border: 1px solid #C3E6CB;
  color: #155724;
  padding: 10px;
  margin-bottom: 15px;
}
.msg-error {
  background: #F8D7DA;
  border: 1px solid #F5C6CB;
  color: #721C24;
  padding: 10px;
  margin-bottom: 15px;
}
.msg-warning {
  background: #FFF3CD;
  border: 1px solid #FFEEBA;
  color: #856404;
  padding: 10px;
  margin-bottom: 15px;
}
table {
  border-collapse: collapse;
  width: 100%;
  margin-bottom: 15px;
}
td, th {
  border: 1px solid #B7C5D9;
  padding: 5px 8px;
  font-size: 12px;
  text-align: left;
}
th {
  background: #D6DAF0;
  font-weight: bold;
  white-space: nowrap;
  width: 120px;
}
textarea {
  width: 100%;
  box-sizing: border-box;
  font-family: arial, helvetica, sans-serif;
  font-size: 12px;
  padding: 5px;
}
input[type=submit] {
  padding: 6px 18px;
  cursor: pointer;
  font-size: 13px;
}
.appeal-box {
  background: #D6DAF0;
  border: 1px solid #B7C5D9;
  padding: 12px;
  margin-bottom: 15px;
}
.appeal-status {
  display: inline-block;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: bold;
  border-radius: 3px;
}
.status-pending { background: #FFF3CD; color: #856404; }
.status-approved { background: #D4EDDA; color: #155724; }
.status-denied { background: #F8D7DA; color: #721C24; }
.not-banned {
  text-align: center;
  padding: 40px;
  color: #666;
}
.footer-links {
  margin-top: 20px;
  font-size: 12px;
  color: #666;
}
.footer-links a { color: #34345C; }
</style>
</head>
<body>
<div class="container">

<h2>Ban Appeal</h2>

<?
if ($message) {
  echo '<div class="msg-' . $message_type . '">' . htmlspecialchars($message) . '</div>';
}

if (empty($bans)) {
?>
<div class="not-banned">
<p><b>You are not currently banned.</b></p>
<p>Your IP: <?= htmlspecialchars($ip) ?></p>
<p>If you believe this is an error, try clearing your cookies and reloading.</p>
</div>
<?
} else {
  // Show each active ban
  foreach ($bans as $ban) {
    $ban_no = (int)$ban['no'];
    $reasons = explode('<>', $ban['reason']);
    $pub_reason = $reasons[0] ?: '(no reason given)';
    $scope = $ban['global'] ? 'Global' : ('/' . htmlspecialchars($ban['board']) . '/ only');

    $ends_on = (int)$ban['ends_on'];
    if ($ends_on == 0) {
      $expiry = '<b style="color:red">Permanent</b>';
    } else {
      $expiry = date('M j, Y g:i A', $ends_on);
      $remaining = $ends_on - time();
      if ($remaining > 0) {
        $days_left = floor($remaining / 86400);
        $hours_left = floor(($remaining % 86400) / 3600);
        $expiry .= " ($days_left day" . ($days_left != 1 ? 's' : '') . ", $hours_left hour" . ($hours_left != 1 ? 's' : '') . " remaining)";
      }
    }

    $banned_on = date('M j, Y g:i A', (int)$ban['starts_on']);

    // Check if there's already a pending appeal for this ban
    $has_pending = false;
    foreach ($past_appeals as $pa) {
      if ((int)$pa['ban_id'] === $ban_no && $pa['status'] === 'pending') {
        $has_pending = true;
        break;
      }
    }
?>

<div class="appeal-box">
<h3>Ban #<?= $ban_no ?></h3>
<table>
<tr><th>Reason</th><td><?= htmlspecialchars($pub_reason) ?></td></tr>
<tr><th>Scope</th><td><?= $scope ?></td></tr>
<tr><th>Banned on</th><td><?= $banned_on ?></td></tr>
<tr><th>Expires</th><td><?= $expiry ?></td></tr>
<tr><th>Your IP</th><td><?= htmlspecialchars($ip) ?></td></tr>
</table>

<?
    if ($has_pending) {
      echo '<p style="color:#856404"><b>Appeal pending.</b> A moderator will review your appeal. Please be patient.</p>';
    } else {
?>
<form method="post" action="appeal.php">
<input type="hidden" name="ban_id" value="<?= $ban_no ?>">
<p><b>Write your appeal:</b> (max 2000 characters)</p>
<textarea name="appeal_text" rows="5" maxlength="2000" placeholder="Explain why you believe your ban should be lifted..."></textarea>
<br><br>
<input type="submit" name="submit_appeal" value="Submit Appeal">
</form>
<?
    }
?>
</div>

<?
  } // end foreach bans

  // Show past appeals
  if (!empty($past_appeals)) {
?>
<h3>Your Appeal History</h3>
<table>
<tr style="background:#D6DAF0"><th>Ban #</th><th>Submitted</th><th>Status</th><th>Your Appeal</th><th>Mod Response</th></tr>
<?
    foreach ($past_appeals as $appeal) {
      $status_class = 'status-' . $appeal['status'];
      $status_label = ucfirst($appeal['status']);
      $appeal_text = htmlspecialchars(substr($appeal['appeal_text'], 0, 200));
      if (strlen($appeal['appeal_text']) > 200) $appeal_text .= '...';
      $mod_resp = $appeal['mod_response'] ? htmlspecialchars($appeal['mod_response']) : '-';
      $submitted = htmlspecialchars($appeal['created_at']);
?>
<tr>
<td><?= (int)$appeal['ban_id'] ?></td>
<td style="font-size:11px"><?= $submitted ?></td>
<td><span class="appeal-status <?= $status_class ?>"><?= $status_label ?></span></td>
<td style="font-size:11px"><?= $appeal_text ?></td>
<td style="font-size:11px"><?= $mod_resp ?></td>
</tr>
<?
    }
?>
</table>
<?
  } // end past appeals
} // end has bans
?>

<div class="footer-links">
[<a href="/">Home</a>]
</div>

</div>
</body>
</html>
