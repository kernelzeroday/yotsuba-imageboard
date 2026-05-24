<?php

	function report_get_style($board) {
		$styles = array(
					'Yotsuba' => STATIC_SERVER.'css/yotsuba.css',
					'Yotsuba B' => STATIC_SERVER.'css/yotsublue.css',
					'Futaba' => STATIC_SERVER.'css/futaba.css',
					'Burichan' => STATIC_SERVER.'css/burichan.css',
					);
		$db = YotsubaDB::global();
		$query = $db->query("SELECT domain FROM boardlist WHERE dir = ?", [$board]);
		$row = $query->fetch(PDO::FETCH_NUM);
		$domain = $row ? $row[0] : null;
		if(DEFAULT_BURICHAN == 1)
			$styletitle = ($_COOKIE['ws_style']?$_COOKIE['ws_style']:'Yotsuba B');
		elseif($domain == 'may')
			$styletitle = 'not4chan';
		else
			$styletitle = ($_COOKIE['nws_style']?$_COOKIE['nws_style']:'Yotsuba');
		return $styles[$styletitle];
	}

function log_cleared_reporter($long_ip, $pwd, $pass_id, $cat_id, $weight) {
  $db = YotsubaDB::global();
  return !!$db->query(
    "INSERT INTO report_clear_log(long_ip, pwd, pass_id, category, weight) VALUES(?, ?, ?, ?, ?)",
    [(int)$long_ip, (string)$pwd, (string)$pass_id, (int)$cat_id, (float)$weight]
  );
}

function report_can_bypass_captcha($ip, $userpwd, $post) {
  if (!$userpwd || !$post) {
    return false;
  }

  if ($userpwd->ipLifetime() < 604800) { // 7 days
    return false;
  }

  if (!$post['fsize']) { // only posts with images
    return false;
  }

  $allowance = 3;

  $long_ip = ip2long($ip);

  if (!$long_ip) {
    return false;
  }

  $db = YotsubaDB::global();

  // Allow $allowance no-captcha reports for every hour of inactivity
  $res = $db->query(
    "SELECT COUNT(*) as cnt FROM user_actions WHERE ip = ? AND action = 'report' AND time > DATE_SUB(NOW(), INTERVAL 1 HOUR)",
    [$long_ip]
  );

  $row = $res->fetch(PDO::FETCH_NUM);

  if (!$row || $row[0] >= $allowance) {
    return false;
  }

  // Don't allow ips with 1 cleared reports in the past 72 hours
  $res = $db->query(
    "SELECT COUNT(*) FROM report_clear_log WHERE long_ip = ? AND created_on > DATE_SUB(NOW(), INTERVAL 72 HOUR)",
    [$long_ip]
  );

  $count = (int)$res->fetch(PDO::FETCH_NUM)[0];

  if ($count >= 1) {
    return false;
  }

  // Don't allow ips with recent warn/ban history
  $res = $db->query(
    "SELECT no FROM banned_users WHERE host = ? AND now > DATE_SUB(NOW(), INTERVAL 30 DAY) LIMIT 1",
    [$ip]
  );

  if ($res->rowCount() > 0) {
    return false;
  }

  return true;
}

  function report_check_ip($board, $no, $check_ban = false, $is_illegal = false) {
    global $captcha_bypass, $passid;

    $db = YotsubaDB::global();

    $no = (int)$no;

    $ip = ip2long($_SERVER['REMOTE_ADDR']);

    $pass_sql = false;

    $pwd_sql = false;

    // Check if already reported
    // by IP
    $rep_clauses = array("ip = ?");
    $rep_params = array($ip);

    // by 4chan pass
    if ($captcha_bypass && $passid) {
      $pass_sql = $passid;
      $rep_clauses[] = "4pass_id = ?";
      $rep_params[] = $pass_sql;
    }

    // by password
    $userpwd = UserPwd::getSession();

    if ($userpwd && $userpwd->getPwd()) {
      $pwd_sql = $userpwd->getPwd();
      $rep_clauses[] = "pwd = ?";
      $rep_params[] = $pwd_sql;
    }

    $rep_clauses_sql = implode(' OR ', $rep_clauses);

    $res = $db->query(
      "SELECT no FROM reports WHERE ($rep_clauses_sql) AND board = ? AND no = ?",
      array_merge($rep_params, [$board, $no])
    );

    if ($res->rowCount() > 0) {
      fancydie('You have already reported this post.');
    }

    // Check cooldown
    $res = $db->query(
      "SELECT no FROM reports WHERE ($rep_clauses_sql) AND ts > DATE_SUB(NOW(), INTERVAL 15 SECOND) LIMIT 1",
      $rep_params
    );

    if ($res->rowCount() > 0) {
      fancydie('You have to wait a while before reporting another post.');
    }

    // Check hourly limits
    $res = $db->query(
      "SELECT COUNT(*) FROM reports WHERE ($rep_clauses_sql) AND ts > DATE_SUB(NOW(), INTERVAL 1 HOUR) LIMIT 1",
      $rep_params
    );

    if ($res->fetch(PDO::FETCH_NUM)[0] >= RENZOKU_REP_HOURLY) {
      fancydie('You have to wait a while before reporting another post.');
    }

    // Check daily limits
    $res = $db->query(
      "SELECT COUNT(*) FROM reports WHERE ($rep_clauses_sql) AND ts > DATE_SUB(NOW(), INTERVAL 24 HOUR) LIMIT 1",
      $rep_params
    );

    if ($res->fetch(PDO::FETCH_NUM)[0] >= RENZOKU_REP_DAILY) {
      fancydie('You have to wait a while before reporting another post.');
    }

    // Check if banned
    if ($check_ban) {
      // by ip
      $ban_clauses = array("host = ?");
      $ban_params = array($_SERVER['REMOTE_ADDR']);

      // by 4chan pass
      if ($pass_sql) {
        $ban_clauses[] = "4pass_id = ?";
        $ban_params[] = $pass_sql;
      }

      // by password
      if ($pwd_sql) {
        $ban_clauses[] = "password = ?";
        $ban_params[] = $pwd_sql;
      }

      $ban_clauses_sql = implode(' OR ', $ban_clauses);

      $res = $db->query(
        "SELECT COUNT(*) FROM banned_users WHERE ($ban_clauses_sql) AND active = 1 AND (global = 1 OR board = ?)",
        array_merge($ban_params, [$board])
      );

      if ($res->fetch(PDO::FETCH_NUM)[0] > 0) {
        fancydie('You can\'t report posts because you are <a href="https://www.' .
          L::d(BOARD_DIR) .
          '/banned" target="_blank">banned</a>.');
      }

      if ($captcha_bypass !== true) {
        $longip = ip2long($_SERVER['REMOTE_ADDR']);

        if (isset($_SERVER['HTTP_X_GEO_ASN'])) {
          $asn = (int)$_SERVER['HTTP_X_GEO_ASN'];
        }
        else {
          $_asninfo = GeoIP2::get_asn($_SERVER['REMOTE_ADDR']);

          if ($_asninfo) {
            $asn = (int)$_asninfo['asn'];
          }
          else {
            $asn = 0;
          }
        }

        if (isIPRangeBannedReport($longip, $asn, BOARD_DIR, $userpwd)) {
          fancydie('Reporting from this IP range has been blocked due to abuse. [<a href="//www.' .
            L::d(BOARD_DIR) .
            '/faq#blocked" target="_blank">More Info</a>]<br>4chan Pass users can bypass this block. [<a href="https://www.4chan.org/pass" target="_blank">Learn More</a>]');
        }
      }
    }
  }

	function report_increment_counter() {
		return; // broken lol
		$count = @file_get_contents('reports/report.count');
		if(!$count) $count = 0;
		$count++;
		file_put_contents('reports/report.count',$count);
	}

	function report_post_exists($no) {
		$db = YotsubaDB::board();
		$tbl = $db->qi(SQLLOG);
		$res = $db->query("SELECT COUNT(*) FROM $tbl WHERE no = ?", [(int)$no]);
		return $res->fetch(PDO::FETCH_NUM)[0];
	}

	function report_is_capcoded_post( $no )
	{
		$db = YotsubaDB::board();
		$tbl = $db->qi(SQLLOG);
		$res = $db->query("SELECT COUNT(*) FROM $tbl WHERE capcode != 'none' AND no = ?", [(int)$no]);
		return $res->fetch(PDO::FETCH_NUM)[0];
	}

	function report_check_autodelete($board,$no) {
		$db = YotsubaDB::global();
		$res = $db->query("SELECT COUNT(*) FROM reports WHERE board = ? AND no = ?", [$board, (int)$no]);
		$count = $res->fetch(PDO::FETCH_NUM)[0];

		if(defined('REPORTS_AUTODELETE') && $count >= REPORTS_AUTODELETE) {
			report_do_autodelete($board,$no,1);
			return;
		}

		$res = $db->query("SELECT COUNT(*) FROM reports WHERE cat = '2' AND board = ? AND no = ?", [$board, (int)$no]);
		$count = $res->fetch(PDO::FETCH_NUM)[0];
		if(defined('REPORTS_AUTODELETE_ILLEGAL') && $count >= REPORTS_AUTODELETE_ILLEGAL) {
			report_do_autodelete($board,$no,2);
			return;
		}
	}
	function report_do_autodelete($board,$no,$cat) {
		$db_board = YotsubaDB::board();
		$db_global = YotsubaDB::global();
		$tbl = $db_board->qi(SQLLOG);
		$res = $db_board->query("SELECT * FROM $tbl WHERE no = ?", [(int)$no]);
		$row = $res->fetch(PDO::FETCH_ASSOC);
		if(!$row) return;
		$auser = 'Auto-del';
		$adfsize=($row['fsize']>0)?1:0;
		$adname=str_replace('</span> <span class="postertrip">!','#',$row['name']);
		$imgonly = 0;
		$del_tbl = $db_global->qi(SQLLOGDEL);
		$db_global->query(
			"INSERT INTO $del_tbl (imgonly,postno,board,name,sub,com,img,filename,admin) VALUES(?,?,?,?,?,?,?,?,?)",
			[$imgonly, (int)$no, SQLLOG, $adname, $row['sub'], $row['com'], $adfsize, $row['filename'], $auser]
		);
		delete_post($no, '', 0, 1, 1);
	}
	function report_log_action($board,$no) {
		$db = YotsubaDB::global();
		$db->query(
			"INSERT INTO user_actions (ip,board,action,postno,time) VALUES (?,?,'report',?,NOW())",
			[ip2long($_SERVER["REMOTE_ADDR"]), $board, (int)$no]
		);
	}

	function report_post_sticky($no) {
		$db = YotsubaDB::board();
		$tbl = $db->qi(SQLLOG);
		$res = $db->query("SELECT sticky FROM $tbl WHERE no = ?", [(int)$no]);
		return $res->fetch(PDO::FETCH_NUM)[0];
	}

function report_check_post($board, $post_id) {
  $db = YotsubaDB::board();
  $tbl = $db->qi($board);

  $res = $db->query("SELECT * FROM $tbl WHERE no = ?", [(int)$post_id]);

  if (!$res) {
    fancydie(S_POST_DEAD);
  }

  $post = $res->fetch(PDO::FETCH_ASSOC);

  if (!$post) {
    fancydie(S_POST_DEAD);
  }

  if ($post['sticky']) {
    fancydie(S_CANNOTREPORTSTICKY);
  }

  if ($post['capcode'] !== 'none') {
    fancydie(S_CANNOTREPORT);
  }

  return $post;
}

function get_report_categories($board, $post_id, $is_worksafe) {
  $db = YotsubaDB::global();
  $db_board = YotsubaDB::board();

  $res = $db->query("SELECT * FROM report_categories ORDER BY board ASC");

  if (!$res) {
    return false;
  }

  $tbl = $db_board->qi($board);
  $res2 = $db_board->query("SELECT resto, fsize, filedeleted FROM $tbl WHERE no = ?", [(int)$post_id]);

  if (!$res2) {
    return false;
  }

  $post = $res2->fetch(PDO::FETCH_ASSOC);

  if (!$post) {
    return false;
  }

  $is_op = !$post['resto'];
  $has_image = $post['fsize'] && !$post['filedeleted'];

  // ID of the category which will be used for the Illegal radio button
  $illegal_cat_id = 31;

  // Rule violations + one illegal category
  $data = array('rule' => null, 'illegal' => null);

  // Sorting, board specific categories go on top
  $data_rule_top = array();
  $data_rule_bottom = array();

  $match_board = ',' . $board . ',';

  while ($cat = $res->fetch(PDO::FETCH_ASSOC)) {
    if ($cat['id'] == $illegal_cat_id) {
      $data['illegal'] = $cat;
      continue;
    }

    if ($cat['board'] !== '') {
      if ($cat['board'] === '_ws_') {
        if (!$is_worksafe) {
          continue;
        }
      }
      else if ($cat['board'] === '_nws_') {
        if ($is_worksafe) {
          continue;
        }
      }
      else if ($cat['board'] !== $board) {
        continue;
      }
    }

    if ($cat['op_only'] && !$is_op) {
      continue;
    }

    if ($cat['reply_only'] && $is_op) {
      continue;
    }

    if ($cat['image_only'] && !$has_image) {
      continue;
    }

    if ($cat['exclude_boards'] && strpos(",{$cat['exclude_boards']},", $match_board) !== false) {
      continue;
    }

    if ($cat['board']) {
      $data_rule_top[$cat['id']] = $cat;
    }
    else {
      $data_rule_bottom[$cat['id']] = $cat;
    }
  }

  $data['rule'] = $data_rule_top + $data_rule_bottom;

  return $data;
}

/**
 * Checks if the report should have a different priority
 * based on the number of cleared reports in the past X days and ban history.
 */
function is_report_filtered($filter_thres, $ip, $long_ip, $pass_id = null, $pwd = null) {
  if ($filter_thres < 1) {
    return false;
  }

  // only count reports made in the past X days
  $cleared_days_lim = 2;
  // number of cleared reports for the IP to be considered 'abusive'
  $cleared_count_lim = (int)$filter_thres;
  // only count bans made in the past X days
  $ban_days_lim = 30;
  // number of bans/warnings for the IP to be considered 'abusive'
  $ban_count_lim = 3;

  $rep_abuse_tpl = 190; // ban template for report abusing

  $long_ip = (int)$long_ip;

  $db = YotsubaDB::global();

  $ban_clauses = array();
  $ban_params = array();
  $rep_clauses = array();
  $rep_params = array();

  // 4chan Pass
  if ($pass_id) {
    $ban_clauses[] = array("4pass_id = ?", [$pass_id]);
    $rep_clauses[] = array("pass_id = ?", [$pass_id]);

    $pwd_and_ban = "4pass_id != ?";
    $pwd_and_ban_param = $pass_id;
    $pwd_and_rep = "pass_id != ?";
    $pwd_and_rep_param = $pass_id;
  }
  // IP
  else {
    $ban_clauses[] = array("host = ?", [$ip]);
    $rep_clauses[] = array("long_ip = ?", [$long_ip]);

    $pwd_and_ban = "host != ?";
    $pwd_and_ban_param = $ip;
    $pwd_and_rep = "long_ip != ?";
    $pwd_and_rep_param = $long_ip;
  }

  // Password
  if ($pwd) {
    $ban_clauses[] = array("password = ? AND $pwd_and_ban", [$pwd, $pwd_and_ban_param]);
    $rep_clauses[] = array("pwd = ? AND $pwd_and_rep", [$pwd, $pwd_and_rep_param]);
  }

  // ---
  // Check cleared reports
  // ---
  $clear_count = 0;

  foreach ($rep_clauses as $clause_data) {
    list($clause, $params) = $clause_data;

    $res = $db->query(
      "SELECT COUNT(*) FROM report_clear_log WHERE $clause AND created_on > DATE_SUB(NOW(), INTERVAL $cleared_days_lim DAY)",
      $params
    );

    $clear_count += (int)$res->fetch(PDO::FETCH_NUM)[0];

    if ($clear_count >= $cleared_count_lim) {
      return true;
    }
  }

  // ---
  // Check ban history
  // ---
  $ban_count = 0;

  foreach ($ban_clauses as $clause_data) {
    list($clause, $params) = $clause_data;

    $res = $db->query(
      "SELECT COUNT(*) FROM banned_users WHERE active = 0 AND $clause AND template_id = $rep_abuse_tpl AND now > DATE_SUB(NOW(), INTERVAL $ban_days_lim DAY)",
      $params
    );

    $ban_count += (int)$res->fetch(PDO::FETCH_NUM)[0];

    if ($ban_count >= $ban_count_lim) {
      return true;
    }
  }

  return false;
}

function report_get_rel_sub($board, $thread_id) {
  if (!$board || !$thread_id) {
    return '';
  }

  $thread_id = (int)$thread_id;

  $db = YotsubaDB::board();
  $tbl = $db->qi($board);

  $res = $db->query("SELECT sub FROM $tbl WHERE no = ?", [$thread_id]);

  if ($res->rowCount() !== 1) {
    return '';
  }

  return $res->fetch(PDO::FETCH_NUM)[0];
}

function report_submit($board, $no, $cat_id) {
  global $log, $passid;

  $db = YotsubaDB::global();
  $no = (int)$no;
  $long_ip = ip2long($_SERVER['REMOTE_ADDR']);

  // check if the category is valid
  $cats = get_report_categories($board, $no, DEFAULT_BURICHAN == 1);

  if ($cats['illegal']['id'] == $cat_id) {
    $old_cat = 2; // todo: remove later
    $old_field = 'num_illegal'; // todo: remove later
    $rep_cat = $cats['illegal'];
  }
  else if (isset($cats['rule'][$cat_id])) {
    $old_cat = 1;
    $old_field = 'num_rule';
    $rep_cat = $cats['rule'][$cat_id];
  }
  else {
    fancydie('Invalid category selected.');
  }

  if (!$no) {
    fancydie(S_POST_DEAD);
  }

  log_cache(0, $no, 2);

  if ($log[$no]['archived']) {
    $extra = array('archived' => 1);
  }
  else {
    $extra = array();
  }

  $resto = (int)$log[$no]['resto'];

  $post_data = generate_post_json($log[$no], $log[$no]['resto'] ? $log[$no]['resto'] : $no, $extra);

  if ($log[$no]['resto']) {
    $rel_sub = report_get_rel_sub($board, $log[$no]['resto']);

    if ($rel_sub !== '') {
      $post_data['rel_sub'] = $rel_sub;
    }
  }

  $json = json_encode($post_data);

  $weight = $rep_cat['weight'];

  $is_staff = has_level('janitor');

  $req_sig = spam_filter_get_req_sig();

  $userpwd = UserPwd::getSession();

  if ($userpwd) {
    $pwd = $userpwd->getPwd();
    $is_new_pwd = $userpwd->isNew();
    $is_known_pwd = $userpwd->isUserKnownOrVerified(60);
  }
  else {
    $pwd = null;
    $is_new_pwd = true;
    $is_known_pwd = false;
  }

  if (!$is_staff) {
    $ignore_reason = 0;

    $_threat_score = spam_filter_get_threat_score(null, true, false);

    if (!$is_known_pwd) {
      $ignore_reason = 1;
    }
    else if ($_threat_score >= 0.4) {
      $ignore_reason = 2;
    }
    else if ($rep_cat['filtered']) {
      if (is_report_filtered($rep_cat['filtered'], $_SERVER['REMOTE_ADDR'], $long_ip, $passid, $is_new_pwd ? null : $pwd)) {
        $ignore_reason = 3;
      }
    }
  }

  if ($ignore_reason > 0) {
    $weight = 0.5;
    if ($ignore_reason == 2) {
      $_bot_headers = spam_filter_format_http_headers($log[$no]['com'], '', '', $_threat_score, $req_sig);
      log_spam_filter_trigger('ignore_report_score', BOARD_DIR, $no, $_SERVER['REMOTE_ADDR'], $ignore_reason, $_bot_headers);
    }
  }

  // Check if the post was already reported and cleared
  $is_cleared = 0;
  $cleared_by = '';

  $res = $db->query(
    "SELECT cleared_by FROM reports WHERE board = ? AND no = ? AND cleared = 1 LIMIT 1",
    [$board, $no]
  );

  $row = $res->fetch(PDO::FETCH_NUM);

  if ($row) {
    $is_cleared = 1;
    $cleared_by = $row[0];
    log_cleared_reporter($long_ip, $pwd, $passid, $rep_cat['id'], $weight);
  }

  $is_ws = DEFAULT_BURICHAN == 1 ? 1 : 0;

  $res = $db->query(
    "INSERT IGNORE INTO reports SET ip = ?, pwd = ?, 4pass_id = ?, req_sig = ?, board = ?, no = ?, resto = ?, cat = ?, weight = ?, report_category = ?, ws = ?, post_ip = ?, post_json = ?, cleared = ?, cleared_by = ?",
    [
      (int)$long_ip, (string)$pwd, (string)$passid, (string)$req_sig, $board, $no, $resto,
      $old_cat, (float)$weight, (int)$rep_cat['id'], $is_ws, ip2long($log[$no]['host']), $json, $is_cleared, (string)$cleared_by
    ]
  );

  if (!$res) {
    fancydie('There was an error submitting your report. Please try again.');
  }

  // Use raw SQL for the upsert since old_field is dynamic
  $old_field_qi = $db->qi($old_field);
  $res = $db->query(
    "INSERT INTO `reports_for_posts` (`board`, `postid`, `threadid`, $old_field_qi, `max_cat`) VALUES (?, ?, ?, 1, ?) ON DUPLICATE KEY UPDATE $old_field_qi = $old_field_qi + 1, max_cat = IF(num_illegal >= num_rule, 2, 1)",
    [$board, $no, $resto, $old_cat]
  );

  report_log_action($board, $no);

  if ($userpwd) {
    $userpwd->updateReportActivity();
    $userpwd->setCookie('.' . MAIN_DOMAIN);
  }

  fancydie('Report submitted! This window will close in 3 seconds...', 1);
}
