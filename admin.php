<?
include_once "yotsuba_config.php";
require_once 'lib/util.php';
/*
if( isset( $_REQUEST["profile"] ) ) {
	xhprof_enable( XHPROF_FLAGS_CPU | XHPROF_FLAGS_MEMORY );
	register_shutdown_function( "xhprof_save" );
}
if ( isset($_REQUEST["sqlprofile"] )) {
	$mysql_query_log = YES;
}
*/
if( TEST_BOARD ) {
  ini_set('display_errors', '1');
	if( isset( $_REQUEST[ "profile" ] ) ) {
		xhprof_enable();
		register_shutdown_function( "xhprof_save" );
	}
}

include_once 'lib/rpc.php';
include_once 'lib/admin.php';
include_once 'lib/auth.php';
include_once 'lib/json.php';
include_once 'lib/geoip2.php';

//include "strings_e.php";		//String resource file
if (!defined('SQLLOGBAN')) define( 'SQLLOGBAN', 'banned_users' ); //Table (NOT DATABASE) used for holding banned users
if (!defined('SQLLOGMOD')) define( 'SQLLOGMOD', 'mod_users' ); //Table (NOT DATABASE) used for holding mod users
if (!defined('SQLLOGDEL')) define( 'SQLLOGDEL', 'del_log' ); //Table (NOT DATABASE) used for holding deletion log

extract( $_POST, EXTR_SKIP );
extract( $_GET, EXTR_SKIP );
extract( $_COOKIE, EXTR_SKIP );

//if( isset( $_REQUEST['id'] ) ) $id = $_REQUEST['id']; // weird bug?

if( isset( $_POST[ 'id' ] ) && ctype_digit( $_POST[ 'id' ] ) ) $id = $_POST[ 'id' ];
if( isset( $_GET[ 'id' ] ) && ctype_digit( $_GET[ 'id' ] ) ) $id = $_GET[ 'id' ];

if( isset($argv[1]) && $argv[1] ) $admin = $argv[1];
if( !isset($admin) ) $admin = isset($_GET['admin']) ? $_GET['admin'] : (isset($_POST['admin']) ? $_POST['admin'] : '');

// FIXME whitelist
unset( $dest );
unset( $log );
unset( $update_avg_secs );

$access_allow = '';
$access_deny  = '';

mysql_board_connect( BOARD_DIR );

function janitor_votes_left()
{
	$user = $_COOKIE[ '4chan_auser' ];

	$db = YotsubaDB::global();
	$res = $db->query("SELECT count(id) FROM {$db->qi('janitor_votes')} WHERE moderator = ?", [$user]);
	$high = $res->fetch(PDO::FETCH_NUM)[0];

	$res = $db->query("SELECT COUNT(id) FROM {$db->qi('janitor_apps')} WHERE closed = 0 AND age > 17");

	return $res->fetch(PDO::FETCH_NUM)[0] - $high;
}

function append_ban( $board, $ip )
{
	// run in background
	$cmd = "nohup /usr/local/bin/suid_run_global bin/appendban $board $ip >/dev/null 2>&1 &";
	print "User banned from /$board/";
//	print $cmd . "<br>"; //disabling this because it's ugly and leaks filepaths
	exec( $cmd );
}

function https_self_url()
{
	return "/".BOARD_DIR."/admin";
}

// for lib/admin.php
function delete_uploaded_files()
{

}

function make_post_json($row)
{
	$nrow = array();

	foreach( $row as $key => $val ) {
		if( ctype_digit( $val ) || is_int( $val ) ) {
			$val = (int)$val;
		}

		$nrow[ $key ] = $val;
	}
	
	return json_encode( $nrow );
}

function get_board_list() {
  $db = YotsubaDB::global();

  $res = $db->query("SELECT dir, name FROM {$db->qi('boardlist')} ORDER BY dir ASC");

  $boards = array();

  while ($dir = $res->fetch(PDO::FETCH_NUM)) {
    $boards[$dir[0]] = $dir[1];
  }

  return $boards;
}

function is_board_valid($board, $allow_hidden = false) {
  if (!$allow_hidden && ($board === 'test' || $board === 'j')) {
    return false;
  }

  $db = YotsubaDB::global();
  $res = $db->query("SELECT dir FROM {$db->qi('boardlist')} WHERE dir = ? LIMIT 1", [$board]);

  if ($res->rowCount() === 1) {
    return true;
  }

  return false;
}

function admin_clear_reports($board, $post_id) {
  $db = YotsubaDB::global();

  $db->query("UPDATE {$db->qi('reports')} SET cleared = 1 WHERE board = ? AND no = ?", [$board, (int)$post_id]);

  $db->query("UPDATE {$db->qi('reports_for_posts')} SET cleared = 1, clearedby = 'Auto-clear' WHERE board = ? AND postid = ?", [$board, (int)$post_id]);
}

function get_bans_summary($value, $by_pass = false) {
	if (!$value) {
		return array();
	}
	
  if ($by_pass === false) {
    $col = 'host';
    $col_active = '';
  }
  else {
    $col = '4pass_id';
    $col_active = '(active = 0 OR active = 1) AND '; // pass column doesn't have an index for itself
  }
  
  $db = YotsubaDB::global();
  $ut_now = $db->unixTimestamp($db->qi('now'));
  $ut_length = $db->unixTimestamp($db->qi('length'));
  $ut_unbanned = $db->unixTimestamp($db->qi('unbannedon'));

  $res = $db->query("SELECT {$ut_now} as created_on, {$ut_length} as expires_on, {$ut_unbanned} as unbanned_on FROM {$db->qi('banned_users')} WHERE {$col_active}{$db->qi($col)} = ?", [$value]);
  
  $limit = $_SERVER['REQUEST_TIME'] - 31536000; // 1 year
  
  $total_count = $res->rowCount();
  $recent_perma_count = 0;
  $recent_ban_count = 0;
  $recent_warn_count = 0;
  $recent_duration = 0; // in days
  
  while ($ban = $res->fetch(PDO::FETCH_ASSOC)) {
    if ($ban['created_on'] < $limit) {
      continue;
    }
    
    if (!$ban['expires_on']) {
      ++$recent_perma_count;
      continue;
    }
    
    $ban_len = $ban['expires_on'] - $ban['created_on'];
    
    if ($ban_len <= 10) {
      ++$recent_warn_count;
    }
    else {
      if ($ban['unbanned_on']) {
        $spent_len = $ban['unbanned_on'] - $ban['created_on'];
        
        if ($spent_len > $ban_len) {
          $spent_len = $ban_len;
        }
      }
      else {
        $spent_len = $ban_len;
      }
      
      $recent_duration += $spent_len;
      ++$recent_ban_count;
    }
  }
  
  if ($recent_duration) {
    $recent_duration = round($recent_duration / 86400.0);
  }
  
  return array(
    'total' => $total_count,
    'recent_bans' => $recent_ban_count,
    'recent_warns' => $recent_warn_count,
    'recent_days' => $recent_duration,
    'recent_permas' => $recent_perma_count
  );
}

// Counts recently made threads by IP
function admin_get_thread_history($ip) {
	$long_ip = ip2long($ip);
	
	if (!$long_ip) {
		return false;
	}
	
	$db = YotsubaDB::global();
	$date_sub = $db->dateInterval('NOW()', 60, 'MINUTE');
	$res = $db->query("SELECT COUNT(*) FROM {$db->qi('user_actions')} WHERE action = 'new_thread' AND ip = ? AND time >= {$date_sub}", [$long_ip]);

	return (int)$res->fetch(PDO::FETCH_NUM)[0];
}

function admin_hash_4chan_pass($pass) {
  $salt = file_get_contents(SALTFILE);
  
  if (!$salt || !$pass) {
    return '';
  }
  
  return sha1($pass . $salt);
}

function get_ban_history_html($ban_summary, $host = false) {
  $ban_tip = array();
  
  if ($ban_summary['recent_bans'] > 0) {
    $ban_tip[] = $ban_summary['recent_bans'] . ' ban' . ($ban_summary['recent_bans'] > 1 ? 's' : '');
  }
  
  if ($ban_summary['recent_warns'] > 0) {
    $ban_tip[] = $ban_summary['recent_warns'] . ' warning' . ($ban_summary['recent_warns'] > 1 ? 's' : '');
  }
  
  if ($ban_summary['recent_days'] > 0) {
    $ban_tip[] = $ban_summary['recent_days'] . ' day'
      . ($ban_summary['recent_days'] > 1 ? 's' : '')
      . ' spent banned';
  }
  
  if ($ban_summary['recent_permas'] > 0) {
    $ban_tip[] = $ban_summary['recent_permas'] . ' permaban' . ($ban_summary['recent_permas'] > 1 ? 's' : '');
  }
  
  $ban_tip = "<strong>Past 12 months history</strong><ul class=\"ban-tip-cnt\"><li>" . implode('</li><li>', $ban_tip) . '</li></ul>';
  
  if ($host !== false) {
    return "<div id=\"ban-tip-ip\" style=\"display:none\">$ban_tip</div><small>[ <a data-tip data-tip-type=\"ip\" data-tip-cb=\"showBanTip\" href=\"https://team.4chan.org/bans?action=search&amp;ip=$host\" target=\"_blank\">{$ban_summary['total']} ban" .
      (($ban_summary['total'] > 1) ? 's' : '') . " for this IP</a> ]</small>";
  }
  else {
    return "<div id=\"ban-tip-pass\" style=\"display:none\">$ban_tip</div><small>[ <a data-tip data-tip-type=\"pass\" data-tip-cb=\"showBanTip\" href=\"https://team.4chan.org/bans?action=search&amp;pass_ref=%2F" . BOARD_DIR . "%2F" . (int)$_GET['id'] . "\" target=\"_blank\">{$ban_summary['total']} ban" .
      (($ban_summary['total'] > 1) ? 's' : '') . " for this Pass</a> ]</small>";
  }
}

function ban_post( $no, $globalban, $length, $reason, $is_threadban = 0 )
{
	$db = YotsubaDB::board();
	$query = $db->query("SELECT * FROM {$db->qi(SQLLOG)} WHERE no = ?", [intval($no)]);
	$row   = $query->fetch(PDO::FETCH_ASSOC);
	if( !$row ) return "";
	extract( $row, EXTR_OVERWRITE );

	//list( $no, $sticky, $permasage, $closed, $now, $name, $email, $sub, $com, $host, $pwd, $filename, $ext, $w, $h, $tn_w, $tn_h, $tim, $time, $md5, $fsize, $root, $resto ) = $row;
	$name = str_replace( '</span> <span class="postertrip">!', ' #', $name );
	$name = preg_replace( '/<[^>]+>/', '', $name ); // remove all remaining html crap

	if( $host ) $reverse = gethostbyaddr( $host );
	$displayhost = ( $reverse && $reverse != $host ) ? "$reverse ($host)" : $host;
	$xff         = '';

	//$xffresult = mysql_board_call("select host from xff where board='%s' and postno=%d", BOARD_DIR, $no);
	//$xffresult = mysql_global_call( "SELECT xff from xff where board='%s' AND postno='%d'", BOARD_DIR, $no );
	//if( $xffrow = mysql_fetch_row( $xffresult ) ) {
	//	$xff = $xffrow[ 0 ];
		//	$xff_reverse = gethostbyaddr($xffrow[0]);
		//	$xff = ($xff_reverse && $xff_reverse!=$xffrow[0])?"$xff_reverse ($xff)":$xff;
	//}
	$board = BOARD_DIR;
	$zonly = 0;

	$bannedby = $_COOKIE[ '4chan_auser' ];
	$pass_id  = $row[ '4pass_id' ];
	$post_json = make_post_json($row);

	$dbg = YotsubaDB::global();
	$from_ut = $dbg->fromUnixtime('?');
	$result = $dbg->query(
		"INSERT INTO {$dbg->qi(SQLLOGBAN)}
	(board, global, zonly, name, host, reverse, xff, reason, length, admin, md5, {$dbg->qi('4pass_id')}, post_num, post_time, post_json, admin_ip)
	 VALUES
	(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, {$from_ut}, ?, ?)",
		[$board, (int)$globalban, (int)$zonly, $name, $host, $reverse, $xff, $reason, (int)$length, $bannedby, $md5, $pass_id, (int)$no, (int)$time, $post_json, $_SERVER['REMOTE_ADDR']]);

	if( !$result ) {
		echo S_SQLFAIL;
	}

	/*if( $ext != '' ) {
		$salt = file_get_contents( SALTFILE );
		$hash = sha1( BOARD_DIR . $no . $salt );
		@copy( THUMB_DIR . "{$tim}s.jpg", BANTHUMB_DIR . "{$hash}s.jpg" );
	}*/
  /*
	$afsize = (int)( $fsize > 0 );
	validate_admin_cookies();
	if( $is_threadban ) mysql_global_do( "INSERT INTO " . SQLLOGDEL . " (imgonly,postno,resto,board,name,sub,com,img,filename,admin,admin_ip) values('0',%d,%d,'%s','%s','%s','%s','%d','%s','%s','%s')", $no, $resto, SQLLOG, $name, $sub, $com, $afsize, $filename.$ext, $bannedby, $_SERVER['REMOTE_ADDR'] ); // FIXME do all this in one insert outside the write lock
  */
	echo "$displayhost banned.<br>\n";

	return $host;
}

function cpban($no) {
  $no = (int)$no;
  
  if (!$no) {
    die('Invalid thread number.');
  }
  
  $op_reason = htmlspecialchars($_POST['op_reason']);
  $rep_reason = htmlspecialchars($_POST['rep_reason']);
  
  if (!$op_reason || !$rep_reason) {
    die('Ban reason cannot be empty.');
  }
  
  $op_days = (int)$_POST['op_days'];
  $rep_days = (int)$_POST['rep_days'];
  
  if ($op_days < 0 || $rep_days < 0 || $op_days > 9999 || $rep_days > 9999) {
    die('Invalid ban length.');
  }
  
  $op_ban_end = date('YmdHis', time() + $op_days * (24 * 60 * 60));
  $rep_ban_end = date('YmdHis', time() + $rep_days * (24 * 60 * 60));
  
  $op_host = ban_post($no, 1, $op_ban_end, "$op_reason<>Thread Ban No.$no", 1);
  
  if (!$op_host) {
    die("Thread $no doesn't exist.");
  }

  $db = YotsubaDB::board();
  $query = $db->query("SELECT no, host FROM {$db->qi(SQLLOG)} WHERE resto = ? AND host != ? GROUP BY host", [$no, $op_host]);

  while ($row = $query->fetch(PDO::FETCH_ASSOC)) {
    ban_post($row['no'], 1, $rep_ban_end, "$rep_reason<>Thread Ban No.$no", 1);
  }
  
  delete_post($no, false, null, 'threadban');
  
  echo 'Done.<script language="JavaScript">setTimeout("self.close()", 3000); postBack("done-ban-' . SQLLOG . '-' . $no . '");</script><br>';
}

function delete_post($no, $imgonly, $template_id = null, $tool = null) {
	$url       = "/".BOARD_DIR."/post";

	$post = array(
		'mode' => 'usrdel',
		'onlyimgdel' => $imgonly ? 'on' : '',
		$no => 'delete',
		'remote_addr' => $_SERVER['REMOTE_ADDR']
	);
	
	if ($template_id) {
		$post['template_id'] = $template_id;
	}
	
	if ($tool) {
	  $post['tool'] = $tool;
	}
	
	rpc_start_request("https://sys.int$url", $post, $_COOKIE, true);
	
	// don't bother waiting to check for errors

	return true;
}

function archive_thread($thread_id) {
  $url       = "/".BOARD_DIR."/post";

  $post = array(
    'mode' => 'forcearchive',
    'id' => $thread_id
  );
  
  rpc_start_request("https://sys.int$url", $post, $_COOKIE, true);
  
  // don't bother waiting to check for errors

  return true;
}

function move_thread($thread_id, $board) {
	$url       = "/".BOARD_DIR."/post";

	$post = array(
		'mode' => 'movethread',
		'id' => $thread_id,
		'board' => $board
	);
	
	rpc_start_request("https://sys.int$url", $post, $_COOKIE, true);
	
	// don't bother waiting to check for errors

	return true;
}

function rebuild_thread($no, &$error = '', $is_archived = false) {
  $url = '/' . BOARD_DIR . '/post';
  
  if (!$is_archived) {
    $post = array(
      'mode' => 'rebuildadmin',
      'no'   => $no
    );
  }
  else {
    $post = array();
    $post['mode'] = 'rebuild_threads_by_id';
    $post['ids'] = array($no);
    $post = http_build_query($post);
  }
  
  rpc_start_request("https://sys.int$url", $post, $_COOKIE, true);
  
  return true;
}

function rebuild_all(&$error = '') {
  $url = '/' . BOARD_DIR . '/post';
  
  $post = array(
    'mode' => 'rebuildall'
  );
  
  rpc_start_request("https://sys.int$url", $post, $_COOKIE, true);
  
  return true;
}

function dir_contents( $dir )
{
	$d = opendir( $dir );
	$a = array();
	if( !$d ) return $a;

	while( ( $f = readdir( $d ) ) !== false ) {
		if( $f == "." || $f == ".."  || $f == "" ) continue;
		$a[ ] = $f;
	}

	closedir( $d );

	return $a;
}

function clean()
{
	// Survive oversized boards.
	set_time_limit(0);
	ini_set("memory_limit", "-1");
	
	$images     = array();
	$respages   = array();
	$indexpages = array();

	if( PAGE_MAX > 0 ) {
		print "<strong>Running cleanup...</strong><br>Pruning orphaned posts...<br>";
		$dbb = YotsubaDB::board();
		$result = $dbb->query("SELECT no FROM {$dbb->qi(SQLLOG)} WHERE resto > 0 AND resto NOT IN (SELECT no FROM {$dbb->qi(SQLLOG)} WHERE resto = 0)");
		$nos = array();
		while ($r = $result->fetch(PDO::FETCH_NUM)) { $nos[] = $r[0]; }
		if( count( $nos ) ) {
			$placeholders = implode(',', array_fill(0, count($nos), '?'));
			$dbb->query("DELETE FROM {$dbb->qi(SQLLOG)} WHERE no IN ({$placeholders})", $nos);
			foreach( $nos as $no ) {
				print "$no pruned<br>";
			}
		}
	}

	//clearstatcache();

	// get list of images that should exist
	if (MOBILE_IMG_RESIZE) {
	  $cols = ',m_img'; // FIXME, only because not all boards have that column
	}
	if (!isset($dbb)) $dbb = YotsubaDB::board();
	$result = $dbb->query("SELECT tim, filename, ext{$cols} FROM {$dbb->qi(SQLLOG)} WHERE ext != ''");
	while( $row = $result->fetch(PDO::FETCH_BOTH) ) {
		if( $row[ 'ext' ] == '.swf' ) {
			$images[ "{$row[ 'filename' ]}{$row[ 'ext' ]}" ] = 1;
		}
		else {
			$images[ "{$row[ 'tim' ]}{$row[ 'ext' ]}" ] = 1; // picture
			$images[ "{$row[ 'tim' ]}s.jpg" ]           = 1; // thumb
			
			if (ENABLE_OEKAKI_REPLAYS) {
				$images["{$row['tim']}.tgkr"] = 1; // oe animation
			}
			
			if (MOBILE_IMG_RESIZE) {
			  $images["{$row['tim']}m.jpg"] = 1; // resized
			}
		}
	}
  
	// get list of res pages that should exist
	$result = $dbb->query("SELECT no FROM {$dbb->qi(SQLLOG)} WHERE resto = 0");
	while( $row = $result->fetch(PDO::FETCH_BOTH) ) {
		if( USE_GZIP == 1 ) {
			$respages[ "{$row[ 'no' ]}.html.gz" ] = 1;
			
      if (ENABLE_JSON) {
        $respages[$row['no'] . '.json.gz'] = 1;
        
        if (JSON_TAIL_SIZE) {
          $respages[$row['no'] . '-tail.json.gz'] = 1;
        }
      }
		}
		else {
      $respages[ "{$row[ 'no' ]}.html" ] = 1;
      
      if (ENABLE_JSON) {
        $respages[$row['no'] . '.json'] = 1;
        
        if (JSON_TAIL_SIZE) {
          $respages[$row['no'] . '-tail.json'] = 1;
        }
      }
		}
    
		if( JANITOR_BOARD ) $respages[ $row[ 'no' ] . '.html.php' ] = 1;
	}
	
	print "Cleaning src dir...<br>";
	foreach( dir_contents( IMG_DIR ) as $filename ) {
		if( $images[ $filename ] != 1 && !preg_match('/dmca_/', $filename) && $filename !== 'src') {
			print "Deleted $filename<br>";
      //if (file_exists(IMG_DIR . "$filename")) {
        unlink(IMG_DIR . "$filename") or print "Couldn't delete!<br>";
      //}
		}
	}
  
	print "Cleaning thumb dir...<br>";
	foreach( dir_contents( THUMB_DIR ) as $filename ) {
		if( $images[ $filename ] != 1 && !preg_match('/dmca_/', $filename)) {
			print "Deleted $filename<br>";
      //if (file_exists(THUMB_DIR . "$filename")) {
        unlink(THUMB_DIR . "$filename") or print "Couldn't delete!<br>";
      //}
		}
	}

	print "Cleaning res dir...<br>";
	foreach( dir_contents( RES_DIR ) as $filename ) {
		if( $respages[ $filename ] != 1 ) {
			print "Deleted $filename<br>";
			unlink( RES_DIR . "$filename" ) or print "Couldn't delete!<br>";
		}
	}
	
	print "Cleaning index pages...<br>";
	$result   = $dbb->query("SELECT COUNT(*) FROM {$dbb->qi(SQLLOG)} WHERE archived = 0 AND resto = 0");
	$lastpage = PAGE_MAX + 1;//(mysql_result( $result, 0, 0 ) / DEF_PAGES) + 1;
	if( USE_GZIP == 1 ) {
		$indexpages[ SELF_PATH2_FILE . '.gz' ] = 1;
		
    if (USE_RSS) {
      $indexpages[INDEX_DIR . 'index.rss.gz'] = 1;
    }
    if (ENABLE_CATALOG) {
      $indexpages[INDEX_DIR . 'catalog.html.gz'] = 1;
    }
    if (ENABLE_JSON_CATALOG) {
      $indexpages[INDEX_DIR . 'catalog.json.gz'] = 1;
    }
    if (ENABLE_JSON_THREADS) {
      $indexpages[INDEX_DIR . 'threads.json.gz'] = 1;
      $indexpages[INDEX_DIR . 'archive.json.gz'] = 1;
    }
    if (ENABLE_ARCHIVE) {
      $indexpages[INDEX_DIR . 'archive.html.gz'] = 1;
    }
	}
	
  $indexpages[ SELF_PATH2_FILE ] = 1;
  
  if (USE_RSS) {
    $indexpages[INDEX_DIR . 'index.rss'] = 1;
  }
  if (ENABLE_CATALOG) {
    $indexpages[INDEX_DIR . 'catalog.html'] = 1;
  }
  if (ENABLE_JSON_CATALOG) {
    $indexpages[INDEX_DIR . 'catalog.json'] = 1;
  }
  if (ENABLE_JSON_THREADS) {
    $indexpages[INDEX_DIR . 'threads.json'] = 1;
    $indexpages[INDEX_DIR . 'archive.json'] = 1;
  }
  if (ENABLE_ARCHIVE) {
    $indexpages[INDEX_DIR . 'archive.html'] = 1;
  }
	
	for( $page = 1; $page < $lastpage; $page++ ) {
		if( USE_GZIP == 1 ) {
			$indexpages[ INDEX_DIR . $page . PHP_EXT . '.gz' ] = 1;
      if (ENABLE_JSON_INDEXES) {
        $indexpages[INDEX_DIR . $page . '.json.gz'] = 1;
      }
		}
    $indexpages[ INDEX_DIR . $page . PHP_EXT ] = 1;
    if (ENABLE_JSON_INDEXES) {
      $indexpages[INDEX_DIR . $page . '.json'] = 1;
    }
	}
	
	foreach( glob( INDEX_DIR . '*.{html,gz}', GLOB_BRACE ) as $filename ) {
		$bfilename = basename( $filename );
		if( $indexpages[ $filename ] != 1 ) {
			print "Deleted $bfilename<br>";
			unlink( $filename ) or print "Couldn't delete!<br>";
		}
	}

	print "Cleaning tmp uploads...<br>";
	$phptmp = ini_get( "upload_tmp_dir" );
	exec( "find $phptmp/ -mtime +2h -name php*", $tmpfiles );
	exec( "find -E " . INDEX_DIR . " -regex '.*/(gz)?tmp.*$' -mtime +2h", $indextmp );
	exec( "find -E " . RES_DIR . " -regex '.*/(gz)?tmp.*$' -mtime +2h", $restmp );

	$tmpfiles = array_merge( $tmpfiles, $indextmp );
	$tmpfiles = array_merge( $tmpfiles, $restmp );

	foreach( $tmpfiles as $filename ) {
		$safename = explode( '/' . BOARD_DIR . '/', $filename );
		$safename = end( $safename );

		print "Deleted $safename<br>";
		unlink( $filename ) or print "Couldn't delete!<br>";
	}
	/*print "Cleaning /var/tmp<br>";
	exec("find /var/tmp/ -mtime +2h -type f", $tmpfiles);
	foreach($tmpfiles as $filename) {
		print "Delete $filename<br>"; unlink($filename) or print "Couldn't delete!<br>";
	}*/
	print "Cleaning up side tables...<br>";

	$dbg = YotsubaDB::global();
	$di_7d = $dbg->dateInterval('NOW()', 7, 'DAY');
	$dbg->query("DELETE FROM {$dbg->qi('user_actions')} WHERE time < {$di_7d}");
	$dbg->query("DELETE FROM {$dbg->qi('event_log')} WHERE created_on < {$di_7d}");
	$ut_7d = $dbg->unixTimestamp($di_7d);
	$dbg->query("DELETE FROM {$dbg->qi('xff')} WHERE tim < ({$ut_7d} * 1000)");
	$di_2d = $dbb->dateInterval('NOW()', 2, 'DAY');
	$dbb->query("DELETE FROM {$dbb->qi('f_md5')} WHERE now < {$di_2d}");
	$di_2y = $dbb->dateInterval('NOW()', 2, 'YEAR');
	$dbb->query("DELETE FROM {$dbb->qi('r9k_posts')} WHERE created_on < {$di_2y}");

	print "<strong>Cleanup complete!</strong>";
}

// Changes relative board urls to admin urls
function fix_board_nav($nav) {
  return preg_replace('/href="\/([a-z0-9]+)\/"/', 'href="/$1/admin"', $nav);
}

/* head */
function head( &$dat, $is_logged_in = false )
{
	global $admin, $access_allow, $access_deny;
	
	$allowed_modes = array('ban', 'delall', 'unban', 'opt', 'banreq', 'editop');
	
	if( !is_user() || ( is_user() && ( $admin != "ban" ) && ( $admin != "delall" ) && ( $admin != "unban" ) && ( $admin != "opt" ) && ( $admin != 'banreq' ) && ( $admin != 'editop' ) ) ) {
		$navinc = fix_board_nav(file_get_contents( NAV_TXT )) . '<br>';
		$navinc = str_replace( '[<a href="javascript:void(0);" id="settingsWindowLink">Settings</a>] ', '', $navinc );
	}
  
  if (DEFAULT_BURICHAN) {
    $style_cookie = 'ws_style';
    $ws = 'ws';
  }
  else {
    $style_cookie = 'nws_style';
    $ws = '';
  }
  
  $preferred_style = isset($_COOKIE[$style_cookie]) ? $_COOKIE[$style_cookie] : '';
  
  switch ($preferred_style) {
    case 'Yotsuba New':
      $style = 'yotsubanew';
      break;
    case 'Yotsuba B New':
      $style = 'yotsubluenew';
      break;
    //case 'Futaba New':
    //  $style = 'futabanew';
    //  break;
    //case 'Burichan New':
    //  $style = 'burichannew';
    //  break;
    case 'Tomorrow':
      $style = 'tomorrow';
      break;
    case 'Photon':
      $style = 'photon';
      break;
    default:
      $style = DEFAULT_BURICHAN ? 'yotsubluenew' : 'yotsubanew';
      break;
  }
  
	if (!in_array($admin, $allowed_modes)) {
		$admin = '';
	}
	
	if ($admin == 'ban') {
	  $page_title = 'Ban No.' . (int)$_GET['id'] . ' on /' . BOARD_DIR . '/';
	  $no_header = true;
	}
	else if ($admin == 'banreq') {
	  $page_title = 'Ban request No.' . (int)$_GET['id'] . ' on /' . BOARD_DIR . '/';
	  $no_header = true;
	}
	else {
	  $page_title = TITLE;
	  $no_header = isset($_GET['noheader']);
	}
	
	$fb_js = <<<JS
Feedback = {
  showMessage: function(msg) {
    var el;
    
    Feedback.hideMessage();
    
    el = document.createElement('div');
    el.id = 'feedback';
    el.innerHTML = '<span class="feedback-error">' + msg + '</span>';
    
    document.body.insertBefore(el, document.body.firstElementChild);
  },
  
  hideMessage: function() {
    var el = document.getElementById('feedback');
    
    if (el) {
      document.body.removeChild(el);
    }
  },
  
  checkTemplate: function(id) {
    var tpl;
    
    Feedback.hideMessage();
    
    if (id < 0) {
      return;
    }
    
    tpl = window.templates[id];
    
    if (tpl.no == '1') {
      Feedback.showMessage('<u>Only</u> use this ban template for images depicting apparent child pornography. For links and non-pornographic images, please use the appropriate template(s).');
    }
    else if (tpl.no == '123' || tpl.no == '126') {
      Feedback.showMessage('Images depicting apparent child pornography should be banned using the "Child Pornography (Explicit Image)" template.');
    }
  }
};
JS;
  
$tooltip_js = <<<JS
var Tip = {
  node: null,
  timeout: null,
  delay: 150,
  
  init: function() {
    document.addEventListener('mouseover', this.onMouseOver, false);
    document.addEventListener('mouseout', this.onMouseOut, false);
  },
  
  onMouseOver: function(e) {
    var cb, data, t;
    
    t = e.target;
    
    if (Tip.timeout) {
      clearTimeout(Tip.timeout);
      Tip.timeout = null;
    }
    
    if (t.hasAttribute('data-tip')) {
      data = null;
      
      if (t.hasAttribute('data-tip-cb')) {
        cb = t.getAttribute('data-tip-cb');
        if (cb.indexOf('.') !== -1) {
          cb = cb.split('.');
          if (window[cb[0]] && (cb = window[cb[0]][cb[1]])) {
            data = cb(t);
          }
        }
        else if (window[cb]) {
          data = window[cb](t);
        }
        if (data === null) {
          return;
        }
      }
      Tip.timeout = setTimeout(Tip.show, Tip.delay, e.target, data);
    }
  },
  
  onMouseOut: function(e) {
    if (Tip.timeout) {
      clearTimeout(Tip.timeout);
      Tip.timeout = null;
    }
    
    Tip.hide();
  },
  
  show: function(t, data, pos) {
    var el, rect, style, left, top;
    
    rect = t.getBoundingClientRect();
    
    el = document.createElement('div');
    el.id = 'tooltip';
    
    if (data) {
      el.innerHTML = data;
    }
    else {
      el.textContent = t.getAttribute('data-tip');
    }
    
    if (!pos) {
      pos = 'top';
    }
    
    el.className = 'tip-' + pos;
    
    document.body.appendChild(el);
    
    left = rect.left - (el.offsetWidth - t.offsetWidth) / 2;
    
    if (left < 0) {
      left = rect.left + 2;
      el.className += '-right';
    }
    else if (left + el.offsetWidth > document.documentElement.clientWidth) {
      left = rect.left - el.offsetWidth + t.offsetWidth + 2;
      el.className += '-left';
    }
    
    top = rect.top - el.offsetHeight - 5;
    
    style = el.style;
    style.display = 'none';
    style.top = (top + window.pageYOffset) + 'px';
    style.left = left + window.pageXOffset + 'px';
    style.display = '';
    
    Tip.node = el;
  },
  
  hide: function() {
    if (Tip.node) {
      document.body.removeChild(Tip.node);
      Tip.node = null;
    }
  }
}

Tip.init();
JS;

	$dat .= '<!DOCTYPE html><html><head>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<meta http-equiv="pragma" content="no-cache">
<meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="icon" type="image/x-icon" href="//s.4cdn.org/image/favicon-team' . $ws . '.ico">
<link rel="stylesheet" style="text/css" href="//s.4cdn.org/css/' . $style . '.387.css">
<script type="text/javascript">' . $fb_js . '</script>
<style type="text/css">
table:not([class]) {
	border: 1px solid #fff;
	border-collapse: collapse;

	margin: 0 auto;
}

#tooltip {
  color: #dedede;
  text-align: left;
}

.ico-phone {
	opacity: 0.75;
	font-size: 12px;
	cursor: default;
}

.ban-tip-cnt {
  padding: 0 0 0 10px;
  margin: 2px 0 1px 0;
}

#js-move-board-sel {
  display: none;
  width: 100px;
}

#feedback {
  top: 0px;
  text-align: center;
  z-index: 9999;
  display: block;
  background-color: #C41E3A;
  margin: 0px;
  left: 0px;
  padding: 5px;
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.2);
}
.feedback-error {
  color: #fff;
  font-size: 12px;
  text-shadow: 0 1px rgba(0, 0, 0, 0.2);
}

.bantable {
	width: 98%;
	margin: 0;
}

.bantable-extra input[type="text"] {
  font-size: 11px;
  white-space: nowrap;
  width: 260px;
}

.bantable-extra.bantable-tb input[type="text"] {
  width: 244px;
}

.bantable-extra td {
  font-size: 11px;
  white-space: nowrap;
}

.postblock {
  width: 80px;
}

#ban-days { width: 45px; }

#submit-ban-btn {
  position: absolute;
  right: 10px;
  margin-top: -2px;
}

.bantable tr td:first-child {
	font-weight: bold;
	padding-right: 5px;
}

table:not([class]) td {
padding: 3px;
border: 1px solid #fff;
}

input[type="text"], textarea {
	margin: 0px;
	margin-right: 2px;
	padding: 2px 4px 3px 4px;
	border: 1px solid #AAA;
	outline: none;
	font-family: arial,helvetica,sans-serif;
	font-size: 10pt;
}

.inputcenter { text-align: center; }

table {
  border-spacing: 1px;
}

.tomorrow textarea {
  background-color: #282a2e;
  color: #c5c8c6;
}

.tomorrow input[type="text"]:not(:focus),
.tomorrow textarea:not(:focus) {
  border-color: #000;
}

.glow-r { box-shadow: 0 0 4px 4px #e04000; }

*[disabled=disabled] {
	opacity: 0.5;
}
</style>
<script type="text/javascript">
' . ($is_logged_in ? '
/*localStorage.setItem("extra_path", "' . (has_level('mod') ? ADMIN_JS_PATH : JANITOR_JS_PATH) . '");*/
' : '') . '
function checkBrowser(){
	this.ver=navigator.appVersion
	this.dom=document.getElementById?1:0
	this.ie5=(this.ver.indexOf("MSIE 5")>-1 && this.dom)?1:0;
	this.ie4=(document.all && !this.dom)?1:0;
	this.ns5=(this.dom && parseInt(this.ver) >= 5) ?1:0;
	this.ns4=(document.layers && !this.dom)?1:0;
	this.bw=(this.ie5 || this.ie4 || this.ns4 || this.ns5)
	return this
}
bw=new checkBrowser()

function popup(vars) {
//490 - 220
	var pheight = /admin=opt/.test(vars) ? 220 : 490;
  day = new Date();
	id = day.getTime();
	var newWindow;
	var props = \'scrollBars=no,resizable=no,toolbar=no,menubar=no,location=no,directories=no,width=400,height=\' + pheight;
	eval(\'popup\'+id+\' = window.open("admin?mode=admin&"+vars, "\'+id+\'", props);\');
}

function more(div,div2,nest){
	obj=bw.dom?document.getElementById(div).style:bw.ie4?document.all[div].style:bw.ns4?nest?document[nest].document[div]:document[div]:0;
	obj2=bw.dom?document.getElementById(div2).style:bw.ie4?document.all[div2].style:bw.ns4?nest?document[nest].document[div2]:document[div2]:0;
	if(obj.display==\'\') {
		obj.display=\'none\';
		obj2.display=\'none\';
	} else {
		obj.display=\'\';
		obj2.display=\'\';
	}
}

function swap(div,div2) {
	var el = document.getElementById(div);
	var el2 = document.getElementById(div2);
	var tmp = el.style.display;
	el.style.display = el2.style.display;
	el2.style.display = tmp;
}

function postBack(msg) {
	if (self !== top) {
		window.parent.postMessage(msg, "*");
	}
}

document.addEventListener("DOMContentLoaded", onDOMReady, false);

function onDOMReady() {
  var el;
  
  document.removeEventListener("DOMContentLoaded", onDOMReady, false);
  
  el = document.getElementById("move-form");
  
  if (el) {
    el.addEventListener("submit", onMoveThread, false);
  };
  
  el = document.getElementById("autocomplete");
  
  if (el && !/Android|iPhone|iPad/.test(navigator.userAgent)) {
    el.focus();
  };
  
  el = document.getElementById("js-postban-sel");
  
  if (el) {
    el.addEventListener("change", onPostBanSelChange, false);
  };
  
  el = document.getElementById("js-sticky-cb");
  
  if (el) {
    el.addEventListener("change", onStickyChange, false);
  };
  
  adjustMobileMargin();
};

function adjustMobileMargin() {
  if (!window.matchMedia("(max-device-width: 480px)").matches) {
    return;
  }
  
  let oh = document.documentElement.clientHeight;
  let ih = document.body.clientHeight;
  
  if (oh - ih > 50) {
    document.body.style.paddingTop = (oh - ih - 50) + "px";
  }
}

function onStickyChange(e) {
  var el = document.getElementById("js-undead-cb");
  
  if (!this.checked) {
    el.checked = false;
  }
  
  if (this.dataset.cur === "0") {
    el = document.getElementById("js-set-btn");
    
    if (this.checked) {
      el.classList.add("glow-r");
    }
    else {
      el.classList.remove("glow-r");
    }
  }
}

function onMoveThread(e) {
  if (!checkSubmitConfirm(document.getElementById("js-move-btn"))) {
    e.preventDefault();
    return;
  }
}

function checkSubmitConfirm(el) {
	if (el.hasAttribute("data-js-confirming")) {
		clearSubmitConfirm(el);
		return true;
	}
	
	el.setAttribute("data-js-confirming", "1");
	
	if (el.tagName === "BUTTON") {
		el.setAttribute("data-js-label", el.textContent);
		el.textContent = "Confirm?";
	}
	else {
		el.setAttribute("data-js-label", el.value);
		el.value = "Confirm?";
	}
	
	let timeout = setTimeout(clearSubmitConfirm, 3000, el);
	
	el.setAttribute("data-js-to", timeout);
	
	return false;
}

function clearSubmitConfirm(el) {
	let label = el.getAttribute("data-js-label");
	
	if (label === null) {
		return;
	}
	
	let timeout = +el.getAttribute("data-js-to");
	clearTimeout(timeout);
	
	el.removeAttribute("data-js-confirming");
	el.removeAttribute("data-js-to");
	el.removeAttribute("data-js-label");
	
	if (el.tagName === "BUTTON") {
		el.textContent = label;
	}
	else {
		el.value = label;
	}
}

admin = "' . $admin . '";

document.addEventListener("keydown", onKeyDown, false);

function onKeyDown(e) {
	var board, postno;
	
	board = "' . BOARD_DIR . '";
	postno = ' . ((int)(isset($_GET['id']) ? $_GET['id'] : 0)) . ';
	
  if (e.keyCode == 27 && !e.ctrlKey && !e.altKey && !e.shiftKey && !e.metaKey) {
    postBack("cancel-ban-" + board + "-" + postno);
  }
  
  if( admin == "opt" ) {
  	//sticky 83
  	//permasage 80
  	//closed 67
  	//permaage 69
  	//undead 85
  	//spoiler 79
  	//enter 13
  	//S, P, C, E, U, O
  	//Also give the sticky checkbox focus so I can hit tab once to change the number,
  	//and then hit enter to submit.
  
  if (document.activeElement.nodeName == "INPUT" && document.activeElement.type === "text") {
    return;
  }
  
	if( e.ctrlkey || e.altkey || e.shiftkey || e.metakey ) return;
	
	var kc = e.keyCode;
	var toggle = "";
	
	switch(kc) {
		case 83:
			toggle = "sticky";
			break;
		case 80:
			toggle = "permasage";
			break;
		case 67:
			toggle = "closed";
			break;
		case 69:
			toggle = "permaage";
			break;
		case 85:
			toggle = "undead";
			break;
		case 79:
			toggle = "spoiler";
			break;		

		case 13:
			document.getElementById("mainform").submit();
			return true;
			
		default:
			// hello
			break;
	}
	
	if(toggle) toggleCheckbox(document.querySelector("input[name=" + toggle + "]"));
	
  }
}

' . $tooltip_js . '

function toggleCheckbox(elem) {
	elem.checked = !elem.checked;
  elem.focus();
}

function showBanTip(btn) {
  return document.getElementById("ban-tip-" + btn.getAttribute("data-tip-type")).innerHTML;
}
';

if ($admin == 'ban') {
  $dat .= <<<JS
function onPostBanSelChange(e) {
  var el, opt, to, i, o;
  
  el = document.getElementById('js-move-board-sel');
  
  if (!el) {
    return;
  }
  
  opt = this.options[this.selectedIndex];
  
  if (opt.value === 'move') {
    el.style.display = 'inline';
    el.disabled = false;
  }
  else {
    el.style.display = '';
    el.disabled = true;
  }
}
JS;
}

$dat .= '</script>
<title>' . $page_title . '</title>
</head>
<body class="' . $style . '">
';
  
	if (!$no_header) {
		$dat .= '
' . str_replace( "12pt", "10pt", $navinc ) . '
<div class="boardBanner"><div class="boardTitle" style="font-size: 18pt !important;">' . TITLE . '</div></div>
<hr width="90%" size=1>';
	}
}

/* Footer */
function foot( &$dat )
{
	$dat .= '
<center>
<small>' . S_FOOT . '
</small>
</center>wtf?
' . str_replace( "12pt", "10pt", $navinc2 ) . '
</body></html>';
}

function error( $mes, $dest = '' )
{
	global $upfile_name;
  if ($dest && file_exists($dest)) {
    unlink($dest);
  }
	head( $dat );
	echo $dat;
	echo "<br><br>
        <center><font color=\"red\" size=\"5\"><b>$mes</b></font><br><br><font size=\"5\"><b>[<a href=" . SELF_PATH2_ABS . ">" . S_RELOAD . "</a>]</b></font></center>";
	die( "</body></html>" );
}

/* text plastic surgery */
function sanitize_text( $str )
{
	global $admin;
	$str = trim( $str ); //blankspace removal
	if( function_exists('get_magic_quotes_gpc') && get_magic_quotes_gpc() ) {
		$str = stripslashes( $str );
	}
	if( $admin != $adminpass ) { //admins can use tags
		$str = htmlspecialchars( $str ); //remove html special chars
		$str = str_replace( "&amp;", "&", $str ); //remove ampersands
	}

	return str_replace( ",", "&#44;", $str ); //remove commas
}

//check for table existance
function table_exist( $table )
{
	$db = YotsubaDB::global();
	$result = $db->query("SHOW TABLES LIKE ?", [$table]);
	if( !$result ) {
		return 0;
	}
	$a = $result->fetch(PDO::FETCH_NUM);

	return $a;
}

function is_local()
{
	if (!isset($_SERVER['REMOTE_ADDR'])) {
	  return true;
	}
	
	// local rpc can do anything
	$longip = ip2long( $_SERVER['REMOTE_ADDR'] );
	
	if(
		cidrtest( $longip, "10.0.0.0/24" ) ||
		cidrtest( $longip, "204.152.204.0/24" ) ||
		cidrtest( $longip, "127.0.0.0/24" )
	) {
		return true;
	}

	return false;
}

// FIXME hack
function valid( $action = 'moderator', $no = 0 )
{
	return false;
}

/*password validation */
function admin_login_form($error_msg = '') {
	$board = BOARD_DIR;
	$err = $error_msg ? '<div style="color:red;margin:10px 0">' . htmlspecialchars($error_msg) . '</div>' : '';
	echo <<<HTML
<!DOCTYPE html>
<html><head><title>/{$board}/ — Admin Login</title>
<style>
body { font-family: arial, helvetica, sans-serif; background: #EEF2FF; }
.login-box { width: 300px; margin: 80px auto; padding: 20px; background: #D6DAF0; border: 1px solid #B7C5D9; }
.login-box h2 { margin: 0 0 15px; font-size: 16px; text-align: center; }
.login-box input[type=text], .login-box input[type=password] { width: 100%; padding: 4px; margin: 4px 0 10px; box-sizing: border-box; }
.login-box input[type=submit] { width: 100%; padding: 6px; cursor: pointer; }
.login-box label { font-size: 13px; }
</style></head><body>
<div class="login-box">
<h2>Staff Login</h2>
{$err}
<form method="post" action="admin.php">
<label>Username</label>
<input type="text" name="userlogin" autofocus>
<label>Password</label>
<input type="password" name="passlogin">
<input type="hidden" name="adminlogin" value="1">
<input type="submit" value="Log In">
</form>
</div>
</body></html>
HTML;
	die();
}

function admin_do_login() {
	$username = $_POST['userlogin'];
	$password = $_POST['passlogin'];

	if (!$username || !$password) {
		admin_login_form('Username and password are required.');
	}

	$db = YotsubaDB::global();
	$query = $db->query("SELECT * FROM {$db->qi(SQLLOGMOD)} WHERE {$db->qi('username')} = ? LIMIT 1", [$username]);
	if (!$query->rowCount()) {
		admin_login_form('Invalid username or password.');
	}

	$fetch = $query->fetch(PDO::FETCH_ASSOC);

	if ($fetch['password'] !== $password) {
		admin_login_form('Invalid username or password.');
	}

	if ($fetch['password_expired'] == 1) {
		admin_login_form('Your password has expired.');
	}

	$admin_salt = @file_get_contents('/www/keys/2014_admin.salt');
	if (!$admin_salt) $admin_salt = 'local-lab-salt';

	$apass = hash('sha256', $fetch['username'] . $fetch['password'] . $admin_salt);

	setcookie('4chan_auser', $username, time() + 30 * 24 * 3600, '/');
	setcookie('apass', $apass, time() + 30 * 24 * 3600, '/');

	header('Location: admin.php');
	die();
}

function adminvalid( $title = 'Manager Mode' )
{
	global $user, $pass, $access_allow, $access_deny, $admin;

	$level    = 0;
	$levelarr = array( 'janitor' => 1, 'mod' => 2, 'manager' => 3, 'admin' => 4 );

	ob_start();

	// Handle login POST
	if (isset($_POST['adminlogin'])) {
		admin_do_login();
	}

	// 1 = janitor, 2 = mod, 3 = manager, 4 = admin

	if( is_local() ) {
		echo head( $dat );

		return;
	}

	$user = isset($_COOKIE['4chan_auser']) ? $_COOKIE['4chan_auser'] : '';
	$pass = isset($_COOKIE['apass']) ? $_COOKIE['apass'] : '';

	$valid = auth_user();

	if( $valid !== true ) {
	  admin_login_form();
  }

	//if( !$valid ) admin_login_fail();


	// Do we have permission for this board?
	if( $valid && ( $title !== 'Ban Request' && !access_board( BOARD_DIR ) ) ) {
		error( 'You do not have permission to access this board.' );

	}
  
	if ($title !== 'Ban Request' && !has_level('mod')) {
	  die();
	}
	
  if ($title === 'Board Cleanup' && !has_level('manager') && !has_flag('developer')) {
    error( 'You do not have permission to access this board.' );
  }
	
	if( $valid && has_level() && isset($_GET['admin']) && $_GET[ 'admin' ] == 'adminext' ) {
		return true;
	}


	head( $dat, $valid );
	echo $dat;

	$SELF_PATH2_ABS = SELF_PATH2_ABS;
	$S_RETURNS     = S_RETURNS;
	$SELF_PATH      = SELF_PATH;
	$S_LOGUPD      = S_LOGUPD;
	$S_LOGUPDALL   = S_LOGUPDALL;
	if (!isset($_GET['noheader']) && $title == 'Manager Mode') {

		if( $valid && has_level( 'mod' ) ) {
			echo '<div style="clear: both;">';
			echo '<span style="float:left;margin-bottom:3px;">[<a href="' . SELF_PATH2_ABS . '">' . S_RETURNS . '</a>] [<a href="' . SELF_PATH . '">' . S_LOGUPD . '</a>] [<a href="' . SELF_PATH . '?mode=rebuildall">' . S_LOGUPDALL . '</a>]';

			if( isset($_GET['admin']) && $_GET[ 'admin' ] == 'cleanup' ) {
				echo ' [<a href="admin">Admin</a>]';
			}
			else if (has_level('manager') || has_flag('developer')) {
				echo ' [<a href="admin?admin=cleanup">Cleanup</a>]';
			}

			if( isset($_GET['admin']) && $_GET[ 'admin' ] == 'ban' ) {
				echo ' [<a href="//www.' . L::d(BOARD_DIR) . '/rules#' . BOARD_DIR . '" target="_blank" title="Open the rules for this board in a new window">Rules</a>]';
			}

			echo '</span>';
		}
		elseif( $valid ) {
			//echo ' [<a href="//www.4chan.org/rules#' . BOARD_DIR . '" target="_blank" title="Open the rules for this board in a new window">Rules</a>] ';
		}

		if( ( !isset( $_GET[ 'admin' ] ) || $_GET[ 'admin' ] == 'cleanup' ) && has_level( 'mod' ) ) {
			echo "<select style=\"float:right;\" onchange=\"var x=this.options[this.selectedIndex].value;x&&(window.location=x)\">";
			$db = YotsubaDB::global();
			$result = $db->query("SELECT dir FROM {$db->qi('boardlist')} ORDER BY dir");
			while( $row = $result->fetch(PDO::FETCH_BOTH) ) {
				if( isset($_GET['admin']) && $_GET[ 'admin' ] == 'cleanup' ) {
					$querystring = '?admin=cleanup';
				}
				else $querystring = '';
				if( $row[ 'dir' ] == SQLLOG ) {
					$selected = 'selected';
				}
				else $selected = '';
				echo "<option value=\"/{$row[ 'dir' ]}/admin$querystring\" $selected>{$row[ 'dir' ]}</option>\n";
			}
			echo "</select>";
		}
	}
  
	$no_header = isset($_GET['noheader']) || (isset($_GET['admin']) && ($_GET['admin'] == 'ban' || $_GET['admin'] == 'banreq'));
	
	if( $valid && !has_level( 'mod' ) ) {
		if ($no_header) {
			return;
		}
		echo "<br><br>
        <center><font color=\"red\" size=\"5\"><b>You are logged in as a janitor.</b></font><br><br><font size=\"5\"><b>[<a href=\"//boards." . L::d(BOARD_DIR) . '/' . BOARD_DIR . "/\">Return</a>]</b></font></center>";
		die( '</body></html>' );
	}

	//if( $valid && (has_level('manager') || has_flag('developer')) ) {
		$GLOBALS[ 'b_sticky' ] = 1;
	//}

	if( !$valid ) $title = 'Manager Mode';
	if( !$valid ) echo '<div style="clear:both;">[<a href="//boards.' . L::d(BOARD_DIR) . '/' . BOARD_DIR . '" accesskey="a">' . S_RETURN . '</a>]</span></div>';
	if( !$no_header ) echo '<div class="postingMode" style="clear: both;">' . $title . '</div>';
	// Mana login form
	if( !$valid ) {
		echo "<form action=\"" . https_self_url() . "\" method=\"post\" style=\"margin-top: 5px;\">\n";

		echo "<center>";
		echo "<input type=\"hidden\" name=\"mode\" value=\"admin\">\n";
		echo "<table class=\"postForm\"><tbody>";
		// echo "<tr><td>ID(s):</td><td><input type=text name=res size=8 value=\"".$_GET['res']."\"></td></tr>";
		echo "<tr><td>Username</td><td><input type=\"text\" name=\"userlogin\" style=\"width: 120px; text-align: center;\" tabindex=\"1\"> <input type=\"submit\" value=\"" . S_MANASUB . "\" style=\"margin: 0;\" tabindex=\"3\"></td></tr>";
		echo "<tr><td>Password</td><td><input type=\"password\" name=\"passlogin\"  style=\"width: 120px; text-align: center;\" tabindex=\"2\"></td></tr>";
		echo "</tbody></table></form></center>\n";
		//echo file_get_contents( NAV2_TXT );
		echo '</body></html>';


		die();
	}
}

// FIXME
function adminreportclear() {
  if (!has_level('mod')) {
    die('404');
  }

  $pid = (int)$_GET['pid'];

  $board = $_GET['board'];
  
  if (!$pid || !$board) {
    die('404');
  }
  
  $db = YotsubaDB::global();
  $res = $db->query("UPDATE {$db->qi('reports')} SET cleared = 1, cleared_by = ? WHERE board = ? AND no = ?", [$_COOKIE['4chan_auser'], $board, $pid]);

  if (!$res) {
    die("DB error (2-1)");
  }

  $res = $db->query("UPDATE {$db->qi('reports_for_posts')} SET cleared = 1, clearedby = ? WHERE board = ? AND postid = ?", [$_COOKIE['4chan_auser'], $board, $pid]);
  
  if (!$res) {
    die("DB error (2-2)");
  }
    
  echo "Done";
}

function adminreportqueue() {
  if (!has_level('mod')) {
    die('404');
  }

  $db = YotsubaDB::global();
  $query = "SELECT *, SUM(weight) as total_weight, COUNT({$db->qi('reports')}.no) as cnt, "
    . $db->groupConcatDistinct('report_category') . " as cats, "
    . $db->unixTimestamp('ts') . " as {$db->qi('time')} "
    . "FROM {$db->qi('reports')} "
    . "WHERE cleared = 0 "
    . "GROUP BY {$db->qi('reports')}.no, {$db->qi('reports')}.board "
    . "ORDER BY total_weight DESC "
    . "LIMIT 200";

  $res = $db->query($query);

  if (!$res) {
    die('DB error (1)');
  }

  if (!$res->rowCount()) {
    echo '<p>No pending reports.</p>';
  }

  while ($report = $res->fetch(PDO::FETCH_ASSOC)) {
    $post = json_decode($report['post_json'], true);

    echo '<div style="margin:12px;padding:8px;border:1px solid #D9BFB7;background:#F0E0D6">';
    if ($post && $post['fsize'] > 0) {
      echo '<img src="/thumbs/' . $report['board'] . '/' . $post['tim'] . 's.jpg" style="max-width:125px;float:left;margin-right:8px">';
    }

    $tid = $post && $post['resto'] ? $post['resto'] : $report['no'];

    echo "<a target=\"_blank\" href=\"/{$report['board']}/thread/$tid#p{$report['no']}\"><b>/{$report['board']}/{$report['no']} ({$report['total_weight']})</b></a>";
    echo ' — <span style="color:#789922">' . htmlspecialchars($report['cats']) . '</span>';
    echo ' — ' . $report['cnt'] . ' report(s)';
    echo ' &mdash; <a style="color:red" href="?admin=reportclear&amp;board=' . $report['board'] . '&amp;pid=' . $report['no'] . '">[CLEAR]</a>';
    echo ' <a href="/' . $report['board'] . '/admin?admin=ban&amp;id=' . $report['no'] . '">[BAN]</a>';

    if ($post && $post['com']) {
      echo "<p style=\"margin:4px 0\">" . substr($post['com'], 0, 300) . "</p>";
    }

    echo '<div style="clear:both"></div></div>';
  }
}

/* Admin deletion */
// This might not be used anymore
function admin_delete()
{
	if( !has_level('mod') ) return true;

	global $admin, $onlyimgdel, $res, $thread, $ip, $user, $pass;

	if( ( $admin != "ban" ) && ( $admin != "delall" ) && ( $admin != "unban" ) ) {
		$navinc = ''; //file_get_contents( NAV_TXT );
	}
	if( !isset( $_POST[ 'p' ] ) ) {
		$p = 1;
	}
	else {
		$p = $_POST[ 'p' ];
	}
	$max_results = 30;
	$from        = ( ( $p * $max_results ) - $max_results );

	$board = explode( "/", $_SERVER[ 'SCRIPT_NAME' ] );
	$board = $board[ 1 ];

	$db_board = YotsubaDB::board();
	$threadmode = $_REQUEST[ 'threadmode' ];
	if( !$threadmode ) { // threadmode uses table aliases, so don't bother locking
		if( $delflag ) $db_board->lockTable(SQLLOG);
	}

	$delno   = array();
	$delflag = false;
	foreach( $_POST as $key => $value ) {
		$item = array( 0 => $key, 'key' => $key, 1 => $value, 'value' => $value );
		if( $item[ 1 ] == 'delete' ) {
			array_push( $delno, intval( $item[ 0 ] ) );
			$delflag = true;
		}
	}
	if( $delflag ) {
		$resultstr = "(" . implode( ",", $delno ) . ")";
		if( $threadmode ) $db_board->lockTable(SQLLOG); // can finally lock it now
		if( !$result = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)} WHERE no IN $resultstr OR resto IN $resultstr" ) ) {
			echo S_SQLFAIL;
		} //FIXME use assoc
		$find = false;
		while( $row = $result->fetch(PDO::FETCH_ASSOC) ) {
			//list( $no, $sticky, $permasage, $closed, $now, $name, $email, $sub, $com, $host, $pwd, $filename, $ext, $w, $h, $tn_w, $tn_h, $tim, $time, $md5, $fsize, $root, $resto ) = $row;
			extract( $row, EXTR_OVERWRITE );

			if( $onlyimgdel == 'on' ) {
				if( array_search( $no, $delno ) ) { //only a picture is deleted
					if( $board == "f" ) {
						$delfile = IMG_DIR . $filename . $ext;
					}
					else {
						$delfile = IMG_DIR . $tim . $ext; //only a picture is deleted
					}
					unlink( $delfile ); //delete
					unlink( THUMB_DIR . $tim . 's.jpg' ); //delete
				}
			}
			else {
				if( array_search( $no, $delno ) || array_search( $resto, $delno ) ) { //It is empty when deleting
					$find  = true;
					$auser = $_COOKIE[ '4chan_auser' ];
					$apass = $_COOKIE[ '4chan_apass' ];
					if( !$db_board->query( "DELETE FROM {$db_board->qi(SQLLOG)} WHERE no = ? OR resto = ?", [$no, $no] ) ) {
						echo S_SQLFAIL;
					} // FIXME can't this be atomic? (one statement)
					if( $board == "f" ) {
						$delfile = IMG_DIR . $filename . $ext;
					}
					else {
						$delfile = IMG_DIR . $tim . $ext;
					}
					unlink( $delfile ); //Delete
					unlink( THUMB_DIR . $tim . 's.jpg' ); //Delete
					if( $fsize > 0 ) $adfsize = 1;
					$adname = str_replace( '</span> <span class="postertrip">!', '#', $name );
					if( $onlyimgdel == "on" ) {
						$imgonly = 1;
					}
					else {
						$imgonly = 0;
					}
					validate_admin_cookies();
					$db_global_del = YotsubaDB::global();
					$db_global_del->query( "INSERT INTO {$db_global_del->qi(SQLLOGDEL)} (imgonly, postno, resto, board, name, sub, com, img, filename, admin, admin_ip) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [$imgonly, $no, $resto, SQLLOG, $adname, $sub, $com, $adfsize, "$filename$ext", $auser, $_SERVER['REMOTE_ADDR']] ); // FIXME do all this in one insert outside the write lock
				}
			}
		}
	}

	if( $delflag ) $db_board->unlockTables();

	// Deletion screen display
	echo "<center style=\"margin-top: 4px;\"><input type=\"hidden\" name=\"mode\" value=\"admin\">\n";
	echo "<input type=\"hidden\" name=\"admin\" value=\"del\">\n";
	echo "Go to ID(s): <input type=\"text\" name=\"res\" size=\"10\" maxlength=\"10\" class=\"inputcenter\">&nbsp;<input type=\"submit\" value=\"Go\">";
	if( $threadmode ) {
		echo "<input type=\"button\" onclick='location.search=\"\"' value=\"View by order posted\">";
	}
	else {
		echo "<input type=\"button\" onclick='location.search=\"?threadmode=1\"' value=\"Group by thread\">";
	}

	echo "</center></form>";
  
	echo "<center><p><form action=\"" . SELF_PATH . "\" method=\"POST\"><input type=\"hidden\" name=\"mode\" value=\"admindel\"><input type=\"hidden\" name=\"pwd\" value=\"" . ADMIN_PASS . "\"><input type=\"submit\" value=\"" . S_ITDELETES . "\"> ";
	echo "<input type=\"reset\" value=\"" . S_MDRESET . "\">";
	echo " [<input type=\"checkbox\" name=\"onlyimgdel\" value=\"on\"><!--checked-->" . S_MDONLYPIC . "]";

	echo "<table border=\"1\" cellspacing=\"0\">";
	if( $threadmode ) {
		echo "<tr bgcolor=\"#408040\" align=\"center\" style=\"color:#eef6ee\">";
	}
	else {
		echo "<tr bgcolor=\"#6080f6\" align=\"center\">";
	}
	echo '<td>&nbsp;</td><td><b>No.</b></td><td><b>Time</b></td><td><b>Name</b></td><td><b>Subject</b></td><td><b>Comment</b></td><td><b>Host</b></td><td>&nbsp;</td>';
	echo "</tr>\n";

	$resq = "`";
	if( $res ) {
		$resq     = "";
		$splitres = explode( ",", $res );
		foreach( $splitres as $line ) {
			$resq .= " no='" . intval( $line ) . "' OR";
		}
		$resq = rtrim( $resq, " OR" );
		$resq = "` WHERE" . $resq;

	}
	elseif( $thread && $ip ) {
		$max_results = 5000;
		$thread      = (int)$thread;
		$resq        = "` WHERE (no='$thread' OR resto='$thread') AND host='" . sprintf( "%s", long2ip( -( 4294967296 - $ip ) ) ) . "'";
	}
	elseif( $ip ) {
		$max_results = 5000;
		$resq        = "` WHERE host='" . sprintf( "%s", long2ip( -( 4294967296 - $ip ) ) ) . "'";
	}
	elseif( $thread ) {
		$max_results = 5000;
		$thread      = (int)$thread;
		$resq        = "` WHERE no='$thread' OR resto='$thread'";
	}

	if( $threadmode ) {
		$_tbl = $db_board->qi(SQLLOG);
		if( !$result = $db_board->query( "(SELECT child.*, parent.root proot FROM {$_tbl} child LEFT OUTER JOIN {$_tbl} parent ON child.resto=parent.no) UNION (SELECT *, root proot FROM {$_tbl} parent WHERE resto=0) ORDER BY proot DESC, no ASC LIMIT " . (int)$max_results . " OFFSET " . (int)$from ) ) {
			echo S_SQLFAIL;
		}
	}
	else {
		if( !$result = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)}" . $resq . " ORDER BY no DESC LIMIT " . (int)$max_results . " OFFSET " . (int)$from ) ) {
			echo S_SQLFAIL;
		}
	}

	$j = 0;
	while( $row = $result->fetch(PDO::FETCH_ASSOC) ) { //FIXME use assoc
		$j++;
		$img_flag = false;
		extract( $row, EXTR_OVERWRITE );
		// Format
		//$now=preg_replace('@^(../..)/..@','$1',$now);
		//$now=preg_replace('/\(.*\)/','&nbsp;',$now);
		$fullname = str_replace( '</span> <span class="postertrip">!', ' #', $name );
		$name     = strip_tags( $name );
		$fullname = strip_tags( $name ); //for capcode cleaning

		if( strpos( $sub, 'SPOILER<>' ) !== false ) $sub = substr( $sub, 9 );

		$fullsub = $sub;
		if( strlen( $name ) > 14 ) $name = substr( $name, 0, 15 ) . "...";
		if( strlen( $sub ) > 14 ) $sub = substr( $sub, 0, 15 ) . "...";
		//if( $email ) $name = "<a href=\"mailto:$email\">$name</a>";
		$shortcom = html_entity_decode( preg_replace( "/<[^>]+>/", " ", $com ), ENT_QUOTES, "UTF-8" );
		if( strlen( $shortcom ) > 35 ) $shortcom = substr( $shortcom, 0, 36 ) . "...";
		// Link to the picture
		if( $ext ) {
			$img_flag = true;
			if( !$filedeleted ) {
				if( SQLLOG == "f" ) {
					$filelink = $filename . $ext;
				}
				else {
					$filelink = $tim . $ext;
				}
				$clip = "<a href=\"" . IMG_DIR2 . $filelink . "\" target=_blank>" . $filelink . "</a>";
			}
			else {
				$clip = "<s>" . $filelink . "</s>";
			}
			$size = $fsize / 1024;
			$size = round( $size, 2 ) . " KB";
			$all  = $all + $fsize; //total calculation
			$md5  = substr( $md5, 0, 10 );
		}
		else {
			$clip = "";
			$size = 0;
			$md5  = "";
		}
		$bg = ( $j % 2 ) ? "d0d0f0" : "f6f6f6"; //BG color
		if( $threadmode ) {
			$bg = ( !$resto ) ? "d0f0d0" : "eeffee";
		}

		$displayhost = $host;

		$cboard = explode( "/", $_SERVER[ 'SCRIPT_NAME' ] );
		$cboard = $cboard[ 1 ];

		$bantrue = 0;
		$db_global = YotsubaDB::global();
		if( !$banned = $db_global->query( "SELECT host, board, global, zonly, DATE_FORMAT(length, 'Until %W, %M %D, %Y.') AS buntil FROM {$db_global->qi(SQLLOGBAN)} WHERE host = ? AND active = 1", [$host] ) ) {
			echo S_SQLFAIL;
		}
		$bannedrows = $banned->rowCount();
		if( $bannedrows > 0 ) {
			$row    = $banned->fetch(PDO::FETCH_BOTH);
			$buntil = $row[ 'buntil' ];
			if( $row[ 'board' ] == $cboard ) {
				$bg = "f0d0d0";
				if( $buntil == "" ) $buntil = "Indefinitely.";
				$bantrue = 1;
			}
			if( $row[ 'global' ] == 1 ) {
				$bg = "f0a0a0";
				if( $buntil == "" ) $buntil = "Indefinitely.";
				//$globally = " (Globally)";
				$bantrue = 1;
			}
			elseif( $row[ 'zonly' ] == 1 ) {
				$bg = "a0f0a0";
				if( $buntil == "" ) $buntil = "Indefinitely.";
				$bantrue = 0;
				//$globally = " (".$board.")";
			}
			else {
				//$globally = " (".$board.")";
			}
		}

		echo "<tr bgcolor=\"#$bg\"><td><input type=\"checkbox\" id=\"fake$no\" name=\"$no\" value=\"delete\"></td>";
		if( $resto == 0 ) {
			$spec = "";
			if( $sticky == 1 ) $spec = " color: #800080;";
			if( $permasage == 1 ) $spec = " text-decoration: underline;";
			if( $closed == 1 ) $spec = " color: #FF0000;";
			if( $sticky == 1 && $closed == 1 ) $spec = " color: #808080;";

			echo "<td><a href=\"" . SELF_PATH . "?res=$no\" target=\"_blank\" style=\"font-weight: bold;" . $spec . "\">$no</a></td>";
		}
		else {
			$parentline = ( $threadmode ? "&#x2514;" : "" );
			echo "<td><a href=\"" . SELF_PATH . "?res=$no#$no\" target=\"_blank\">$parentline$no</a></td>";
		}
		echo "<td>$now</td><td title=\"$fullname\" align=\"center\"><b>$name</b></td>";
		echo "<td title=\"$fullsub\">$sub</td><td><span id='short$no' ondblclick='swap(\"full$no\",\"short$no\")' title='Double-click to show full comment'>$shortcom</span><span id='full$no' ondblclick='swap(\"full$no\",\"short$no\")' style='display:none;'>$com</span></td>";
		echo "<td style=\"text-align: center\">$displayhost</td><td><input type=\"button\" value=\"More\" onClick=\"more('" . $no . "a','" . $no . "b');\"></td>\n";
		echo "</tr>\n";
		echo "<tr id=\"" . $no . "a\" bgcolor=\"#a0c0ff\" align=\"center\" style=\"display: none;\">";
		// echo "<td colspan=2>&nbsp;</td>";


		if( $size != 0 ) {
			echo "<td colspan=\"3\"><b>File</b></td>";
			echo "<td colspan=\"5\">&nbsp;</td>";
			echo "</tr>";
			echo "<tr id=\"" . $no . "b\" bgcolor=\"#$bg\" style=\"display: none;\">";
			// echo "<td colspan=2>&nbsp;</td>";
			echo "<td colspan=3 align=\"center\">$clip ($size)</td>";
		}
		elseif( $resto == 0 ) {
			//echo "<td colspan=3 align=\"left\"><b>Text-only thread</b></td>";
			//echo "<td colspan=2>";
			if( $bannedrows > 0 ) {
				echo '<td colspan="6" align="left"><b>Text-only thread</b></td>';
				echo '<td colspan="2"><b>Ban length</b></td>';
			}
			else {
				echo "<td colspan=8 align=\"left\"><b>Text-only thread</b></td>";
			}

			echo "</tr>";
			echo "<tr id=\"" . $no . "b\" bgcolor=\"#$bg\" style=\"display: none;\">";
			$span = 8;
		}
		else {
			echo "<td colspan=\"3\" align=\"center\"><b>Reply to thread</b></td>";
			echo "<td colspan=\"5\">&nbsp;</td>";
			echo "</tr>";
			echo "<tr id=\"" . $no . "b\" bgcolor=\"#$bg\" style=\"display: none;\">";
			//echo "<td colspan=3>&nbsp;</td>";
			echo "<td colspan=\"3\" align=\"center\"><a href=\"" . $SELF_PATH . "?thread=$resto\">$resto</a></td>";
			$span = 5;
		}
		echo "<td colspan=\"$span\" align=\"center\"><input type=\"button\" value=\"Display all posts by IP\" onClick=\"location.href='" . $SELF_PATH . "?ip=" . sprintf( "%u", ip2long( $host ) ) . "'\">&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Delete all posts by IP\" onClick=\"popup('admin=delall&id=$no');\">";
		/*if ($bantrue) {
	   	echo "&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Unban user\" onClick=\"popup('admin=unban&id=$no');\"></td>";
  	} else  {*/
		//  if (!$bantrue) {
		echo "&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Ban user\" onClick=\"popup('admin=ban&id=$no');\">";
		//  }
		//}
		if( $resto == 0 ) {
			echo "&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Thread options\" onClick=\"popup('admin=opt&id=$no');\">";
			if( !$thread ) {
				echo "&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Replies\" onClick=\"location.href='$SELF_PATH?thread=$no'\"></td>";
			}
		}
		echo "</tr>";
	}

	echo "</table><p style=\"margin: 0px; padding: 0px; text-align: center;\"><input type=\"submit\" value=\"" . S_ITDELETES . "$msg\"> ";
	echo "<input type=\"reset\" value=\"" . S_RESET . "\">";
	echo " [<input type=\"checkbox\" name=\"onlyimgdel\" value=\"on\"><!--checked-->" . S_MDONLYPIC . "]</form><br>";

	//$all = (int)($all / 1024);

	//page stuff
	$_count_res = $db_board->query( "SELECT COUNT(*) as Num FROM {$db_board->qi(SQLLOG)}" );
	$total_results = (int)$_count_res->fetch(PDO::FETCH_NUM)[0];
	$total_pages   = ceil( $total_results / $max_results );

	echo "</form><form action=\"" . https_self_url() . "\" method=\"POST\">\n";
	echo "<input type=\"hidden\" name=\"mode\" value=\"admin\"><input type=\"hidden\" name=\"admin\" value=\"del\"><input type=\"hidden\" name=\"user\" value=\"$user\"><input type=\"hidden\" name=\"pass\" value=\"$pass\">\n";

	echo '<center><div class="pagelist" style="float: none!important; display: inline-block;"><div class="prev">';
	if( $p > 1 ) {
		$prev = ( $p - 1 );
		echo "<form action=\"" . https_self_url() . "\" method=\"POST\">\n";
		echo "<input type=\"hidden\" name=\"mode\" value=\"admin\"><input type=\"hidden\" name=\"admin\" value=\"del\"><input type=\"hidden\" name=\"user\" value=\"$user\"><input type=\"hidden\" name=\"pass\" value=\"$pass\">\n";
		echo "<input type=\"hidden\" name=\"p\" value=\"$prev\"><input type=\"submit\" value=\"Previous\"></form>";
	}
	else {
		echo "<span>Previous</span>";
	}

	echo "</div><div class=\"next\">";
	if( $p < $total_pages ) {
		$next = ( $p + 1 );
		echo "<form action=\"" . https_self_url() . "\" method=\"POST\">\n";
		echo "<input type=\"hidden\" name=\"mode\" value=\"admin\"><input type=\"hidden\" name=\"admin\" value=\"del\"><input type=\"hidden\" name=\"user\" value=\"$user\"><input type=\"hidden\" name=\"pass\" value=\"$pass\">\n";
		echo "<input type=\"hidden\" name=\"p\" value=\"$next\"><input type=\"submit\" value=\"Next\"><input type=\"hidden\" name=\"threadmode\" value=\"$threadmode\"></form>";
	}
	else {
		echo "<span>Next</span>";
	}
	echo "</div></div>";
	echo "</center></center>";
	echo str_replace( "12pt", "10pt", $navinc );

	die( "</body></html>" );
}

// return the images/thumbnails for a single post
// $row is an assoc. array representation of the post
function image_files_for( $row )
{
	$del_files = array();
	// we always need to delete the image
	$del_files[ IMG_DIR . $row[ 'tim' ] . $row[ 'ext' ] ] = 1;
	// and the thumbnail
	$del_files[ THUMB_DIR . $row[ 'tim' ] . 's.jpg' ] = 1;
	// and the oekaki replay
	if (ENABLE_OEKAKI_REPLAYS) {
		$del_files[IMG_DIR . $row['tim'] . '.tgkr'] = 1;
	}
	// and the resized mobile images
	if (MOBILE_IMG_RESIZE && $row['m_img']) {
	  $images["{$row['tim']}m.jpg"] = 1;
	}
	
	return $del_files;
}

// delete all posts from an IP, maintaining the consistency of the files and db
function delallbyip($ip, $imgonly, $replies_only = false)
{
	if ($ip === '') {
	  error('Invalid IP');
	}

	$db_board = YotsubaDB::board();

	if ($replies_only) {
		$_rep_sql = ' AND resto > 0';
	}
	else {
		$_rep_sql = '';
	}

	$db_board->lockTable(SQLLOG);
	$query          = $db_board->query("SELECT * FROM {$db_board->qi(SQLLOG)} WHERE archived = 0 AND host = ?" . $_rep_sql, [$ip]);
	$del_files      = array(); // keys = delete these files
	$update_threads = array(); // keys = update these threads' HTML
	$del_threads    = array(); // keys = delete replies to these thread numbers from db
	$del_all        = array(); //  keys = these are being deleted from the db (used to clean up reports etc.)

	while( $row = $query->fetch(PDO::FETCH_ASSOC) ) {
		// we always need to delete the image files
		$del_files += image_files_for( $row );

		if( !$imgonly ) // deleting this post from the db
		{
			$del_all[ $row[ 'no' ] ] = 1;
		}

		if( $row[ 'resto' ] ) { // it's a reply, need to update parent
			$update_threads[ $row[ 'resto' ] ] = 1;
		}
		elseif( !$imgonly ) { // it's a thread parent and it's getting deleted from db
			// need to delete thread html
			if( USE_GZIP == 1 ) {
				// HTML
				$del_files[ RES_DIR . $row[ 'no' ] . PHP_EXT ]         = 1;
				$del_files[ RES_DIR . $row[ 'no' ] . PHP_EXT . '.gz' ] = 1;
				// JSON
				$del_files[ RES_DIR . $row[ 'no' ] . '.json' ] = 1;
				$del_files[ RES_DIR . $row[ 'no' ] . '.json.gz' ] = 1;
			}
			else {
				// HTML
				$del_files [ RES_DIR . $row[ 'no' ] . PHP_EXT ] = 1;
				// JSON
				$del_files[ RES_DIR . $row[ 'no' ] . '.json' ] = 1;
			}

			$del_threads[ $row[ 'no' ] ] = 1;
			$replyquery                  = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)} WHERE resto = ?", [$row[ 'no' ]] );
			while( $replyrow = $replyquery->fetch(PDO::FETCH_ASSOC) ) {
				$del_files += image_files_for( $replyrow );
				$del_all[ $replyrow[ 'no' ] ] = 1;
			}
			$replyquery->closeCursor();
		}

		{
			$auser   = $_COOKIE[ '4chan_auser' ];
			$adfsize = ( $row[ 'fsize' ] > 0 ) ? 1 : 0;
			$adname  = str_replace( '</span> <span class="postertrip">!', '#', $row[ 'name' ] );
			if( $imgonly ) {
				$imgonly = 1;
			}
			else {
				$imgonly = 0;
			}
			//$row['sub']      = mysql_escape_string( $row['sub'] );
			//$row['com']      = mysql_escape_string( $row['com'] );
			//$row['filename'] = mysql_escape_string( $row['filename'] );
			validate_admin_cookies();
			$_db_del = YotsubaDB::global();
			$_db_del->query( "INSERT INTO {$_db_del->qi(SQLLOGDEL)} (imgonly, postno, resto, board, name, sub, com, img, filename, admin, email, admin_ip, tool) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'del-all-by-ip')", [$imgonly, $row[ 'no' ], $row[ 'resto' ], SQLLOG, $adname, $row[ "sub" ], $row[ "com" ], $adfsize, $row[ "filename" ].$row['ext'], $auser, $row[ 'email' ], $_SERVER['REMOTE_ADDR']]);
		}
	}
	$query->closeCursor();

	// delete IP's posts
	if( !$imgonly ) {
		$db_board->query( "DELETE FROM {$db_board->qi(SQLLOG)} WHERE host = ?" . $_rep_sql, [$ip] );
		// delete replies to IP's parent posts
		foreach( $del_threads as $parent => $unused ) {
			$db_board->query( "DELETE FROM {$db_board->qi(SQLLOG)} WHERE resto = ?", [$parent] );
		}
	}
	else {
		$db_board->query( "UPDATE {$db_board->qi(SQLLOG)} SET filedeleted = 1, root = root WHERE host = ?" . $_rep_sql, [$ip] );
	}
	$db_board->unlockTables();

	// delete all necessary files (images and HTML)
	foreach( $del_files as $file => $unused ) {
		@unlink( $file );

		if( CLOUDFLARE_PURGE_ON_DEL && strpos( $file, IMG_DIR ) !== false ) {
			$filename    = basename( $file );
			cloudflare_purge_by_basename(BOARD_DIR, $filename);
		}
	}

	// delete reports for deleted posts
	$db_global = YotsubaDB::global();
	foreach( $del_all as $no => $unused ) {
		$db_global->query( "DELETE FROM {$db_global->qi('reports')} WHERE board = ? AND no = ?", [SQLLOG, $no] );
		$db_global->query( "DELETE FROM {$db_global->qi('reports_for_posts')} WHERE board = ? AND postid = ?", [SQLLOG, $no] );
	}

	echo "<br><strong>Deleting posts...</strong><br>";
	if( $imgonly ) {
		echo "All images deleted.<br><strong>Deletion successful!</strong><br>";
	}
	else {
		echo "All posts deleted.<br><strong>Deletion successful!</strong><br>";
	}

	// rebuild html
	if( count( $update_threads ) > 25 ) {
		echo "Rebuilding all pages...";
		echo ( rebuild_all( $error ) ? " OK!" : $error ); // at some number of threads, this must be faster...
	}
	else {
		foreach( $update_threads as $parent => $unused ) {
			if( $del_threads[ $parent ] ) continue; // this thread was deleted, forget it

			echo "Rebuilding No.$parent...";
			echo ( rebuild_thread( $parent, $error ) ? " OK!" : $error );
			echo "<br>";
		}
	}

	die( "<br><strong>Rebuild successful!</strong><span style=\"display:none\">Done.</span>" );
}

function admindelall()
{
	global $onlyimgdel, $onlyrepdel, $id, $user, $pass;
	$delno   = array();
	$delflag = false;
	foreach( $_POST as $key => $value ) {
		$item = array( 0 => $key, 'key' => $key, 1 => $value, 'value' => $value );
		if( $item[ 1 ] == 'delete' ) {
			array_push( $delno, intval( $item[ 0 ] ) );
			$delflag = true;
		}
	}
	if( $delflag ) {
		$db_board = YotsubaDB::board();
		if( !$result = $db_board->query( "SELECT host FROM {$db_board->qi(SQLLOG)} WHERE archived = 0 AND no = ?", [(int)$id] ) ) {
			echo S_SQLFAIL;
		}
		$row = $result->fetch(PDO::FETCH_NUM);
		list( $host ) = $row;
		delallbyip($host, $onlyimgdel, $onlyrepdel === true);
	}
	echo "<input type=\"hidden\" name=\"mode\" value=\"admin\">\n";
	echo "<input type=\"hidden\" name=\"admin\" value=\"delall\">\n";
	echo "<input type=\"hidden\" name=\"user\" value=\"$user\">\n";
	echo "<input type=\"hidden\" name=\"pass\" value=\"$pass\">\n";
	echo "<input type=\"hidden\" name=\"id\" value=\"$id\">\n";
	echo "<input type=\"hidden\" name=\"$id\" value=\"delete\">\n";
	echo "<input type=\"hidden\" name=\"onlyimgdel\" value=\"on\">\n";
	echo "<input type=\"submit\" value=\"Delete images only\">\n";
	echo "</form><form \"action=\"" . https_self_url() . "\" method=\"POST\">\n";
	echo "<input type=\"hidden\" name=\"mode\" value=\"admin\">\n";
	echo "<input type=\"hidden\" name=\"admin\" value=\"delall\">\n";
	echo "<input type=\"hidden\" name=\"pass value=\"$pass\">\n";
	echo "<input type=\"hidden\" name=\"id\" value=\"$id\">\n";
	echo "<input type=\"hidden\" name=\"$id\" value=\"delete\">\n";
	echo "<input type=\"submit\" value=\"Delete all posts\">\n";
	echo "</form>\n";
	die( "</body></html>" );
}

function ban_template_js($post_has_file = true, $is_thread = false) {
  $templates = array();
  
  $level_map = get_level_map();
  
  $db = YotsubaDB::global();
  $query = "SELECT * FROM {$db->qi('ban_templates')} ORDER BY LENGTH(rule), rule ASC";
  $q = $db->query($query);

  while ($r = $q->fetch(PDO::FETCH_ASSOC)) {
    if (!preg_match('#^(global|' . BOARD_DIR . ')[0-9]+$#', $r[ 'rule' ])) {
      continue;
    }
    
    if (($r['no'] == 1 || $r['no'] == 123 || $r['no'] == 213) && !$post_has_file) {
      continue;
    }
    
    if ($r['no'] == 6 && !DEFAULT_BURICHAN) {
      continue;
    }
    
    if ($r['no'] == 17 && (BOARD_DIR === 'mlp' || BOARD_DIR === 'trash')) {
      continue;
    }
    
    if ($r['no'] == 223 && BOARD_DIR === 'pol') {
      continue;
    }
    
    // Global 3 - Troll posts
    if ($r['no'] == 222 && BOARD_DIR === 's4s') {
      continue;
    }
    
    // Global 16 - Request Thread Outside of /r/
    if ($r['no'] == 59 && BOARD_DIR === 'po') {
      continue;
    }
    
    // Global 3
    if ((BOARD_DIR === 'b' || BOARD_DIR === 'bant') && strpos($r['rule'], 'global3') !== false) {
      continue;
    }
    
    // Skip OP-only templates
    if ($r['postban'] === 'move' && !$is_thread) {
      continue;
    }
    
    if ($level_map[$r['level']] !== true) {
      continue;
    }
    
    unset($r['special_action']);
    
    $templates[] = $r;
  }
  
  return '
  <script type="text/javascript" src="//s.4cdn.org/js/admin_autocomplete.10.js"></script>
  <script>
  var e_template = document.getElementsByName("template")[0];
  var globalTemplates = ' . json_encode( $templates, JSON_PARTIAL_OUTPUT_ON_ERROR ) . ';
  var templates = {};
  var localTemplates = {};

  function $(e) {return document.getElementsByName(e)[0];}
  function unhide(e) {$(e).style.visibility="visible";}

  function chooseTemplate() {
    var i = e_template.selectedIndex - 1;
    
    Feedback.checkTemplate(i);
    
    if (i < 0) {
      return;
    }

    var t = templates[i];

    $("pubreason").value = t.publicreason;
    $("pvtreason").value  = t.privatereason;
    $("days").value = (t.banlen == "" && t.days > 0) ? t.days : "";
    $("warn").checked = (t.banlen == "" && t.days == 0);
    $("indefinite").checked = (t.banlen == "indefinite");
    $("banmsg").checked = t.publicban==1;
    $("bantype").value = t.bantype;
    
    $("postban").value = t.postban;
    
    if (t.postban === "move") {
      document.getElementById("js-move-board-sel").value = t.postban_arg;
    }
    
    $("templateno").value = t.no;
    
    onPostBanSelChange.call(document.getElementById("js-postban-sel"));
    undisableForm();
  }

  function undisableForm() {
    var f = document.querySelectorAll("*[disabled=disabled]");
    var len = f.length;

    for( var i = 0; i < len; i++ ) {
      f[i].removeAttribute("disabled");
    }
  }

  function updateTemplate() {
    var t = {};
    var name = prompt("Enter a name for this template");

    t.banlen = $("indefinite").checked ? "indefinite" : "";
    t.bantype = $("bantype").value;
    //t.blacklist;
    t.days = ($("warn").checked) ? 0 : $("days").value;
    t.name = name;
    t.postban = $("postban").value;
    t.publicreason = $("pubreason").value;
    t.privatereason = $("pvtreason").value;

    localTemplates[name] = t;
    localStorage.setItem("ban_templates", JSON.stringify(localTemplates));

    initTemplate();

    return false;
  }

  function deleteTemplate() {
    var i = e_template.selectedIndex - 1;

    if (i >= globalTemplates.length)
      delete localTemplates[templates[i].name];

    localStorage.setItem("ban_templates", JSON.stringify(localTemplates));
    initTemplate();

    return false;
  }

  function initTemplate() {
    templates = globalTemplates;
    
    e_template.innerHTML = "<option value=\"-1\">None Selected (Required)</option>";

    for (var i=0;i<templates.length;i++) {
      var t = templates[i];
      //if( !t.name.match(/Global/) && !t.name.match(/\/' . BOARD_DIR . '\//) && i < globalTemplates.length ) continue;

      var o = document.createElement("option");
      o.value = i;
      o.innerHTML = t.name + ((i < globalTemplates.length) ? "" : " [Local]");
      e_template.appendChild(o);
    }
    unhide("template_row");
    if (localStorage && false == true) {
      unhide("local_template_row");
      unhide("deltemplate");
    }
  }

  initTemplate();
  </script>
  ';
}

function do_post_quarantine( $board, $post )
{
	/*
	Gathers -
	Current post, current post image
	All images of posts in the same thread
	*/

	$db_board = YotsubaDB::board();
	$db_global = YotsubaDB::global();
	$db_board->lockTable(SQLLOG);
	$host = $post[ "host" ];

	$post_json = make_post_json($post);
	$postno = $post["no"];

	$xffres = $db_global->query("SELECT xff FROM {$db_global->qi('xff')} WHERE board = ? AND postno = ?", [$board, $postno]);
	if ($xffres->rowCount()) $xff = $xffres->fetch(PDO::FETCH_ASSOC)["xff"];
	$db_global->query("INSERT INTO {$db_global->qi('ncmec_reports')} (board, post_num, post_json, xff) VALUES (?, ?, ?, ?)", [$board, $postno, $post_json, $xff]);
	$reportid = $db_global->lastInsertId();
	
	$path = "/www/quarantine/$reportid";
	mkdir( $path );
	
	$image = $post[ "tim" ] . $post[ "ext" ];
	$dst_path = "$path/$image";
	$tmp_path = $dst_path.".tmp";
	@copy( IMG_DIR . "/$image", $tmp_path );
	@rename($tmp_path, $dst_path);
	
	if (!file_exists($dst_path)) {
		// guess we can't quarantine it after all
		$db_global->query("DELETE FROM {$db_global->qi('ncmec_reports')} WHERE id = ?", [$reportid]);
	} else {
		$resto = $post["resto"];
		$respred = $resto ? "no=$resto or resto=$resto" : "resto=$postno";
		$q = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)} WHERE host = ? AND no != ? AND ($respred)", [$host, $postno] );
		while( $p = $q->fetch(PDO::FETCH_ASSOC) ) {
			$i = $p[ "tim" ] . $p[ "ext" ];
			mkdir( "$path/images" );
			@copy( IMG_DIR . "/$i", "$path/images/$i" );
		}
	}
	$db_board->unlockTables();
}

function do_template_special_action($template, $board, $row, $is_manager = false) {
  if ($template['special_action'] === 'quarantine') {
    do_post_quarantine($board, $row);
  }
  
  if ($is_manager) {
    if( $template['special_action'] === 'quarantine' || $template['special_action'] === 'revokepass_spam' || $template['special_action'] === 'revokepass_illegal') {
      $pass = $row['4pass_id'];
      $status = $template['special_action'] === 'revokepass_spam' ? 4 : 5;
      $db_global = YotsubaDB::global();
      $db_global->query("UPDATE {$db_global->qi('pass_users')} SET status = ? WHERE user_hash = ? AND status = 0 LIMIT 1", [$status, $pass]);
    }
  }
}

/**
 * Auto-rangeban log entries
 * $tpl_id: ban or BR template id
 * $source: 1 = ban, 0 = ban request
 */
function process_auto_rangeban($ip, $browser_id, $thread_id, $post_id, $tpl_id, $source) {
  $thread_id = (int)$thread_id;
  
  if (!$browser_id) {
    return false;
  }
  
  $db = YotsubaDB::global();
  // Prune stale entries
  $sql = "DELETE FROM {$db->qi('event_log')} WHERE type = 'rangeban_hint' AND created_on < " . $db->dateInterval('NOW()', 1, 'HOUR');

  $res = $db->query($sql);

  if (!$res) {
    return false;
  }
  
  $need_rangeban = false;
  
  // Check if should apply auto rangeban (2 strikes for BRs, immediate for Bans)
  $range_sql = explode('.', $ip);
  
  $range_sql = "{$range_sql[0]}.{$range_sql[1]}.%";
  
  // Ban
  if ($source === 1) {
    $need_rangeban = true;
  }
  // Ban Request
  else {
    $sql = "SELECT COUNT(DISTINCT ip) FROM {$db->qi('event_log')} WHERE "
      . "type = 'rangeban_hint' AND board = ? AND thread_id = ? AND ua_sig = ? "
      . "AND ip LIKE ?";

    $res = $db->query($sql, [BOARD_DIR, $thread_id, $browser_id, $range_sql]);

    if (!$res) {
      return false;
    }

    $count = (int)$res->fetch(PDO::FETCH_NUM)[0];
    
    if ($count > 0) {
      $need_rangeban = true;
    }
  }
  
  if ($need_rangeban) {
    // Skip if a rangeban already exists
    $sql = "SELECT COUNT(*) FROM {$db->qi('event_log')} WHERE "
      . "type = 'rangeban' AND board = ? AND thread_id = ? AND ua_sig = ? "
      . "AND ip LIKE ? AND created_on > " . $db->dateInterval('NOW()', 1, 'HOUR');

    $res = $db->query($sql, [BOARD_DIR, $thread_id, $browser_id, $range_sql]);

    if (!$res) {
      return false;
    }

    $count = (int)$res->fetch(PDO::FETCH_NUM)[0];
    
    if ($count > 0) {
      return true;
    }
    
    return add_auto_rangeban_log($ip, $browser_id, $thread_id, $post_id, true, $tpl_id, $source);
  }
  
  // Add hint entry
  return add_auto_rangeban_log($ip, $browser_id, $thread_id, $post_id, false, $tpl_id, $source);
}

function add_auto_rangeban_log($ip, $browser_id, $thread_id, $post_id, $is_ban = false, $tpl_id = 0, $source = 0) {
  if ($is_ban) {
    $type = 'rangeban';
  }
  else {
    $type = 'rangeban_hint';
  }
  
  return write_to_event_log($type, $ip, [
    'board' => BOARD_DIR,
    'thread_id' => $thread_id,
    'post_id' => $post_id,
    'ua_sig' => $browser_id,
    'arg_num' => $tpl_id,
    'arg_str' => (int)$source
  ]);
}

/**
 * Collects posts related to the provided Password.
 * This is used for banning people who hop between multiple IPs.
 * Only posts made from non-mobile devices are collected.
 */
function admin_collect_related($ip, $pwd) {
  if (!$pwd || !$ip) {
    return null;
  }
  
  $range_sql = explode('.', $ip);
  
  $range_sql[0] = (int)$range_sql[0];
  $range_sql[1] = (int)$range_sql[1];
  
  $range_sql = "{$range_sql[0]}.{$range_sql[1]}.";
  
  $db_board = YotsubaDB::board();
  $sql = "SELECT host, {$db_board->qi('4pass_id')} FROM {$db_board->qi(BOARD_DIR)} "
    . "WHERE archived = 0 AND pwd = ? "
    . "AND host NOT LIKE ? "
    . "AND email NOT LIKE '1%' "
    . "GROUP BY host";

  $res = $db_board->query($sql, [$pwd, $range_sql . '%']);

  if (!$res) {
    return null;
  }

  $data = [];

  while ($post = $res->fetch(PDO::FETCH_ASSOC)) {
    $data[] = $post;
  }
  
  return $data;
}

function admin_get_template_by_id($tpl_id) {
  $tpl_id = (int)$tpl_id;
  $db = YotsubaDB::global();
  $res = $db->query("SELECT * FROM {$db->qi('ban_templates')} WHERE no = ? LIMIT 1", [$tpl_id]);
  if (!$res) {
    return false;
  }
  return $res->fetch(PDO::FETCH_ASSOC);
}

function admin_is_ip_rangebanned($ip) {
  require_once 'lib/geoip2.php';

  $db = YotsubaDB::global();

  $_asninfo = GeoIP2::get_asn($ip);

  if ($_asninfo) {
    $asn = (int)$_asninfo['asn'];
  }
  else {
    $asn = 0;
  }

  if ($asn > 0) {
    $res = $db->query(
      "SELECT id FROM {$db->qi('iprangebans')} WHERE asn = ? "
      . "AND active = 1 AND boards = '' AND expires_on = 0 AND report_only = 0 AND ops_only = 0 "
      . "AND lenient = 0 AND img_only = 0 LIMIT 1",
      [$asn]
    );

    if (!$res) {
      return false;
    }

    if ($res->rowCount() > 0) {
      return true;
    }
  }

  $long_ip = ip2long($ip);

  if (!$long_ip) {
    error('Invalid IP.');
  }

  $res = $db->query(
    "SELECT id FROM {$db->qi('iprangebans')} WHERE range_start <= ? AND range_end >= ? "
    . "AND active = 1 AND boards = '' AND expires_on = 0 AND report_only = 0 LIMIT 1",
    [$long_ip, $long_ip]
  );

  if (!$res) {
    return false;
  }

  return $res->rowCount() > 0;
}

// Signs the ip + timestamp for authenticating reverse dns requests below
// FIXME: This is to avoid delaying ban panels
function admin_get_rev_ip_sig($ip, $t) {
  if (!$ip || !$t) {
    return false;
  }
  
  $secret = 'BusEFdduVhgVKIMAx1ndhvzrgMyA5uCcfRnvIKq4+0X2vL8elzf6wHZCpWS9fsTsNG/XdlwiIBV68hzlGm6sGQ==';
  $secret = base64_decode($secret);
  
  if (!$secret) {
    return false;
  }
  
  $msg = "$ip $t";
  
  return hash_hmac('sha256', $msg, $secret);
}

// Prints a JSON response with the hostname of the IP
// FIXME: This is to avoid delaying ban panels
// The IP needs to be in the long int format
function admin_reverse_ip() {
  if (!isset($_GET['ip']) || !isset($_GET['t']) || !isset($_GET['s'])) {
    die('N/A');
  }
  
  if (!$_GET['t'] || !$_GET['s']) {
    die('N/A');
  }
  
  $ip = long2ip($_GET['ip']);
  
  if (!$ip) {
    die('N/A');
  }
  
  if ($_SERVER['REQUEST_TIME'] - (int)$_GET['t'] > 3) {
    die('N/A');
  }
  
  $sig = admin_get_rev_ip_sig($_GET['ip'], $_GET['t']);
  
  if (!$sig) {
    die('N/A');
  }
  
  if (hash_equals($sig, $_GET['s']) !== true) {
    die('N/A');
  }
  
  $rev = gethostbyaddr($ip);
  
  if ($rev && $rev == $ip) {
    $rev = '';
  }
  
  header('Content-Type: application/json');
  echo json_encode(['rev' => $rev]);
}

/* Admin banning */
function adminban()
{
  if (BOARD_DIR == 'j' && !has_level('manager')) {
    die();
  }
  
	global $id, $user, $pass;
	
  $by_tpl_mode = false;
  
  // for async calls from reports.4chan.org
  if (isset($_POST['by_tpl']) && $_POST['by_tpl']) {
    $template = admin_get_template_by_id($_POST['by_tpl']);
    
    if (!$template) {
      die('No such template');
    }
    
    $by_tpl_mode = true;
    
    $_POST['submit'] = 1;
    $_POST['pubreason'] = $template['publicreason'];
    $_POST['pvtreason'] = $template['privatereason'];
    $_POST['days'] = $template['days'];
    $_POST['warn'] = (int)($template['days'] == 0 && $template['banlen'] == '');
    $_POST['indefinite'] = (int)($template['banlen'] === 'indefinite');
    $_POST['banmsg'] = 0;
    $_POST['bantype'] = $template['bantype'];
    
    // This will be amended later for delall -> delallrep
    $_POST['postban'] = $template['postban'];
    
    if ($template['postban'] === 'move' && $template['postban_arg']) {
      $_POST['move-board'] = $template['postban_arg'];
    }
  }
  else {
    $template = null;
  }
  
	$submit        = $_POST[ 'submit' ];
	$start_time    = microtime( true );
	$xff           = htmlspecialchars($_POST[ 'xff' ], ENT_QUOTES);
	$pubreason     = nl2br( htmlspecialchars( $_POST[ 'pubreason' ] ), false );
	$pvtreason     = nl2br( htmlspecialchars( $_POST[ 'pvtreason' ] ), false );
	$reason        = "$pubreason<>$pvtreason";
	$bannedby      = $_COOKIE['4chan_auser'];
	$days          = $_POST[ 'days' ];
	$warn          = $_POST[ 'warn' ];
	$indefinite    = $_POST[ 'indefinite' ];
	$banmsg        = $_POST[ 'banmsg' ] == 1;
	$globalban     = $_POST[ 'bantype' ] == 'global';
	$zonly         = isset($_POST['zonly']) && $_POST['zonly'] === '1';
	//$pass_id       = htmlspecialchars($_POST[ 'pass_id' ], ENT_QUOTES);
	$board         = BOARD_DIR;
	$postid        = (int)$id;
  
  if ($by_tpl_mode) {
    $template_used = (int)$_POST['by_tpl'];
  }
  else {
    $template_used = (int)$_POST['templateno'];
  }
	
	$db_board = YotsubaDB::board();
	if( !$result = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)} WHERE no = ?", [$postid] ) ) {
		die( 'Post no longer exists.<script language="JavaScript">setTimeout("self.close()", 3000); postBack("error-ban-' . $board . '-' . $postid . '");</script>' );
	}
	$row = $result->fetch(PDO::FETCH_ASSOC);
	if( $row === false ) die( 'Post no longer exists.<script language="JavaScript">setTimeout("self.close()", 3000); postBack("error-ban-' . $board . '-' . $postid . '");</script>' );
	
	if ($row['archived']) {
	  die('This post is archived.<script language="JavaScript">setTimeout("self.close()", 3000); postBack("error-ban-' . $board . '-' . $postid . '");</script>');
	}
  
	$post_has_file = $row['ext'] && !$row['file_deleted'];
	
	//list( $no, $sticky, $permasage, $closed, $now, $name, $email, $sub, $com, $host, $pwd, $filename, $ext, $w, $h, $tn_w, $tn_h, $tim, $time, $md5, $fsize, $root, $resto ) = $row;
	extract( $row, EXTR_OVERWRITE );
  
  $password = $pwd;
  
  // insert tripcode (trip or !sectrip) if not warning
  $tripcode = '';
  
  if ($warn != 1) {
    $name_bits = explode('</span> <span class="postertrip">!', $name);
    
    if ($name_bits[1]) {
      $tripcode = preg_replace('/<[^>]+>/', '', $name_bits[1]); // fixme: why do we do that?
    }
  }
	
	$name = str_replace( '</span> <span class="postertrip">!', ' #', $name );
	$name = preg_replace( '/<[^>]+>/', '', $name ); // remove all remaining html crap

	if( !$result = $db_board->query( "SELECT COUNT(*) FROM {$db_board->qi(SQLLOG)} WHERE host = ? AND no = ?", [$host, $resto] ) ) {
		echo S_SQLFAIL;
	}

	if ((int)$result->fetch(PDO::FETCH_NUM)[0] || $resto == 0) {
		$poster_is_op = true;
	}
	else {
		$poster_is_op = false;
	}

if( $submit != "" ) { // pressed submit
	if (!$host) {
    error('You cannot ban this post');
  }
  
	if ($host) {
		$reverse = gethostbyaddr($host);
	}
	else {
		$reverse = '';
	}
  
	$displayhost = ( $reverse && $reverse != $host ) ? "$reverse ($host)" : $host;
  
	if ($template_used > -1) {
    if (!$template) {
      $db_tpl = YotsubaDB::global();
      $_tpl_res = $db_tpl->query("SELECT * FROM {$db_tpl->qi('ban_templates')} WHERE no = ?", [$template_used]);
      $template = $_tpl_res->fetch(PDO::FETCH_ASSOC);
      $_tpl_res->closeCursor();
    }
	  
	  if (!$template) {
      error('Invalid template');
	  }
	  
    if (!has_level($template['level'])) {
      error('You cannot use this template');
    }
    
    if (($template['no'] == 1 || $template['no'] == 123 || $template['no'] == 213) && !$post_has_file) {
      error('This template requires a post with a file');
    }
  }
	
	if( !$template_used ) {
		$rule = '';
	}
	else {
		$rule = $template[ 'rule' ];
	}
  
	if( !$row ) {
		echo "This post doesn't exist anymore.<br>";
		die( "[<a href=\"javascript:void(0)\" onclick=\"history.back()\">Back</a>]</body></html>" );
	}
	if( $pubreason == "" ) {
		echo "Public reason not specified.<br>";
		die( "[<a href=\"javascript:void(0)\" onclick=\"history.back()\">Back</a>]</body></html>" );
	}
	elseif( $bannedby == "" ) {
		echo "Admin name not specified.<br>";
		die( "[<a href=\"javascript:void(0)\" onclick=\"history.back()\">Back</a>]</body></html>" );
	}
	elseif( !is_numeric( $days ) && ( $indefinite != 1 ) && ( $warn != 1 ) ) {
		echo "Length of ban not specified.<br>";
		die( "[<a href=\"javascript:void(0)\" onclick=\"history.back()\">Back</a>]</body></html>" );
	}
	else {
		if( $warn != 1 ) {
			$ubd_ts = date( "Y-m-d H:i:s", time() + $days * ( 24 * 60 * 60 ) );
		}
		else {
			$ubd_ts = date( "Y-m-d H:i:s", time() );
		}
		if( $indefinite == 1 ) {
			$length = "00000000000000";
		}
		else {
			$length = $ubd_ts;
		}
	}
  
	$is_manager = has_level('manager');
	
	if (!$is_manager) {
	  $zonly = 0;
	}
	
	$nrow = array();

	foreach( $row as $key => $val ) {
		if( ctype_digit( $val ) || is_int( $val ) ) {
			$val = (int)$val;
		}
		$nrow[ $key ] = $val;
	}
	
  if ($row['resto']) {
    $sub_query = $db_board->query("SELECT sub FROM {$db_board->qi($board)} WHERE no = ?", [$row['resto']]);
    $sub_res = $sub_query->fetch(PDO::FETCH_ASSOC);
    if ($sub_res) {
      $rel_sub = $sub_res['sub'];

      if (strpos($rel_sub, 'SPOILER<>') === 0) {
        $rel_sub = substr($rel_sub, 9);
      }

      if ($rel_sub !== '') {
        $nrow['rel_sub'] = $rel_sub;
      }
    }
  }

  // FIXME: email field
  if (isset($row['email'])) {
    $nrow['ua'] = $row['email'];
    unset($nrow['email']);
  }
  
  $post_json = json_encode($nrow);
  $no_thumb = false;
  
  if ($template && $template['save_post'] !== 'everything') {
    $no_thumb = true;
  }
  
	$db_global_ins = YotsubaDB::global();
	$result = $db_global_ins->query( "INSERT INTO {$db_global_ins->qi(SQLLOGBAN)} (board, global, zonly, name, host, reverse, xff, reason, length, admin, md5, {$db_global_ins->qi('4pass_id')}, post_num, rule, post_time, post_json, template_id, admin_ip, tripcode, password) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " . $db_global_ins->fromUnixtime('?') . ", ?, ?, ?, ?, ?)", [$board, $globalban, $zonly, $name, $host, $reverse, $xff, $reason, $length, $bannedby, $md5, $row[ '4pass_id' ], $no, $rule, $time, $post_json, $template_used, $_SERVER['REMOTE_ADDR'], $tripcode, $password] );

	if( !$result ) {
		echo S_SQLFAIL;
	}
  
	if( $ext != '' && $template_used && !$no_thumb ) {
		$salt = file_get_contents( SALTFILE );
		$hash = sha1( BOARD_DIR . $no . $salt );
		@copy( THUMB_DIR . "{$tim}s.jpg", BANTHUMB_DIR . "{$hash}s.jpg" );
	}

	if( $banmsg ) {
		if( $warn ) {
			$samessage = S_USERWARNEDFORPOST;
		}
		else {
			$samessage = S_USERBANNEDFORPOST;
		}

		//if( isset( $_GET[ 'santa' ] ) && $_GET[ 'santa' ] == 'hohoho' ) $samessage = 'USER WAS GIVEN COAL FOR THIS POST';
		
		if (($is_manager || has_flag('banmsg')) && isset($_POST['custombanmsg']) && $_POST['custombanmsg'] != '') {
		  $samessage = htmlspecialchars($_POST['custombanmsg'], ENT_QUOTES);
		}

		if( !$result = $db_board->query( "UPDATE {$db_board->qi(SQLLOG)} SET root=root, com=" . $db_board->concat('com', '?') . " WHERE no = ?", [' <br><br><strong style="color: red;">(' . $samessage . ')</strong>', $postid] ) ) {
			echo S_SQLFAIL;
		}
		$db_board->query("UPDATE {$db_board->qi(SQLLOG)} SET root=root, last_modified=? WHERE no=?", [(int)$_SERVER['REQUEST_TIME'], ($resto ? $resto : $postid)]);
		
		if ($_POST['postban'] !== 'delpost' && $_POST['postban'] !== 'move' && $_POST['postban'] !== 'archive') {
		  admin_clear_reports(BOARD_DIR, $postid);
		}
	}
	
	//print "\n<br>insert: " . (time()  - $start_time)."\n<br>"; //disabling this because again nobody needs to see it/leaks filepaths
	echo "<strong>Banning " . $displayhost . " from ";
	
	if( $globalban == 1 ) {
		echo "the entirety of 4chan...</strong><br>";
		//append_ban( "global", $host );
	}
	else {
		echo "/" . $board . "/...</strong><br>";
		//append_ban( $board, $host );
	}
	
	if( $length == "00000000000000" ) {
		echo " for an indefinite amount of time.";
	}
	else {
		echo " until " . date( 'l, F jS, Y', time() + $days * ( $warn ? 0 : 24 * 60 * 60 ) ) . ".<br><strong>Ban successful!</strong>";
	}
	//print "\n<br>rebuild : " . (microtime(1) - $start_time); //disabling because no point in showing it/leaks file paths
	if( $template ) {
    $db_global_ban = YotsubaDB::global();
    $inserted_ban_id = $db_global_ban->lastInsertId();
		do_template_special_action( $template, $board, $row, $is_manager );
		if( ( $template[ "blacklist" ] == "image" || $template[ 'blacklist' ] == 'rejectimage' ) && $md5 ) {
			$blban = (int)( $template[ 'blacklist' ] === 'image' );
			$len   = $blban ? $template['days'] : '0';
			$db_global_ban->query( "INSERT INTO {$db_global_ban->qi('blacklist')} (field, contents, description, addedby, ban, banlength, banreason) VALUES ('md5', ?, ?, ?, ?, ?, ?)",
				[$md5, $template[ "name" ] . " (via ban template, ban ID: $inserted_ban_id)", $bannedby, $blban, $len, $template[ "publicreason" ]] );
		}
	}
  
  // Auto-rangebans processing (bans)
  // FIXME: email field
  $_post_meta = decode_user_meta($row['email']);
  
  if (!$warn && $_post_meta && $_post_meta['is_mobile']) { // mobile devices only
    // global rules only
    if ($template && strpos($template['rule'], 'global') !== false) {
      process_auto_rangeban($host, $_post_meta['browser_id'], $row['resto'], $row['no'], $template['no'], 1);
    }
    
    // Collect and ban other IPs based on the password
    /*
    $related_posts = admin_collect_related($host, $password);
    
    if ($related_posts) {
      write_to_event_log('rel_posts', $host, [
        'board' => BOARD_DIR,
        'thread_id' => $row['resto'],
        'post_id' => $no,
        'pwd' => $password,
        'arg_str' => $rule,
        'meta' => json_encode($related_posts)
      ]);
    }
    */
  }
  
	$should_delete = $_POST[ 'postban' ] == 'delpost' || $_POST[ 'postban' ] == 'delfile';
	
  $skip_rebuild = false;
  
	if( $should_delete ) {
		echo "<br>";
		if (delete_post($no, $_POST[ 'postban' ] == 'delfile' ? 1 : 0, $template ? $template['no'] : false, 'ban')) {
			echo ( ( $_POST[ 'postban' ] == 'delfile' ) ? "<strong>File deleted.</strong>" : "<strong>Post deleted.</strong>" );
		}
    // Fixme, this is for the temporary is2/is3 cache purging api
    if ($ext != '' && $template_used && $template['rule'] == 'global1' && !UPLOAD_BOARD) {
      //purge_cache_internal_temp(BOARD_DIR, "$tim$ext");
    }
		//print "\n<br>delete post: " . (microtime(true) - $start_time); //disabling, no point and leaks dirs
	}
	else if ($resto == 0) {
    if ($_POST['postban'] == 'move') {
      if (!isset($_POST['move-board']) || !is_board_valid($_POST['move-board'])) {
        echo ('<strong>Invalid destination board. The thread was not moved.</strong>');
      }
      else {
        move_thread($no, $_POST['move-board']);
        
        echo ('<br><strong>Thread moved to /' . htmlspecialchars($_POST['move-board']) . '/.</strong>');
        
        $skip_rebuild = true;
      }
    }
    else if ($_POST['postban'] === 'archive') {
      archive_thread($no);
      
      echo ('<br><strong>Thread archived.</strong>');
      
      $skip_rebuild = true;
    }
    else if ($_POST['postban'] === 'close') {
      if ($db_board->query("UPDATE {$db_board->qi(BOARD_DIR)} SET closed = 1 WHERE no = ? LIMIT 1", [$no])) {
        log_thread_opts_action($row, $row['sticky'], $row['permasage'], 1, $row['permaage'], $row['undead']);
        echo ('<br><strong>Thread closed.</strong>');
      }
      else {
        echo ('<br><strong>Could not close thread.</strong>');
      }
    }
    else if ($_POST['postban'] === 'permasage') {
      if ($db_board->query("UPDATE {$db_board->qi(BOARD_DIR)} SET permasage = 1 WHERE no = ? LIMIT 1", [$no])) {
        log_thread_opts_action($row, $row['sticky'], 1, $row['closed'], $row['permaage'], $row['undead']);
        echo ('<br><strong>Thread perma-saged.</strong>');
      }
      else {
        echo ('<br><strong>Could not perma-sage thread.</strong>');
      }
    }
	}
	
	echo '<script language="JavaScript">setTimeout("self.close()", 3000); postBack("done-ban-' . $board . '-' . $no . '");</script>';
	if( $banmsg && !$should_delete && !$skip_rebuild) { //need to update log because of the ban message
		rebuild_thread( ( $resto ) ? $resto : $no );
	}
	
  // Delete all posts by IP, including threads
  if ($_POST['postban'] === 'delall') {
    delallbyip($host, false);
  }
  // Delete only replies by IP
  else if ($_POST['postban'] === 'delallrep') {
    // Delete the thread if the target post is an OP
    if (!$resto) {
      delete_post($no, 0, $template ? $template['no'] : false, 'ban');
    }
    
    delallbyip($host, false, true);
  }
	
	//print "\n<br>total time: " . (microtime(1) - $start_time); //dont need to display this
} else {
	// Banning screen display
	$adminuser = $_COOKIE[ '4chan_auser' ];
	// see if user is banned
	$ban_summary = get_bans_summary($host);
	$db_global_ban2 = YotsubaDB::global();

	if( $ban_summary['total'] > 0 ) { // don't bother checking the active ban if there weren't ever any bans on this IP...
		if( !$banned = $db_global_ban2->query( "SELECT host, board, global, zonly, DATE_FORMAT(length, 'Until %W, %M %D, %Y.') AS buntil FROM {$db_global_ban2->qi(SQLLOGBAN)} WHERE host = ? AND active = 1", [$host] ) ) {
			echo S_SQLFAIL;
		}
		$bannedrows = $banned->rowCount();
		if( $bannedrows > 0 ) {
		  while ($ban_row = $banned->fetch(PDO::FETCH_BOTH)) {
  			$buntil      = $ban_row[ 'buntil' ];
  			$gban        = $ban_row[ 'global' ];
  			$bannedboard = $ban_row[ 'board' ];
  			$bannedzonly = $ban_row[ 'zonly' ];
  			if( $bannedboard == BOARD_DIR ) {
  				$bg = "f0d0d0";
  				if( $buntil == "" ) $buntil = "Indefinitely.";
  				$bantrue = 1;
  			}
  			if( $gban == 1 ) {
  				$bg = "f0a0a0";
  				if( $buntil == "" ) $buntil = "Indefinitely.";
  				$globally = " (Globally)";
  				$bantrue  = 1;
  				break;
  			}
  			else {
  				$globally = " (" . $board . ")";
  			}
			}
		}
		if( $bantrue ) {
			echo "<style>body { background: #$bg; }</style>";
		}
	}
  
  $note = array();
  
  if ($poster_is_op) {
    $note[] = 'This poster is the OP';
    
    if ($resto == 0) {
      $_count = admin_get_thread_history($host);
      
      if ($_count > 1) {
        $note[0] .= ' <sup data-tip="Other threads made in the past hour">' . ($_count - 1) . '</sup>';
      }
    }
  }
  
  if ($row['4pass_id'] != '') {
    $has_4chan_pass = $row['4pass_id'];
    
    $note[] = 'This user is using a 4chan Pass';
    
    $ban_summary_pass = get_bans_summary($has_4chan_pass, true);
  }
  else {
    $has_4chan_pass = false;
    $ban_summary_pass = null;
  }
  
  if (!preg_match('/Android|iPhone|iPad/', $_SERVER['HTTP_USER_AGENT'])) {
    $autofocus_html = ' autofocus="autofocus"';
  }
  else {
    $autofocus_html = '';
  }
  
  if ($host) {
    $geoinfo = GeoIP2::get_country($host);
    $asninfo = GeoIP2::get_asn($host);
  }
  else {
  	$geoinfo = $asninfo = false;
  }
  
  if ($asninfo && isset($asninfo['aso'])) {
    $aso_formatted = ' (' . htmlspecialchars($asninfo['aso'], ENT_QUOTES) . ')';
  }
  else {
    $aso_formatted = '';
  }
  
  echo '<form action="" method="post">';
  echo csrf_tag();
	echo "<input type=\"hidden\" name=\"mode\" value=\"admin\">\n";
	echo "<input type=\"hidden\" name=\"admin\" value=\"ban\">\n";
	echo "<input type=\"hidden\" name=\"user\" value=\"$user\">\n";
	echo "<input type=\"hidden\" name=\"pass\" value=\"$pass\">\n";
	echo "<input type=\"hidden\" name=\"id\" value=\"$postid\">\n";
	echo '<input type="hidden" name="templateno" value="-1">' . "\n";
	echo "<table border=\"0\" cellspacing=\"0\" cellpadding=\"0\" class=\"bantable\">\n";
	echo "<tr><td class=\"postblock\">Autocomplete</td><td><input type=\"text\" name=\"autocomplete\" placeholder=\"Start typing...\" id=\"autocomplete\" size=\"40\"$autofocus_html autocomplete=\"off\" style=\"width: 100%;\"></td></tr>" . "\n";
	echo "<tr name=\"template_row\" style=\"visibility: hidden;\"><td style=\"height: 20px;\" class=\"postblock\">Template</td><td><select name=\"template\" style=\"width: 100%;\" onchange=\"chooseTemplate();\"></select></td></tr>\n";
	echo "<tr><td class=\"postblock\">Name</td><td><input type=\"text\" name=\"name\" value=\"$name\" size=\"40\" style=\"width: 100%;\" readonly=\"readonly\"></td></tr>\n";
  echo "<tr><td class=\"postblock\">IP</td><td><input type=\"text\" name=\"ip\" value=\"$host$aso_formatted\" size=\"40\" style=\"width: 100%;\" readonly=\"readonly\"></td></tr>\n";
  echo "<tr><td class=\"postblock\">Host</td><td><input type=\"text\" id=\"js-ip-rev\" name=\"reverse\" value=\"...\" size=\"40\" style=\"width: 100%;\" readonly=\"readonly\"></td></tr>\n";
  
  if ($geoinfo && isset($geoinfo['country_code'])) {
    $geo_loc = array();
    
    if (isset($geoinfo['city_name'])) {
      $geo_loc[] = $geoinfo['city_name'];
    }
    
    if (isset($geoinfo['state_code'])) {
      $geo_loc[] = $geoinfo['state_code'];
    }
    
    $geo_loc[] = $geoinfo['country_name'];
    
    $loc = htmlspecialchars(implode(', ', $geo_loc), ENT_QUOTES);
    
    echo '
      <tr>
        <td class="postblock">Location</td>
        <td><input type="text" value="' . $loc . '" readonly="readonly" style="width: 100%;"></td>
      </tr>
      ';
  }
  
  $ban_history_row = array();
  
  if ($ban_summary['total'] > 0) {
    $ban_history_row[] = get_ban_history_html($ban_summary, $host);
    
  }
	
  if ($ban_summary_pass['total'] > 0) {
    $ban_history_row[] = get_ban_history_html($ban_summary_pass);
  }
  
  if (!empty($ban_history_row)) {
    echo "<tr><td class=\"postblock\" style=\"height: 20px;\">Ban History</td><td style=\"padding-top: 4px; padding-bottom: 4px;\">" .
      implode(' ', $ban_history_row) . "</td></tr>\n";
  }
  
  // Browser ID
  $_post_meta = decode_user_meta($row['email']);
  
	$result = $db_global_ban2->query("SELECT warn_req, {$db_global_ban2->qi('ban_templates')}.name FROM {$db_global_ban2->qi('ban_requests')} LEFT JOIN {$db_global_ban2->qi('ban_templates')} ON ban_template = {$db_global_ban2->qi('ban_templates')}.no WHERE host = ?", [$host]);
	$brpending = array();
	while ($row = $result->fetch(PDO::FETCH_ASSOC)) {
	  $brpending[] = $row['name'] . ($row['warn_req'] ? ' [Warn]' : '');
  }
  $brtooltip = join("\n", $brpending);
	$pending = '';
  $brcount = count($brpending);
	if ($brcount > 0) {
		$plural = ($brcount > 1) ? 's' : '';
		$pending = <<<HTML
<tr>
	<td style="height: 20px;" class="postblock">Ban Requests</td>
	<td style="cursor:help;" title="$brtooltip">
		[$brcount pending ban request$plural]
	</td>
</tr>
HTML;
	}
	echo $pending;
	
	echo "<tr><td class=\"postblock\">Public Ban Reason</td><td><textarea disabled=\"disabled\" name=\"pubreason\" value=\"\" cols=\"30\" rows=\"3\" title=\"The banned user will see this message.\" style=\"width: 100%; margin-bottom: 0px !important;\"></textarea></td></tr>\n";
	
	echo "<tr><td style=\"height: 20px;\" class=\"postblock\">Private Info</td><td><input disabled=\"disabled\" type=\"text\" style=\"width: 100%;\" name=\"pvtreason\" value=\"\" size=\"40\" title=\"Optional extra information for 4chan moderators. This will show up on the ban list.\"></td></tr>\n";
	
	echo "<tr><td class=\"postblock\">Unban In</td><td><input id=\"ban-days\" disabled=\"disabled\" name=\"days\" type=\"number\" size=\"4\" min=\"0\" maxlength=\"4\" class=\"inputcenter\" /> days [<input type=\"checkbox\" name=\"warn\" value=\"1\">Warn] [<input type=\"checkbox\" name=\"indefinite\" value=\"1\">Perma]</tr>\n";
	
	echo "<tr id=\"more_file\"><td style=\"height: 20px;\" class=\"postblock\">More Info</td><td style=\"padding-top: 4px; padding-bottom: 4px;\">[<a href='javascript:more(\"more_info\",\"more_info\")'>View Info</a>] [<a target=\"_blank\" data-tip=\"Search posts by IP\" href=\"https://team.4chan.org/search#{&quot;ip&quot;:&quot;$host&quot;}\">Search</a>]" . ($_post_meta['is_mobile'] ? ' <span data-tip="Posted from a mobile device" class="ico-phone">&phone;</span>' : '') . "</td></tr>";

	if (!empty($note)) {
		$note = implode('<br>', $note);
		
		echo "<tr><td style=\"height: 20px;\" class=\"postblock\">Note</td><td><strong>$note</strong></td></tr>";
	}

	if (has_level('manager')/* || has_flag('developer')*/) {
	  $toz = ' [<input type="checkbox" name="zonly" value="1">Unappealable]';
  }
  else {
    $toz = '';
  }
  
  if (has_level('manager') || has_flag('banmsg')) {
    $ban_msg_row = "<tr style=\"display:none\" id=\"pub-ban-msg\"><td style=\"height: 20px;\" class=\"postblock\">Message</td><td><input name=\"custombanmsg\" placeholder=\"USER WAS BANNED FOR THIS POST\" type=\"text\" style=\"width: 100%;\" title=\"Custom public ban message\">";
    
    $ban_msg_row .= <<<JS
<script type="text/javascript">
  function toggleBanMsg(cb) {
    var el = document.getElementById('pub-ban-msg');
    if (!el) { return; }
    if (cb.checked) {
      el.style.display = '';
    }
    else {
      el.style.display = 'none';
    }
  }
</script></td></tr>
JS;
    
    $pub_ban_evt = ' onchange="toggleBanMsg(this)"';
  }
  else {
    $ban_msg_row = $pub_ban_evt = '';
  }
	
  if ($resto == 0 && ENABLE_ARCHIVE) {
    $_opt_archive = '<option value="archive">Archive</option>';
  }
  else {
    $_opt_archive = '';
  }
  
  if (!$host) {
  	$btn_disabled = ' disabled';
  }
  else {
  	$btn_disabled = '';
  }
  
	echo "<tr><td style=\"height: 20px;\" class=\"postblock\">Ban Scope</td><td><input$btn_disabled id=\"submit-ban-btn\" type=\"submit\" name=\"submit\" value=\"Submit\"><select name=\"bantype\"><option value=\"local\">Ban from /$board/</option><option value=\"global\">Global ban</option></select><div>[<span title=\"Display (USER WAS BANNED FOR THIS POST) message.\"><input type=\"checkbox\"$pub_ban_evt name=\"banmsg\" value=\"1\">Public Ban</span>]$toz</div></td></tr>$ban_msg_row";
  
  echo "<tr><td style=\"height: 20px;\" class=\"postblock\">Post-Ban</td><td><select id=\"js-postban-sel\" name=\"postban\"><option value=\"\">Nothing</option><option value=\"delpost\">Delete post</option><option value=\"delfile\">Delete file only</option>$_opt_archive<option value=\"delallrep\" style=\"color:red\">Delete all replies by IP</option><option value=\"delall\" style=\"font-weight:bold;color:red\">Delete all posts by IP</option>";
  
  if ($resto == 0) {
    echo "<option value=\"close\">Close</option><option value=\"permasage\">Perma-sage</option>";
    
    $board_sel = get_board_options_html();
    echo "<option value=\"move\">Move</option>";
    echo "</select><select id=\"js-move-board-sel\" name=\"move-board\">$board_sel</select></td></tr>";
  }
  else {
    echo "</select></td></tr>";
  }
 	
 	$can_thread_ban = false;
 	
	if ($resto == 0 && (has_level('manager') || has_flag('threadban'))) {
		echo "<tr><td style=\"height: 20px;\" class=\"postblock\">Ban Thread</td><td><input$btn_disabled type=\"button\" value=\"Ban Entire Thread\" style=\"margin-left: 0px;\" id=\"js-tb-btn\"></td></tr>";
		$can_thread_ban = true;
	}
	
	echo "</table>\n";
	echo "</form>";
	
  // Async reverse IP request
  if ($host) {
    $_rev_long_ip = ip2long($host);
    $_rev_ts = $_SERVER['REQUEST_TIME'];
    $_rev_sig = admin_get_rev_ip_sig($_rev_long_ip, $_rev_ts);
  ?>
    <script type="text/javascript">
      async function admin_rev_ip() {
        let el = document.getElementById('js-ip-rev');
        if (!el) { return; }
        let ip = <?php echo $_rev_long_ip ?>;
        let t = <?php echo $_rev_ts ?>;
        let s = '<?php echo $_rev_sig ?>';
        const resp = await fetch(`?admin=rev&ip=${ip}&t=${t}&s=${s}`);
        if (resp.ok) {
          const json = await resp.json();
          el.value = json.rev;
        }
      }
      admin_rev_ip();
    </script>
  <?php }
  
	if ($can_thread_ban) { ?>
		<div id="thread-ban-layer" style="position: absolute; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.6); display: none;">
			<div style="position:absolute; left: 50%; top: 50%; padding: 6px; margin-left: -185px; margin-top: -52px;" class="post reply preview">
				<form action="" method="POST">
					<?php echo csrf_tag(); ?>
					<input type="hidden" name="mode" value="admin">
					<input type="hidden" name="admin" value="cpban">
					<input type="hidden" name="no" value="<?php echo $no ?>">
					<table class="bantable bantable-extra bantable-tb">
						<tr><td data-tip="Public reason for the OP" class="postblock">OP Reason</td><td><input type="text" name="op_reason" value="Posting off-topic threads."></td></tr>
						<tr><td data-tip="Ban length in days for the OP" class="postblock">OP Ban Length</td><td><input type="text" autocomplete="off" name="op_days" value="3"></td></tr>
						<tr><td data-tip="Public reason for replies" class="postblock">Rep. Reason</td><td><input type="text" name="rep_reason" value="Replying to off-topic threads."></td></tr>
						<tr><td data-tip="Ban length in days for replies" class="postblock">Rep. Ban Length</td><td><input type="text" autocomplete="off" name="rep_days" value="0"></td></tr>
						<tr><td></td><td style="text-align: right; padding-top: 8px"><button type="submit">Ban</button><button type="button" style="margin-left: 20px" id="js-tb-cancel">Cancel</button></td></tr>
					</table>
				</form>
			</div>
		</div>
		<script type="text/javascript">
			document.getElementById('js-tb-btn').addEventListener('click', toggleThreadBanPanel, false);
			document.getElementById('js-tb-cancel').addEventListener('click', toggleThreadBanPanel, false);
			
			function toggleThreadBanPanel(e) {
				let el = document.getElementById('thread-ban-layer');
				
				if (el.style.display === 'none') {
					el.style.display = 'block';
				}
				else {
					el.style.display = 'none';
				}
			}
		</script>
	<?php
	}
	
	$html = <<<HTML
<script type="text/javascript">
	var el;
	
	function submitRequest(e) {
		var select, index;
		
		select = document.forms[0].template;
		index = select.selectedIndex;
		
		if (index === 0) {
			e.preventDefault();
			e.stopPropagation();
			alert("You forgot to select a template.");
		}
		else {
			if (/ Child |\[Perm\]/.test(select.options[index].textContent)) {
				if (!checkSubmitConfirm(this)) {
					e.preventDefault();
					e.stopPropagation();
					return;
				}
			}
			postBack("start-ban-$board-$no");
		}
	}
	
	if (el = document.getElementById("submit-ban-btn")) {
		el.addEventListener("click", submitRequest, false);
	}
</script>
HTML;
	
	echo $html;
	
	$is_manager = has_level('manager') || has_flag('developer');

	echo ban_template_js($post_has_file, $resto == 0);

	echo "<div id=\"more_info\" style=\"position: absolute; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.6); display: none;\"><div style=\"position:absolute; left: 50%; top: 50%; padding: 6px; margin-left: -185px; margin-top: -52px;\" class=\"post reply preview\"><table class=\"bantable bantable-extra\">";

  if ($has_4chan_pass && has_level('mod')) {
    if ($is_manager) {
      echo "<tr class=\"more_pass\"><td class=\"postblock\">4chan Pass</td><td><input type=\"text\" value=\"$has_4chan_pass\" readonly=\"readonly\"></td></tr>";
    }
    else {
      $hashed_4chan_pass = admin_hash_4chan_pass($has_4chan_pass);
      echo "<tr class=\"more_pass\"><td class=\"postblock\"><span data-tip=\"Hashed 4chan Pass\">Hashed Pass</span></td><td><input type=\"text\" value=\"$hashed_4chan_pass\" readonly=\"readonly\"></td></tr>";
    }
  }

  if ($md5) {
    echo "<tr class=\"more_file\"><td class=\"postblock\">MD5</td><td><input type=\"text\" name=\"md5_disp\" value=\"$md5\" size=\"34\" readonly=\"readonly\"></td></tr>";
    echo "<tr class=\"more_file\"><td class=\"postblock\">Filename</td><td><input type=\"text\" name=\"md5_disp\" value=\"$filename\" size=\"34\" readonly=\"readonly\"></td></tr>";
    
    echo "<tr><td data-tip=\"Perceptual hash\" class=\"postblock\">PHash</td><td><input type=\"text\" value=\"{$tmd5}\" size=\"34\" readonly=\"readonly\"></td></tr>";
  }
  
	echo "<tr id=\"more_pwd\"><td class=\"postblock\">Password</td><td><input type=\"text\" name=\"pwd_disp\" value=\"$pwd\" size=\"34\" readonly=\"readonly\"></td></tr>";
	
  if ($host && admin_is_ip_rangebanned($host)) {
    echo "<tr><td class=\"postblock\">Rangeban</td><td><input type=\"text\" name=\"rangeban_info\" value=\"Yes\" size=\"34\" readonly=\"readonly\"></td></tr>";
  }
  
  if ($_post_meta['req_sig']) {
    echo "<tr><td data-tip=\"Signature of the HTTP request\" class=\"postblock\">Req. Sig.</td><td><input type=\"text\" value=\"{$_post_meta['req_sig']}\" size=\"34\" readonly=\"readonly\"></td></tr>";
  }
  
  if ($_post_meta['browser_id']) {
    echo "<tr><td class=\"postblock\">Browser ID</td><td><input type=\"text\" value=\"{$_post_meta['browser_id']}\" size=\"34\" readonly=\"readonly\"></td></tr>";
  }
  
  if ($_post_meta['is_new']) {
    $_user_status = 'New';
  }
  else if ($_post_meta['is_known']) {
    $_user_status = 'Trusted';
  }
  else {
    $_user_status = 'Untrusted';
  }
  
  if ($_post_meta['verified_level']) {
    $_user_status .= ', Verified';
  }
  
  if ($_user_status) {
    echo "<tr><td class=\"postblock\">User Status</td><td><input type=\"text\" value=\"$_user_status\" size=\"34\" readonly=\"readonly\"></td></tr>";
  }
  
	echo "<tr><td></td><td>[<a href='javascript:more(\"more_info\",\"more_info\")'>Close</a>]</td></tr>";
	echo "</table></div></div>";

	die( "</body></html>" );
}
}

function adminToggleSpoiler($post, $new_spoiler) {
  if (strpos($post['sub'], 'SPOILER<>') === 0) {
    $old_subject = substr($post['sub'], 9);
    $old_spoiler = true;
  }
  else {
    $old_subject = $post['sub'];
    $old_spoiler = false;
  }
  
  if ($old_spoiler == $new_spoiler) {
    return false;
  }
  
  if ($new_spoiler) {
    $subject = 'SPOILER<>' . $old_subject;
    $actionType = 1;
  }
  else {
    $subject = $old_subject;
    $actionType = 2;
  }
  
  $db_board = YotsubaDB::board();
  $res = $db_board->query("UPDATE {$db_board->qi(BOARD_DIR)} SET sub = ? WHERE no = ? LIMIT 1", [$subject, $post['no']]);

  if (!$res) {
    die('Database error (ats).');
  }

  $maskShift = 128;
  $actionId = $maskShift + $actionType;

  $db_global = YotsubaDB::global();
  $db_global->query(
    "INSERT INTO {$db_global->qi('actions_log')} (oldmask, newmask, postno, board, name, sub, com, filename, admin) VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?)",
    [$actionId, $post['no'], BOARD_DIR, $post['name'], $post['sub'], $post['com'], $post['filename'] . $post['ext'], $_COOKIE['4chan_auser']]
  );
  
  return true;
}

function adminopt()
{
	global $id, $user, $pass;
	$submit         = $_POST[ 'submit' ];
	$post_sticky    = intval( $_POST[ 'sticky' ] );
	$post_sticknum  = intval( $_POST[ 'sticknum' ] );
	$post_permaage  = intval( $_POST[ 'permaage' ] );
	$post_undead    = intval( $_POST[ 'undead' ] );
	$post_permasage = intval( $_POST[ 'permasage' ] );
	$post_closed    = intval( $_POST[ 'closed' ] );
	$post_id        = (int)$id;

	$adminuser = $_COOKIE[ '4chan_auser' ];

	$db_board = YotsubaDB::board();
	$is_managerplus = has_level( 'manager' ) || has_flag('developer');

	if( !$result = $db_board->query( "SELECT * FROM {$db_board->qi(SQLLOG)} WHERE archived = 0 AND no = ?", [intval( $id )] ) ) {
		echo S_SQLFAIL;
	}

	if (!$result->rowCount()) {
	  die("Thread not found.");
	}

	$row = $result->fetch(PDO::FETCH_ASSOC);
	
	if (!$row) {
	  die('Datbase error.');
	}
	
	extract( $row, EXTR_OVERWRITE );

	if( !$is_managerplus ) $post_permaage = $permaage; // force setting to old value to stop forgery
	//if( !$is_managerplus ) $post_undead = $undead; // force setting to old value to stop forgery

	if( $resto != 0 ) die();

	if( $submit != "" ) {		
		if( $post_sticky == 1 && ( $post_sticknum < 0 || $post_sticknum > 60 ) ) {
			echo "Sticky number must be between 0 and 59. Higher numbers appear above lower numbers.<br>";
			die( "[<a href=\"javascript:void(0)\" onclick=\"history.back()\">Back</a>]</body></html>" );
		}
		else {
			if( strlen( $post_sticknum ) == 1 ) $post_sticknum = "0" . $post_sticknum;
			$post_sticknum = "202701010000" . $post_sticknum;
		}
		
		echo "<script language=\"JavaScript\">setTimeout(\"self.close()\", 3000); postBack('done-threadopt');</script>";
		$vars = "";
		echo "Thread flag status:<ul>";
		if( $post_sticky == 1 ) {
			echo "<li>Sticky &check;</li>";
			$vars .= "sticky=1,root=" . $post_sticknum . ",";
		}
		else {
			if( $sticky == 1 ) {
				$sticktime = "now()";
			}
			else {
				$sticktime = "root";
			}
			
			echo '<li>Sticky &cross;</li>';
			$vars .= "sticky=0,root=" . $sticktime . ",";
		}
		if( $post_permasage == 1 ) {
			echo "<li>Perma-sage &check;</li>";
			$vars .= "permasage=1,";
		}
		else {
			echo '<li>Perma-sage &cross;</li>';
			$vars .= "permasage=0,";
		}
		if( $post_closed == 1 ) {
			echo "<li>Closed &check;</li>";
			$vars .= "closed=1,";
		}
		else {
			echo '<li>Closed &cross;</li>';
			$vars .= "closed=0,";
		}
		if( $post_permaage ) {
			if( $is_managerplus ) {
			  echo '<li>Perma-age &check;</li>';
			  $vars .= "permaage=1,";
		  }
		}
		else {
			if( $is_managerplus ) {
			  echo '<li>Perma-age &cross;</li>';
			  $vars .= "permaage=0,";
		  }
		}
		if( $post_undead ) {
			//if( $is_managerplus ) {
			  echo '<li>Undead &check;</li>';
			  $vars .= "undead=1,";
		  //}
		}
		else {
			//if( $is_managerplus ) {
			  echo '<li>Undead &cross;</li>';
			  $vars .= "undead=0,";
		  //}
		}
		
		// Clear the undead flag when a moderator modifies the sticky flag
		// so the thread doesn't turn into a rolling sticky or get stuck as undead
    /*
		if ($undead && !$is_managerplus && $post_sticky != $sticky) {
		  echo '<li>Undead &cross;</li>';
		  $vars .= "undead=0,";
		}
		*/
		$vars .= "last_modified=".$_SERVER['REQUEST_TIME']; // FIXME consider checking if we only change hidden vars and don't update this
		
		echo '</ul><script language="JavaScript">setTimeout("self.close()", 3000); postBack("done-threadopt");</script>';
		
		if( !$result = $db_board->query( "UPDATE {$db_board->qi(SQLLOG)} SET $vars WHERE no = ?", [$post_id] ) ) {
			echo S_SQLFAIL;
		}
		
    log_thread_opts_action($row, $post_sticky, $post_permasage, $post_closed, $post_permaage, $post_undead);
		
		if( $post_sticky != $sticky || $post_closed != $closed) rebuild_thread( $post_id );
	}
	else {
	  echo '<form action="" method="post">';
    echo csrf_tag();
		echo "<input type=\"hidden\" name=\"mode\" value=\"admin\"><input type=\"hidden\" name=\"admin\" value=\"opt\"><input type=\"hidden\" name=\"user\" value=\"$user\"><input type=\"hidden\" name=\"pass\" value=\"$pass\"><input type=\"hidden\" name=\"id\" value=\"$post_id\">\n";
		echo "<table class=\"goawayborder\" style=\"width: 100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\">\n";

		if( BOARD_DIR != 'b' || $GLOBALS[ 'b_sticky' ] ) {
			echo "<tr><td class=\"postblock\" style=\"height: 20px; width: 80px;\"><u>S</u>ticky</td><td><input type=checkbox name=\"sticky\" id=\"js-sticky-cb\" value=\"1\"";
			if( $sticky == 1 ) {
				echo ' checked data-cur="1"';
				$sticknum = substr( $root, -2 );
				if( $sticknum[0] == "0" ) $sticknum = substr( $sticknum, -1 );
			}
			else {
				echo ' data-cur="0"';
				$sticknum = "0";
			}
			echo ">&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"text\" name=\"sticknum\" value=\"$sticknum\" size=\"2\" maxlength=\"2\" class=\"inputcenter\" style=\"height: 20px; width: 40px;\"> (Order: 0-59)</td></tr>\n";
		}
		echo "<tr><td class=\"postblock\" style=\"height: 20px; width: 80px;\"><u>P</u>erma-sage</td><td><input type=\"checkbox\" name=\"permasage\" value=\"1\"";
		if( $permasage == 1 ) echo " CHECKED";
		echo "></td></tr>\n";
		echo "<tr><td class=\"postblock\" style=\"height: 20px; width: 80px;\"><u>C</u>losed</td><td><input type=\"checkbox\" name=\"closed\" value=\"1\"";
		if( $closed == 1 ) echo " CHECKED";
		echo "></td></tr>\n";

    if ($is_managerplus) {
  		echo "<tr><td class=\"postblock\" style=\"height: 20px; width: 80px;\">P<u>e</u>rma-age</td><td><input type=\"checkbox\" name=\"permaage\" value=\"1\"";
  		if( $permaage == 1 ) echo 'checked="checked"';
  		echo "></td></tr>\n";
		}
    
    //if ($is_managerplus) {
  		echo "<tr><td class=\"postblock\" style=\"height: 20px; width: 80px;\"><u>U</u>ndead</td><td><input type=\"checkbox\" name=\"undead\" id=\"js-undead-cb\" value=\"1\"";
  		if( $undead == 1 ) echo 'checked="checked"';
  		echo "></td></tr>\n";
    //}
    
  	echo "<tr><td></td><td><input style=\"width:100px;margin-top: -25px;position: absolute;right: 5px;\" id=\"js-set-btn\" type=\"submit\" name=\"submit\" value=\"Set Options\"></td></tr>\n";
    
		echo "</table>\n";
		echo "</form>";
		
		
		/**
		 * Thread moving form
		 */
		if (BOARD_DIR !== 'b' && !UPLOAD_BOARD && !JANITOR_BOARD) {
		  echo move_thread_form($post_id);
		}
		
		die( "</body></html>" );
	}
}

function log_thread_opts_action($post_data, $sticky, $permasage, $closed, $permaage, $undead) {
  if (!isset($post_data['no']) || !$post_data['no']) {
    die('Internal Server Error (ltoa)');
  }
  
  $new_mask = 0 + (($sticky) ? 1 : 0)
                + (($permasage) ? 2 : 0)
                + (($closed) ? 4 : 0)
                + (($permaage) ? 8 : 0)
                + ($undead ? 16 : 0);
  
  $old_mask = 0 + (($post_data['sticky']) ? 1 : 0)
                + (($post_data['permasage']) ? 2 : 0)
                + (($post_data['closed']) ? 4 : 0)
                + (($post_data['permaage']) ? 8 : 0)
                + ($post_data['undead'] ? 16 : 0);

  if ($new_mask == $old_mask) {
    return false;
  }
  
  $db = YotsubaDB::global();
  $res = $db->query(
    "INSERT INTO {$db->qi('actions_log')} (oldmask, newmask, postno, board, name, sub, com, filename, admin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    [$old_mask, $new_mask, $post_data['no'], BOARD_DIR, $post_data['name'], $post_data['sub'], $post_data['com'], $post_data['filename'] . $post_data['ext'], $_COOKIE['4chan_auser']]
  );

  return !!$res;
}

function get_board_options_html() {
  $boardlist = get_board_list();
  
  $board_sel = array('<option value=""> Board</option>');
  
  foreach ($boardlist as $b_dir => $b_title) {
    if ($b_dir === BOARD_DIR || $b_dir === 'f') {
      continue;
    }
    $board_sel[] = '<option value="' . $b_dir . '">' . $b_dir . ' - '
      . $b_title . '</option>';
  }
  
  return implode("\n", $board_sel);
}

function move_thread_form($post_id) {
    $csrf_tag = csrf_tag();
    
    $board_sel = get_board_options_html();
    
    if (!ENABLE_ARCHIVE) {
      $del_attrs = ' checked';
    }
    else {
      $del_attrs = '';
    }
    
    return <<<HTML
<hr>
<form id="move-form" action="post" method="POST">
$csrf_tag
<input type="hidden" name="id" value="$post_id">
<table class="goawayborder" style="width: 100%" border="0" cellspacing="0" cellpadding="0">
<tr>
  <td class="postblock" style="height: 20px; width: 80px;">Move to</td>
  <td><select name="board" required>$board_sel</select></td>
</tr>
<tr>
  <td class="postblock" style="height: 20px; width: 80px;"><label for="move_del">and delete</label></td>
  <td><input$del_attrs id="move_del" name="move_del" type="checkbox"></td>
</tr>
<tr>
  <td></td>
  <td>
    <button id="js-move-btn" style="margin-top: -25px;position: absolute;right: 5px;" type="submit" name="mode" value="movethread">Move</button>
  </td>
</tr>
</table>
</form>
HTML;
}

function adminExt()
{
	global $thread;
	$where = '';

	if( isset( $_GET[ 'from' ] ) && ctype_digit( $_GET[ 'from' ] ) ) {
		$from  = intval( $_GET[ 'from' ] );
		$where = " AND no >= $from";
	}

	if( !$thread ) return false;

	$thread = (int)$thread;
	$db_board = YotsubaDB::board();
	if( !$result = $db_board->query( "SELECT {$db_board->qi('host')}, {$db_board->qi('no')} FROM {$db_board->qi(SQLLOG)} WHERE (no = ? OR resto = ?)$where", [$thread, $thread] ) ) {
		echo S_SQLFAIL;

		return false;
	}
	$json = array();

	$salt = file_get_contents('/www/keys/2014_admin.salt');

	if (!$salt) {
	  die('Internal Server Error');
	}

	while ($row = $result->fetch(PDO::FETCH_ASSOC)) {
    $hash = substr(base64_encode(pack( "H*", sha1($row['host'] . $salt))), 0, 8);
    
		$json[$row['no']] = $hash;
	}

	echo json_encode( $json, JSON_NUMERIC_CHECK );

	die();
}

function adminBanReq()
{
	$no      = (int)$_GET['id'];
	$board   = BOARD_DIR;
	$janitor = $_COOKIE['4chan_auser'];
	
	if ($board === 'j') {
	  die();
	}

	$db_board = YotsubaDB::board();
	$result = $db_board->query( "SELECT * FROM {$db_board->qi($board)} WHERE no = ?", [$no] );

	if (!$result->rowCount()) {
		echo '<script language="JavaScript">postBack("error-ban-' . $board . '-' . $no . '");</script>';
		error("This post doesn't exist anymore");
	}

	$post = $result->fetch(PDO::FETCH_ASSOC);
	
	if ($post['archived']) {
		echo '<script language="JavaScript">postBack("error-ban-' . $board . '-' . $no . '");</script>';
		error("This post is archived");
	}
	
  if ($post['host'] === '') {
    error('You cannot request a ban for this post.');
  }
	
	$post_has_file = $post['ext'] && !$post['file_deleted'];
	
  if (!access_board(BOARD_DIR)) {
    // Check if the report is unlocked, weight threshold is 1500
    $db_global_br = YotsubaDB::global();
    $result = $db_global_br->query(
      "SELECT CEIL(SUM(" . $db_global_br->ifExpr('resto > 0', 'weight', 'weight * 1.25') . ")) as total_weight "
      . "FROM {$db_global_br->qi('reports')} WHERE board = ? AND no = ?",
      [$board, $no]
    );

    if (!$result) {
      error('Database Error (abru1');
    }

    $total_weight = (int)$result->fetch(PDO::FETCH_NUM)[0];
    
    if (!$total_weight || $total_weight < 1500) {
      error('You do not have permission to access this board.');
    }
  }
	
  // for async calls from reports.4chan.org
  if (isset($_POST['by_tpl']) && $_POST['by_tpl']) {
    $_POST['template'] = $_POST['by_tpl'];
    unset($_POST['warn_req']);
  }
  
	if( $_POST[ 'template' ] ) {
		$template = (int)$_POST['template'];
		
		if ($template < 1) {
			error('You forgot to select a template.');
		}
		
		$db_global_br2 = YotsubaDB::global();
		$bquery = $db_global_br2->query( "SELECT * FROM {$db_global_br2->qi('ban_templates')} WHERE no = ?", [$template] );
		$bres   = $bquery->fetch(PDO::FETCH_ASSOC);
		
    if (!has_level($bres['level'])) {
      error('You cannot use this template');
    }
		
    if (($bres['no'] == 1 || $bres['no'] == 123 || $bres['no'] == 213) && !$post_has_file) {
      error('This template requires a post with a file');
    }
    
		$reason = $bres['publicreason'];
		
		$xffquery = $db_global_br2->query( "SELECT xff FROM {$db_global_br2->qi('xff')} WHERE board = ? AND postno = ?", [$board, $no] );
		$reverse  = gethostbyaddr( $post['host'] );

		if( $xffresult = $xffquery->fetch(PDO::FETCH_NUM) ) {
			if( !( $xff = gethostbyaddr( $xffresult[0] ) ) ) $xff = $xffresult[0];
		}
		
		if (isset($_POST['warn_req']) && $_POST['warn_req']) {
		  if (!$bres['can_warn']) {
		    error('You cannot issue warn requests using this template.');
		  }
		  $warn_req = 1;
		}
		else if ($bres['days'] === '0') {
		  $warn_req = 1;
	  }
		else {
		  $warn_req = 0;
		}
		
    // Fixme: for the cache purger below
    if ($post['ext'] != '') {
      $post_filename = "{$post['tim']}{$post['ext']}";
    }
    else {
      $post_filename = null;
    }
    
		// Make sure we don't have any illegal reports (stop illegal images being stored)
		$illegal = $db_global_br2->query( "SELECT COUNT(*) FROM {$db_global_br2->qi('reports')} WHERE board = ? AND no = ? AND cat = 2", [$board, $_POST['no']] );
		if (((int)$illegal->fetch(PDO::FETCH_NUM)[0] == 0) && $bres['save_post'] === 'everything') {
			$salt = file_get_contents( SALTFILE );
			$hash = sha1($board . $post['no'] . $salt);
			
			@copy(
				IMG_DIR . "{$post['tim']}{$post['ext']}",
				BANIMG_ROOT . "$board/$hash{$post['ext']}"
			);
			
			@copy(
				THUMB_DIR . "{$post['tim']}s.jpg",
				BANTHUMB_DIR . "{$hash}s.jpg"
			);
		}
		else {
			//unset($post['ext']);
			$post['raw_md5'] = $post['md5'];
		}
		
		if ($post['resto']) {
		  $sub_query = $db_board->query("SELECT sub FROM {$db_board->qi($board)} WHERE no = ?", [$post['resto']]);
		  $sub_res = $sub_query->fetch(PDO::FETCH_ASSOC);
		  if ($sub_res) {
		    $rel_sub = $sub_res['sub'];
		    
        if (strpos($rel_sub, 'SPOILER<>') === 0) {
          $rel_sub = substr($rel_sub, 9);
        }
        
        if ($rel_sub !== '') {
          $post['rel_sub'] = $rel_sub;
        }
		  }
		}
		
    $tpl_name = $bres['name'];
    $tpl_global = $bres['bantype'] !== 'local' ? 1 : 0;
    
		delete_post($no, false, $template, 'ban-req');
		
		$res = $db_global_br2->query("INSERT INTO {$db_global_br2->qi('ban_requests')} (host, reverse, pwd, xff, reason, global, tpl_name, ban_template, board, janitor, spost, post_json, warn_req) VALUES (?, ?, ?, ?, '', ?, ?, ?, ?, ?, ?, ?, ?)", [$post['host'], $reverse, $post['pwd'], $xff, $tpl_global, $tpl_name, $template, $board, $janitor, serialize( $post ), json_for_post($board, $post), $warn_req]);
		
		if (!$res) {
			error('Database error.');
		}
    
    // Auto-rangebans processing (ban requests)
    // FIXME: email field
    $_post_meta = decode_user_meta($row['email']);
    
    if (!$warn_req && $_post_meta && $_post_meta['is_mobile']) { // mobile devices only
      // global rules only
      if ($bres && strpos($bres['rule'], 'global') !== false) {
        process_auto_rangeban($post['host'], $_post_meta['browser_id'], $post['resto'], $post['no'], $bres['no'], 0);
      }
    }
    
    // Fixme, this is for the temporary is2/is3 cache purging api
    if ($post_filename && $bres && $bres['rule'] == 'global1') {
      //purge_cache_internal_temp(BOARD_DIR, $post_filename);
    }
		echo '<script language="JavaScript">setTimeout("self.close()", 3000); postBack("done-ban-' . $board . '-' . $no . '");</script>';
		die( ($warn_req ? 'Warn' : 'Ban') . ' request submitted! Window will now close...' );
	}
  
	$name = str_replace( '</span> <span class="postertrip">!', ' !', $post[ 'name' ] );

	$db_global_br3 = YotsubaDB::global();
	$result = $db_global_br3->query("SELECT warn_req, {$db_global_br3->qi('ban_templates')}.name FROM {$db_global_br3->qi('ban_requests')} LEFT JOIN {$db_global_br3->qi('ban_templates')} ON ban_template = {$db_global_br3->qi('ban_templates')}.no WHERE host = ?", [$post['host']]);
	$brpending = array();
	while ($row = $result->fetch(PDO::FETCH_ASSOC)) {
	  $brpending[] = $row['name'] . ($row['warn_req'] ? ' [Warn]' : '');
  }
  $brtooltip = join("\n", $brpending);
	$pending = '';
  $brcount = count($brpending);
	if ($brcount > 0) {
		$plural = ($brcount > 1) ? 's' : '';
		$pending = <<<HTML
<tr>
	<td style="height: 20px;" class="postblock">Note</td>
	<td colspan="2" style="cursor:help;" title="$brtooltip">
		[$brcount pending ban request$plural]
	</td>
</tr>
HTML;
	}
  
	$csrf_tag = csrf_tag();
	
  if (!preg_match('/Android|iPhone|iPad/', $_SERVER['HTTP_USER_AGENT'])) {
    $autofocus_html = ' autofocus="autofocus"';
  }
  else {
    $autofocus_html = '';
  }
  
	$html = <<<HTML
<form action="" method="post">$csrf_tag
<table border="0" cellspacing="0" cellpadding="0" class="bantable">
<tr>
	<td class="postblock">Autocomplete</td>
	<td colspan="2">
		<input type="text" name="autocomplete" placeholder="Start typing..." id="autocomplete" size="40"$autofocus_html autocomplete="off" style="width: 100%;">
	</td>
</tr>

<tr name="template_row" style="visibility: hidden;">
	<td style="height: 20px;" class="postblock">Template</td>
	<td colspan="2">
		<select name="template" style="width: 100%;" onchange="chooseTemplate();"></select>
	</td>
</tr>

$pending

<tr>
	<td class="postblock">Name</td>
	<td colspan="2">
		<input type="text" name="name" value="$name" size="40" style="width: 100%;" readonly="readonly">
	</td>
</tr>

<tr>
	<td class="postblock">Reason</td>
	<td colspan="2">
		<textarea id="reason" name="reason" value="" cols="30" rows="4" title="The banned user will see this message." style="width: 100%; margin-bottom: 0px !important;" readonly="readonly"></textarea>
	</td>
</tr>

<tr>
	<td class="postblock">Warn?</td>
	<td colspan="2">
		<input id="warn-req" type="checkbox" name="warn_req" value="1" title="Request the user be warned instead of banned.">
	</td>
</tr>

<tr>
	<td  class="postblock">Requested By</td>
	<td>
		<input style=" width: 100%;" type="text" name="bannedby" value="$janitor" readonly="readonly">
	</td>
	<td align="right">
		<input id="submit-br-btn" type="submit" value="Submit Request" style="margin: -1px">
		<script type="text/javascript">
			var el;
			
			function submitRequest(e) {
				var select, index;
				
				select = document.forms[0].template;
				index = select.selectedIndex;
				
				if (index === 0) {
					e.preventDefault();
					e.stopPropagation();
					alert("You forgot to select a template.");
				}
				else {
					if (/ Child |\[Perm\]/.test(select.options[index].textContent)) {
						if (!checkSubmitConfirm(this)) {
							e.preventDefault();
							e.stopPropagation();
							return;
						}
					}
					postBack("start-ban-$board-$no");
				}
			}
			
			if (el = document.getElementById("submit-br-btn")) {
				el.addEventListener("click", submitRequest, false);
			}
		</script>
	</td>
</tr>
</table>
</form>
HTML;

	echo $html;
	
  $templates = array();
  $level_map = get_level_map();
  
	$q = $db_global_br3->query("SELECT * FROM {$db_global_br3->qi('ban_templates')} ORDER BY LENGTH(rule), rule ASC");

	while( $r = $q->fetch(PDO::FETCH_ASSOC) ) {
    if (!preg_match('#^(global|' . BOARD_DIR . ')[0-9]+$#', $r['rule'])) {
      continue;
    }
    
    if (($r['no'] == 1 || $r['no'] == 123 || $r['no'] == 213) && !$post_has_file) {
      continue;
    }
    
    if ($r['no'] == 6 && !DEFAULT_BURICHAN) { // NWS on Worksafe Board
      continue;
    }
    
    if ($r['no'] == 17 && (BOARD_DIR === 'mlp' || BOARD_DIR === 'trash')) { // Pony/Ponies Outside of /mlp/
      continue;
    }
    
    if ($r['no'] == 222 && (BOARD_DIR === 's4s' || BOARD_DIR === 'bant')) { // Global 3 - Troll posts
      continue;
    }
    
    if ($r['no'] == 59 && BOARD_DIR === 'po') { // Global 16 - Request Thread Outside of /r/
      continue;
    }
    
    if ($r['no'] == 223 && BOARD_DIR === 'pol') { // Global 3 - Racism
      continue;
    }
    
    // Global 3
    if ((BOARD_DIR === 'b' || BOARD_DIR === 'bant') && strpos($r['rule'], 'global3') !== false) {
      continue;
    }
    
    if ($r['no'] == 59 && $post['resto']) { // Request Thread Outside of /r/
      continue;
    }
    
	  if ($level_map[$r['level']] !== true) {
	    continue;
	  }
	  
		unset($r[ 'special_action' ], $r[ 'blacklist' ], $r[ 'bantype' ], $r[ 'postban' ], $r[ 'privatereason' ]);
		
		$templates[] = $r;
	}
	
	$encTemp = json_encode( $templates );

	$v = <<<HTML
<script type="text/javascript" src="//s.4cdn.org/js/admin_autocomplete.9.js"></script>
<script type="text/javascript">
var e_template = document.getElementsByName("template")[0];
	var globalTemplates = $encTemp;
	var templates = {};
	var localTemplates = {};

	function $(e) {return document.getElementsByName(e)[0];}
	function unhide(e) {
		$(e).style.visibility="visible";
	};

	function chooseTemplate() {
		var i = e_template.selectedIndex - 1;
    
    Feedback.checkTemplate(i);
    
		if (i < 0) {
			return;
		}

		var t = templates[i];
		document.getElementById('reason').innerHTML = t.publicreason;
		
		document.getElementById('warn-req').disabled = t.can_warn == '0';
		document.getElementById('warn-req').checked = (t.banlen == '' && t.days == 0);
		
		//undisableForm(t);
	}

	function undisableForm(t) {
		if( t.name != 'Other...' ) return;
		document.getElementById('reason').removeAttribute('disabled');
	}

	function initTemplate() {
		templates = globalTemplates;

		if (localStorage) {
			var lt = JSON.parse(localStorage.getItem("ban_templates"));
			if (lt) {
				localTemplates = lt;
				for (var t in localTemplates)
					templates = templates.concat(localTemplates[t]);
			}
		}

		e_template.innerHTML = '<option value="-1">None Selected (Required)</option>';

		for (var i=0;i<templates.length;i++) {
			var t = templates[i];
			//if( !t.name.match(/Global/) && !t.name.match(/\/' . BOARD_DIR . '\//) && i < globalTemplates.length ) continue;

			var o = document.createElement("option");
			o.value = t.no;
			o.innerHTML = t.name + ((i < globalTemplates.length) ? "" : " [Local]");
			e_template.appendChild(o);
		}
		unhide("template_row");
		if (localStorage) {
		//	unhide("local_template_row");
		//	unhide("deltemplate");
		}
	}

	initTemplate();
</script>
HTML;

	echo $v;
}

/* FIXME: this is for the temporary is2/is3 cache purge api */
function purge_cache_internal_temp($board, $file) {
  $url = "http://g0ch4.brazil.jp:24502";
  
  $post = array();
  $post['rmpath'] = "/$board/$file";
  $post['key'] = '6a310437e13935b64beefcf10da8dba3';
  $post = http_build_query($post);
  
  rpc_start_request($url, $post, null, false);
}

/**
 * Sets or usnets the spoiler flag for images
 * Does its own access validation.
 * Accessible to janitors
 */
function admin_toggle_spoiler() {
  header('Content-Type: text/plain');
  
  if (!SPOILERS) {
    echo '0'; die();
  }
  
  auth_user();
  
  if (!has_level() && (!has_level('janitor') || !access_board(BOARD_DIR))) {
    echo '-1'; die();
  }
  
  if (!isset($_GET['pid']) || !isset($_GET['flag'])) {
    echo '0'; die();
  }
  
  $db_board = YotsubaDB::board();
  $res = $db_board->query("SELECT * FROM {$db_board->qi(SQLLOG)} WHERE no = ?", [$_GET['pid']]);

  if (!$res) {
    echo '0'; die();
  }

  $post = $res->fetch(PDO::FETCH_ASSOC);
  
  if (!$post) {
    echo '0'; die();
  }
  
  $spoiler_updated = adminToggleSpoiler($post, (bool)$_GET['flag']);
  
  if ($spoiler_updated) {
    if ($post['resto']) {
      $thread_id = (int)$post['resto'];
    }
    else {
      $thread_id = (int)$post['no'];
    }
    
    rebuild_thread($thread_id, $error, (bool)$post['archived']);
  }
  
  echo '1'; die();
}

function validate_csrf($ref_only = false) {
  if (is_local()) return;
  if ($_SERVER['REQUEST_METHOD'] == 'POST' && !$ref_only) {
    if (!isset($_COOKIE['_tkn']) || !isset($_POST['_tkn'])
      || $_COOKIE['_tkn'] == '' || $_POST['_tkn'] == ''
      || $_COOKIE['_tkn'] !== $_POST['_tkn']) {

      if (!is_local()) {
        error('Bad Request.');
      }
    }
  }
  else {
    if (isset($_SERVER['HTTP_REFERER']) && $_SERVER['HTTP_REFERER'] != ''
      && !preg_match('/^https?:\/\/([_a-z0-9]+)\.(4chan|4channel)\.org(\/|$)/', $_SERVER['HTTP_REFERER'])
      && !preg_match('/^https?:\/\/localhost(:[0-9]+)?(\/|$)/', $_SERVER['HTTP_REFERER'])) {
      error('Bad Request.');
    }
  }
}

// ============================================================
// Admin panel features (reproduced from KusabaX reference)
// ============================================================

function admin_banlist() {
  if (!has_level('mod')) die('Access denied');

  $page = max(1, (int)$_GET['page']);
  $per_page = 50;
  $offset = ($page - 1) * $per_page;

  $db = YotsubaDB::global();
  $search = '';
  $where = '';
  $params = [];
  if (isset($_GET['q']) && $_GET['q'] !== '') {
    $search_term = '%' . $_GET['q'] . '%';
    $where = " WHERE host LIKE ? OR reason LIKE ? OR admin LIKE ? OR name LIKE ?";
    $params = [$search_term, $search_term, $search_term, $search_term];
    $search = htmlspecialchars($_GET['q'], ENT_QUOTES);
  }

  $total_res = $db->query("SELECT COUNT(*) FROM {$db->qi(SQLLOGBAN)}" . $where, $params);
  $total = (int)$total_res->fetch(PDO::FETCH_NUM)[0];

  $res = $db->query("SELECT * FROM {$db->qi(SQLLOGBAN)}" . $where . " ORDER BY no DESC LIMIT " . (int)$per_page . " OFFSET " . (int)$offset, $params);

  echo '<h3>Ban List</h3>';
  echo '<form method="get" style="margin-bottom:10px"><input type="hidden" name="admin" value="banlist">';
  echo '<input type="text" name="q" value="' . $search . '" placeholder="Search IP, reason, admin..." size="30"> ';
  echo '<input type="submit" value="Search"></form>';
  echo '<p>' . $total . ' total bans</p>';
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>ID</th><th>Board</th><th>IP</th><th>Reason (public)</th><th>Length</th><th>By</th><th>Active</th><th>Date</th><th>Actions</th></tr>';

  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    $reasons = explode('<>', $row['reason']);
    $pub = $reasons[0] ?: '(none)';
    $active_class = $row['active'] ? 'color:green' : 'color:#999';
    $active_text = $row['active'] ? 'Yes' : 'No';
    $scope = $row['global'] ? '<b>Global</b>' : '/' . htmlspecialchars($row['board']) . '/';
    $length = $row['length'] === '00000000000000' ? 'Permanent' : htmlspecialchars($row['length']);

    echo '<tr>';
    echo '<td>' . $row['no'] . '</td>';
    echo '<td>' . $scope . '</td>';
    echo '<td>' . htmlspecialchars($row['host']) . '</td>';
    echo '<td>' . $pub . '</td>';
    echo '<td style="font-size:11px">' . $length . '</td>';
    echo '<td>' . htmlspecialchars($row['admin']) . '</td>';
    echo '<td style="' . $active_class . '">' . $active_text . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($row['now']) . '</td>';
    echo '<td>';
    if ($row['active']) {
      echo '<a href="?admin=unban&id=' . $row['no'] . '" style="color:red">[Unban]</a>';
    }
    echo '</td>';
    echo '</tr>';
  }
  echo '</table>';

  $pages = ceil($total / $per_page);
  if ($pages > 1) {
    echo '<p>Page: ';
    for ($i = 1; $i <= $pages && $i <= 20; $i++) {
      $bold = ($i == $page) ? 'font-weight:bold' : '';
      $qs = 'admin=banlist&page=' . $i;
      if ($search) $qs .= '&q=' . urlencode($search);
      echo '<a href="?' . $qs . '" style="margin:0 3px;' . $bold . '">' . $i . '</a>';
    }
    echo '</p>';
  }
}

function admin_unban() {
  if (!has_level('mod')) die('Access denied');
  $id = (int)$_GET['id'];
  if (!$id) die('No ban ID');
  $db = YotsubaDB::global();
  $db->query("UPDATE {$db->qi(SQLLOGBAN)} SET active = 0, unbannedon = NOW(), unbannedby = ? WHERE no = ?", [$_COOKIE['4chan_auser'], $id]);
  admin_log_action('unban', '', 0, "Unbanned ban #$id");
  echo '<p>Ban #' . $id . ' lifted.</p>';
  echo '<p><a href="?admin=banlist">Back to ban list</a></p>';
}

function admin_modlog() {
  if (!has_level('mod')) die('Access denied');

  $page = max(1, (int)$_GET['page']);
  $per_page = 100;
  $offset = ($page - 1) * $per_page;

  $db = YotsubaDB::global();
  $where = '';
  $params = [];
  if (isset($_GET['who']) && $_GET['who'] !== '') {
    $where = " WHERE admin = ?";
    $params = [$_GET['who']];
  }

  $res = $db->query("SELECT * FROM {$db->qi('mod_log')}" . $where . " ORDER BY ts DESC LIMIT " . (int)$per_page . " OFFSET " . (int)$offset, $params);

  echo '<h3>Moderation Log</h3>';
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>Time</th><th>Staff</th><th>Action</th><th>Board</th><th>Post</th><th>Detail</th></tr>';

  if (!$res || !$res->rowCount()) {
    echo '<tr><td colspan="6">No log entries.</td></tr>';
  }
  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    echo '<tr>';
    echo '<td style="font-size:11px;white-space:nowrap">' . htmlspecialchars($row['ts']) . '</td>';
    echo '<td>' . htmlspecialchars($row['admin']) . '</td>';
    echo '<td>' . htmlspecialchars($row['action']) . '</td>';
    echo '<td>/' . htmlspecialchars($row['board']) . '/</td>';
    echo '<td>' . ($row['post_id'] ? $row['post_id'] : '') . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars(substr($row['detail'], 0, 200)) . '</td>';
    echo '</tr>';
  }
  echo '</table>';
}

function admin_wordfilters() {
  if (!has_level('mod')) die('Access denied');

  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_filter'])) {
      $pattern = $_POST['pattern'];
      $replacement = $_POST['replacement'];
      $board = $_POST['filter_board'];
      $is_regex = isset($_POST['is_regex']) ? 1 : 0;
      $db = YotsubaDB::global();
      if ($pattern !== '') {
        $db->query("INSERT INTO {$db->qi('word_filters')} (pattern, replacement, board, is_regex, added_by) VALUES (?, ?, ?, ?, ?)",
          [$pattern, $replacement, $board, $is_regex, $_COOKIE['4chan_auser']]);
        admin_log_action('wordfilter_add', $board, 0, "Added filter: $pattern -> $replacement");
      }
    }
    if (isset($_POST['delete_filter'])) {
      $db = YotsubaDB::global();
      $fid = (int)$_POST['filter_id'];
      $db->query("DELETE FROM {$db->qi('word_filters')} WHERE id = ?", [$fid]);
      admin_log_action('wordfilter_delete', '', 0, "Deleted filter #$fid");
    }
    if (isset($_POST['toggle_filter'])) {
      $db = YotsubaDB::global();
      $fid = (int)$_POST['filter_id'];
      $db->query("UPDATE {$db->qi('word_filters')} SET active = 1 - active WHERE id = ?", [$fid]);
    }
  }

  $db = YotsubaDB::global();
  $res = $db->query("SELECT * FROM {$db->qi('word_filters')} ORDER BY board, id");

  echo '<h3>Word Filters</h3>';
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>ID</th><th>Board</th><th>Pattern</th><th>Replacement</th><th>Regex</th><th>Active</th><th>Added By</th><th>Actions</th></tr>';

  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    $active_style = $row['active'] ? 'color:green' : 'color:#999';
    echo '<tr>';
    echo '<td>' . $row['id'] . '</td>';
    echo '<td>' . ($row['board'] ?: '<i>all</i>') . '</td>';
    echo '<td><code>' . htmlspecialchars($row['pattern']) . '</code></td>';
    echo '<td>' . htmlspecialchars($row['replacement']) . '</td>';
    echo '<td>' . ($row['is_regex'] ? 'Yes' : 'No') . '</td>';
    echo '<td style="' . $active_style . '">' . ($row['active'] ? 'Yes' : 'No') . '</td>';
    echo '<td>' . htmlspecialchars($row['added_by']) . '</td>';
    echo '<td>';
    echo '<form method="post" style="display:inline"><input type="hidden" name="admin" value="wordfilters"><input type="hidden" name="filter_id" value="' . $row['id'] . '">';
    echo '<button type="submit" name="toggle_filter" value="1" style="font-size:11px">' . ($row['active'] ? 'Disable' : 'Enable') . '</button>';
    echo ' <button type="submit" name="delete_filter" value="1" style="font-size:11px;color:red" onclick="return confirm(\'Delete this filter?\')">Delete</button>';
    echo '</form></td>';
    echo '</tr>';
  }
  echo '</table>';

  echo '<h4 style="margin-top:15px">Add New Filter</h4>';
  echo '<form method="post">';
  echo '<input type="hidden" name="admin" value="wordfilters">';
  echo '<table cellpadding="4"><tr>';
  echo '<td>Pattern: <input type="text" name="pattern" size="20"></td>';
  echo '<td>Replace with: <input type="text" name="replacement" size="20"></td>';
  echo '<td>Board: <input type="text" name="filter_board" size="5" placeholder="(all)"></td>';
  echo '<td><label><input type="checkbox" name="is_regex"> Regex</label></td>';
  echo '<td><input type="submit" name="add_filter" value="Add Filter"></td>';
  echo '</tr></table></form>';
}

function admin_blotter() {
  if (!has_level('mod')) die('Access denied');

  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $db = YotsubaDB::global();
    if (isset($_POST['add_blotter']) && $_POST['message'] !== '') {
      $db->query("INSERT INTO {$db->qi('blotter')} (message) VALUES (?)", [$_POST['message']]);
      admin_log_action('blotter_add', '', 0, substr($_POST['message'], 0, 100));
    }
    if (isset($_POST['delete_blotter'])) {
      $bid = (int)$_POST['blotter_id'];
      $db->query("DELETE FROM {$db->qi('blotter')} WHERE id = ?", [$bid]);
      admin_log_action('blotter_delete', '', 0, "Deleted blotter #$bid");
    }
  }

  $db = YotsubaDB::global();
  $res = $db->query("SELECT * FROM {$db->qi('blotter')} ORDER BY id DESC");

  echo '<h3>Blotter / News Manager</h3>';
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>ID</th><th>Message</th><th>Date</th><th>Actions</th></tr>';

  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    echo '<tr>';
    echo '<td>' . $row['id'] . '</td>';
    echo '<td>' . htmlspecialchars($row['message']) . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($row['created']) . '</td>';
    echo '<td><form method="post" style="display:inline"><input type="hidden" name="admin" value="blottermgr"><input type="hidden" name="blotter_id" value="' . $row['id'] . '">';
    echo '<button type="submit" name="delete_blotter" value="1" style="font-size:11px;color:red" onclick="return confirm(\'Delete?\')">Delete</button></form></td>';
    echo '</tr>';
  }
  echo '</table>';

  echo '<h4 style="margin-top:15px">Add Blotter Entry</h4>';
  echo '<form method="post"><input type="hidden" name="admin" value="blottermgr">';
  echo '<textarea name="message" cols="60" rows="3" placeholder="Blotter message (HTML allowed)"></textarea><br>';
  echo '<input type="submit" name="add_blotter" value="Post"></form>';
}

function admin_stafflist() {
  if (!has_level('admin')) die('Access denied');

  $db = YotsubaDB::global();
  if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_staff'])) {
    $uid = (int)$_POST['user_id'];
    if ($uid > 0) {
      $check = $db->query("SELECT username FROM {$db->qi('mod_users')} WHERE id = ?", [$uid]);
      $target = $check->fetch(PDO::FETCH_ASSOC);
      if ($target && $target['username'] !== $_COOKIE['4chan_auser']) {
        $db->query("DELETE FROM {$db->qi('mod_users')} WHERE id = ?", [$uid]);
        admin_log_action('staff_delete', '', 0, "Deleted staff: " . $target['username']);
      }
    }
  }

  $res = $db->query("SELECT * FROM {$db->qi('mod_users')} ORDER BY FIELD(level,'admin','manager','mod','janitor'), username");

  echo '<h3>Staff List</h3>';
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>ID</th><th>Username</th><th>Level</th><th>Flags</th><th>Allow</th><th>Deny</th><th>Last Login</th><th>Actions</th></tr>';

  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    $level_colors = array('admin' => '#AF0A0F', 'manager' => '#E04000', 'mod' => '#117743', 'janitor' => '#34345C');
    $lc = isset($level_colors[$row['level']]) ? $level_colors[$row['level']] : '#000';
    echo '<tr>';
    echo '<td>' . $row['id'] . '</td>';
    echo '<td><b>' . htmlspecialchars($row['username']) . '</b></td>';
    echo '<td style="color:' . $lc . '">' . htmlspecialchars($row['level']) . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($row['flags']) . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($row['allow']) . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($row['deny']) . '</td>';
    echo '<td style="font-size:11px">' . ($row['last_login'] ?: 'Never') . '</td>';
    echo '<td>';
    echo '<a href="?admin=staffedit&id=' . $row['id'] . '">[Edit]</a> ';
    if ($row['username'] !== $_COOKIE['4chan_auser']) {
      echo '<form method="post" style="display:inline"><input type="hidden" name="admin" value="stafflist"><input type="hidden" name="user_id" value="' . $row['id'] . '">';
      echo '<button type="submit" name="delete_staff" value="1" style="font-size:11px;color:red" onclick="return confirm(\'Delete ' . htmlspecialchars($row['username']) . '?\')">Delete</button></form>';
    }
    echo '</td>';
    echo '</tr>';
  }
  echo '</table>';

  echo '<h4 style="margin-top:15px">Add Staff Member</h4>';
  echo '<form method="post" action="?admin=staffedit">';
  echo '<table cellpadding="4"><tr>';
  echo '<td>Username: <input type="text" name="username" size="15"></td>';
  echo '<td>Password: <input type="text" name="new_password" size="15"></td>';
  echo '<td>Level: <select name="level"><option value="janitor">Janitor</option><option value="mod">Mod</option><option value="manager">Manager</option><option value="admin">Admin</option></select></td>';
  echo '<td>Boards: <input type="text" name="allow" size="15" value="all" placeholder="all or b,v,g"></td>';
  echo '<td><input type="submit" name="add_staff" value="Add"></td>';
  echo '</tr></table></form>';
}

function admin_staffedit() {
  if (!has_level('admin')) die('Access denied');

  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $db = YotsubaDB::global();
    if (isset($_POST['add_staff']) && $_POST['username'] !== '') {
      $db->query("INSERT INTO {$db->qi('mod_users')} (username, password, level, allow, signed_agreement, ips) VALUES (?, ?, ?, ?, 1, '{}')",
        [$_POST['username'], $_POST['new_password'], $_POST['level'], $_POST['allow']]);
      admin_log_action('staff_add', '', 0, "Added staff: " . $_POST['username'] . " (" . $_POST['level'] . ")");
      echo '<p>Staff member added. <a href="?admin=stafflist">Back to staff list</a></p>';
      return;
    }
    if (isset($_POST['save_staff'])) {
      $db = YotsubaDB::global();
      $uid = (int)$_POST['user_id'];
      $data = [];
      if ($_POST['level'] !== '') $data['level'] = $_POST['level'];
      $data['flags'] = ($_POST['flags'] !== '') ? $_POST['flags'] : '';
      if ($_POST['allow'] !== '') $data['allow'] = $_POST['allow'];
      $data['deny'] = ($_POST['deny'] !== '') ? $_POST['deny'] : '';
      if ($_POST['new_password'] !== '') $data['password'] = $_POST['new_password'];
      if (!empty($data)) {
        [$sql, $params] = $db->buildUpdate('mod_users', $data, ['id' => $uid]);
        $db->query($sql, $params);
        admin_log_action('staff_edit', '', 0, "Edited staff #$uid");
      }
      echo '<p>Staff member updated. <a href="?admin=stafflist">Back to staff list</a></p>';
      return;
    }
  }

  $db = YotsubaDB::global();
  $uid = (int)$_GET['id'];
  if (!$uid) { echo '<p>No user ID</p>'; return; }

  $res = $db->query("SELECT * FROM {$db->qi('mod_users')} WHERE id = ?", [$uid]);
  $user = $res->fetch(PDO::FETCH_ASSOC);
  if (!$user) { echo '<p>User not found</p>'; return; }

  echo '<h3>Edit Staff: ' . htmlspecialchars($user['username']) . '</h3>';
  echo '<form method="post"><input type="hidden" name="admin" value="staffedit"><input type="hidden" name="user_id" value="' . $uid . '">';
  echo '<table cellpadding="6">';
  echo '<tr><td>Username:</td><td><b>' . htmlspecialchars($user['username']) . '</b></td></tr>';
  echo '<tr><td>Level:</td><td><select name="level">';
  foreach (array('janitor', 'mod', 'manager', 'admin') as $lv) {
    $sel = ($user['level'] === $lv) ? ' selected' : '';
    echo '<option value="' . $lv . '"' . $sel . '>' . $lv . '</option>';
  }
  echo '</select></td></tr>';
  echo '<tr><td>Flags:</td><td><input type="text" name="flags" value="' . htmlspecialchars($user['flags']) . '" size="40" placeholder="ban,banmsg,developer"></td></tr>';
  echo '<tr><td>Allow boards:</td><td><input type="text" name="allow" value="' . htmlspecialchars($user['allow']) . '" size="40" placeholder="all or b,v,g"></td></tr>';
  echo '<tr><td>Deny boards:</td><td><input type="text" name="deny" value="' . htmlspecialchars($user['deny']) . '" size="40"></td></tr>';
  echo '<tr><td>New password:</td><td><input type="text" name="new_password" size="20" placeholder="(leave blank to keep)"></td></tr>';
  echo '<tr><td></td><td><input type="submit" name="save_staff" value="Save Changes"> <a href="?admin=stafflist">Cancel</a></td></tr>';
  echo '</table></form>';
}

function admin_getmanager() {
  if (!has_level('admin') && !is_local()) die('Access denied');

  $msg = '';

  // Handle POST: set new AUTO_INCREMENT
  if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['set_autoinc'])) {
    $board = preg_replace('/[^a-z0-9]/i', '', $_POST['board_table']);
    $newval = (int)$_POST['autoinc_value'];

    if ($board === '' || $newval < 1) {
      $msg = '<p style="color:red;font-weight:bold">Invalid board or value.</p>';
    } else {
      // Verify the board table exists
      $db = YotsubaDB::global();
      $check = $db->query(
        "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?",
        [$board]
      );
      $exists = $check->fetch(PDO::FETCH_ASSOC);

      if (!$exists) {
        $msg = '<p style="color:red;font-weight:bold">Table `' . htmlspecialchars($board) . '` does not exist.</p>';
      } else {
        // ALTER TABLE cannot use prepared statement placeholders for table/value
        // Board name is already sanitized to alphanumeric, value is cast to int
        $sql = 'ALTER TABLE ' . $db->qi($board) . ' AUTO_INCREMENT = ' . $newval;
        $result = $db->exec($sql);

        if ($result === false) {
          $err = $db->getPdo()->errorInfo();
          $msg = '<p style="color:red;font-weight:bold">Error: ' . htmlspecialchars($err[2]) . '</p>';
        } else {
          $msg = '<p style="color:green;font-weight:bold">AUTO_INCREMENT for `' . htmlspecialchars($board) . '` set to ' . $newval . '</p>';
          admin_log_action('set_autoinc', $board, 0, "AUTO_INCREMENT set to $newval");
        }
      }
    }
  }

  // Query all board tables and their AUTO_INCREMENT values
  $db = YotsubaDB::global();
  $res = $db->query(
    "SELECT t.TABLE_NAME, t.AUTO_INCREMENT FROM information_schema.TABLES t "
    . "INNER JOIN {$db->qi('boardlist')} b ON b.dir = t.TABLE_NAME "
    . "WHERE t.TABLE_SCHEMA = DATABASE() AND t.AUTO_INCREMENT IS NOT NULL "
    . "ORDER BY t.TABLE_NAME"
  );

  echo '<h3>GET Manager <span style="font-size:11px;color:#888">(AUTO_INCREMENT)</span></h3>';
  echo '<p style="font-size:11px;color:#666">Set the next post number for any board. Hidden admin tool &mdash; not linked from navigation.</p>';

  if ($msg) echo $msg;

  // Board table listing
  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px">';
  echo '<tr style="background:#D6DAF0"><th>Board</th><th>Next Post No. (AUTO_INCREMENT)</th></tr>';

  $boards = array();
  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    $boards[] = $row;
    $hi = ((int)$row['AUTO_INCREMENT'] > 999999) ? ' style="background:#FFFFCC"' : '';
    echo '<tr' . $hi . '>';
    echo '<td><b>/' . htmlspecialchars($row['TABLE_NAME']) . '/</b></td>';
    echo '<td style="font-family:monospace">' . number_format((int)$row['AUTO_INCREMENT']) . '</td>';
    echo '</tr>';
  }
  echo '</table>';

  // Set AUTO_INCREMENT form
  echo '<h4 style="margin-top:15px">Set Next Post Number</h4>';
  echo '<form method="post">';
  echo '<input type="hidden" name="admin" value="getmanager">';
  echo '<table cellpadding="3" cellspacing="0" style="font-size:12px">';
  echo '<tr><td>Board:</td><td><select name="board_table">';
  foreach ($boards as $b) {
    echo '<option value="' . htmlspecialchars($b['TABLE_NAME']) . '">/' . htmlspecialchars($b['TABLE_NAME']) . '/ (currently ' . number_format((int)$b['AUTO_INCREMENT']) . ')</option>';
  }
  echo '</select></td></tr>';
  echo '<tr><td>New value:</td><td><input type="text" name="autoinc_value" size="12" placeholder="e.g. 1000000"> <span style="font-size:11px;color:#888">next post will get this number</span></td></tr>';
  echo '<tr><td></td><td><input type="submit" name="set_autoinc" value="Set AUTO_INCREMENT" onclick="return confirm(\'Are you sure you want to change the next post number?\')"></td></tr>';
  echo '</table>';
  echo '</form>';

  echo '<p style="font-size:11px;color:#999;margin-top:15px">Note: AUTO_INCREMENT can only be set to a value greater than or equal to the current maximum post number in the table. MySQL will silently adjust if needed.</p>';
}

function admin_log_action($action, $board, $post_id, $detail) {
  try {
    $db = YotsubaDB::global();
    $db->query("INSERT INTO {$db->qi('mod_log')} (admin, action, board, post_id, detail, ip) VALUES (?, ?, ?, ?, ?, ?)",
      [$_COOKIE['4chan_auser'], $action, $board, $post_id, $detail, $_SERVER['REMOTE_ADDR']]);
  } catch (Exception $e) {
    // Suppress errors like the original @-prefixed call
  }
}

function admin_appeals() {
  if (!has_level('mod') && !is_local()) die('Access denied');

  $db = YotsubaDB::global();
  $admin_user = $_COOKIE['4chan_auser'];

  // Handle approve/deny actions
  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $appeal_id = (int)$_POST['appeal_id'];

    if ($appeal_id > 0 && (isset($_POST['approve_appeal']) || isset($_POST['deny_appeal']))) {
      // Fetch the appeal
      $aq = $db->query("SELECT * FROM {$db->qi('ban_appeals')} WHERE id = ? LIMIT 1", [$appeal_id]);
      $appeal = $aq ? $aq->fetch(PDO::FETCH_ASSOC) : null;

      if (!$appeal) {
        echo '<p style="color:red">Appeal not found.</p>';
      } else if ($appeal['status'] !== 'pending') {
        echo '<p style="color:red">Appeal has already been resolved.</p>';
      } else {
        $mod_response = trim($_POST['mod_response']);

        if (isset($_POST['approve_appeal'])) {
          // Approve: lift the ban
          $db->query(
            "UPDATE {$db->qi('ban_appeals')} SET status = 'approved', mod_response = ?, mod_user = ?, resolved_at = NOW() WHERE id = ?",
            [$mod_response, $admin_user, $appeal_id]
          );
          $db->query(
            "UPDATE {$db->qi(SQLLOGBAN)} SET active = 0, unbannedon = NOW(), unbannedby = ? WHERE no = ?",
            [$admin_user, (int)$appeal['ban_id']]
          );
          admin_log_action('appeal_approve', '', 0, "Approved appeal #$appeal_id, lifted ban #" . $appeal['ban_id']);
          echo '<p style="color:green">Appeal #' . $appeal_id . ' approved. Ban #' . (int)$appeal['ban_id'] . ' has been lifted.</p>';
        } else {
          // Deny
          $db->query(
            "UPDATE {$db->qi('ban_appeals')} SET status = 'denied', mod_response = ?, mod_user = ?, resolved_at = NOW() WHERE id = ?",
            [$mod_response, $admin_user, $appeal_id]
          );
          admin_log_action('appeal_deny', '', 0, "Denied appeal #$appeal_id for ban #" . $appeal['ban_id']);
          echo '<p style="color:#856404">Appeal #' . $appeal_id . ' denied.</p>';
        }
      }
    }
  }

  // --- Determine view ---
  $view = isset($_GET['view']) ? $_GET['view'] : 'pending';

  echo '<h3>Ban Appeals</h3>';
  echo '<p>';
  foreach (array('pending', 'approved', 'denied', 'all') as $tab) {
    $bold = ($view === $tab) ? 'font-weight:bold' : '';
    echo '<a href="?admin=appeals&view=' . $tab . '" style="margin-right:12px;' . $bold . '">' . ucfirst($tab) . '</a>';
  }
  echo '</p>';

  // Build query
  $where_params = [];
  if ($view === 'all') {
    $where = '';
  } else {
    $where = " WHERE a.status = ?";
    $where_params = [$view];
  }

  $page = max(1, (int)$_GET['page']);
  $per_page = 50;
  $offset = ($page - 1) * $per_page;

  // Count
  $count_q = $db->query("SELECT COUNT(*) FROM {$db->qi('ban_appeals')} a" . $where, $where_params);
  $total = $count_q ? (int)$count_q->fetch(PDO::FETCH_NUM)[0] : 0;

  // Fetch appeals with ban info
  $sql = "SELECT a.*, b.host, b.reason as ban_reason, b.board as ban_board, b.global as ban_global, "
    . "b.active as ban_active, b.admin as banned_by, "
    . $db->unixTimestamp('b.now') . " as ban_starts, " . $db->unixTimestamp('b.length') . " as ban_ends "
    . "FROM {$db->qi('ban_appeals')} a "
    . "LEFT JOIN {$db->qi(SQLLOGBAN)} b ON a.ban_id = b.no"
    . $where
    . " ORDER BY a.created_at DESC LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;

  $res = $db->query($sql, $where_params);

  // Pending count badge
  $pending_q = $db->query("SELECT COUNT(*) FROM {$db->qi('ban_appeals')} WHERE status = 'pending'");
  $pending_count = $pending_q ? (int)$pending_q->fetch(PDO::FETCH_NUM)[0] : 0;
  if ($pending_count > 0) {
    echo '<p><b>' . $pending_count . ' pending appeal' . ($pending_count > 1 ? 's' : '') . '</b></p>';
  }

  echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:12px;width:100%">';
  echo '<tr style="background:#D6DAF0"><th>Appeal&nbsp;#</th><th>Ban&nbsp;#</th><th>IP</th><th>Ban&nbsp;Reason</th><th>Scope</th>';
  echo '<th>Ban&nbsp;Expires</th><th>Appeal&nbsp;Text</th><th>Submitted</th><th>Status</th>';
  if ($view === 'pending') {
    echo '<th>Actions</th>';
  } else {
    echo '<th>Mod</th><th>Response</th>';
  }
  echo '</tr>';

  if (!$res || !$res->rowCount()) {
    $colspan = ($view === 'pending') ? 10 : 11;
    echo '<tr><td colspan="' . $colspan . '" style="text-align:center;padding:15px">No appeals found.</td></tr>';
  }

  while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
    $ban_reasons = explode('<>', $row['ban_reason']);
    $pub_reason = $ban_reasons[0] ?: '(none)';
    $scope = $row['ban_global'] ? '<b>Global</b>' : '/' . htmlspecialchars($row['ban_board']) . '/';
    $ban_ends = (int)$row['ban_ends'];
    $expiry = ($ban_ends == 0) ? '<span style="color:red">Permanent</span>' : date('Y-m-d', $ban_ends);
    $ban_active_text = $row['ban_active'] ? '<span style="color:green">Active</span>' : '<span style="color:#999">Lifted</span>';
    $appeal_excerpt = htmlspecialchars(substr($row['appeal_text'], 0, 150));
    if (strlen($row['appeal_text']) > 150) $appeal_excerpt .= '...';

    $status_colors = array('pending' => '#856404', 'approved' => '#155724', 'denied' => '#721C24');
    $sc = isset($status_colors[$row['status']]) ? $status_colors[$row['status']] : '#000';

    echo '<tr>';
    echo '<td>' . (int)$row['id'] . '</td>';
    echo '<td>' . (int)$row['ban_id'] . '</td>';
    echo '<td>' . htmlspecialchars($row['ip']) . '</td>';
    echo '<td style="font-size:11px">' . htmlspecialchars($pub_reason) . '</td>';
    echo '<td>' . $scope . '</td>';
    echo '<td style="font-size:11px">' . $expiry . ' ' . $ban_active_text . '</td>';
    echo '<td style="font-size:11px">' . $appeal_excerpt . '</td>';
    echo '<td style="font-size:11px;white-space:nowrap">' . htmlspecialchars($row['created_at']) . '</td>';
    echo '<td style="color:' . $sc . ';font-weight:bold">' . ucfirst($row['status']) . '</td>';

    if ($view === 'pending') {
      echo '<td style="white-space:nowrap">';
      echo '<form method="post" style="display:inline">';
      echo '<input type="hidden" name="admin" value="appeals">';
      echo '<input type="hidden" name="appeal_id" value="' . (int)$row['id'] . '">';
      echo '<div style="margin-bottom:4px"><input type="text" name="mod_response" placeholder="Response (optional)" size="20" style="font-size:11px"></div>';
      echo '<button type="submit" name="approve_appeal" value="1" style="font-size:11px;color:green" onclick="return confirm(\'Approve this appeal and lift ban #' . (int)$row['ban_id'] . '?\')">Approve</button> ';
      echo '<button type="submit" name="deny_appeal" value="1" style="font-size:11px;color:red" onclick="return confirm(\'Deny this appeal?\')">Deny</button>';
      echo '</form></td>';
    } else {
      echo '<td style="font-size:11px">' . htmlspecialchars($row['mod_user']) . '</td>';
      echo '<td style="font-size:11px">' . htmlspecialchars($row['mod_response']) . '</td>';
    }
    echo '</tr>';
  }
  echo '</table>';

  // Pagination
  $pages = ceil($total / $per_page);
  if ($pages > 1) {
    echo '<p>Page: ';
    for ($i = 1; $i <= $pages && $i <= 20; $i++) {
      $bold = ($i == $page) ? 'font-weight:bold' : '';
      echo '<a href="?admin=appeals&view=' . $view . '&page=' . $i . '" style="margin:0 3px;' . $bold . '">' . $i . '</a>';
    }
    echo '</p>';
  }

  echo '<p style="font-size:11px;color:#666;margin-top:15px">' . $total . ' total appeal' . ($total != 1 ? 's' : '') . ' (' . $view . ')</p>';
}

/*-----------Main-------------*/

// Can't check for csrf token for this. Only check the referer.
validate_csrf($admin === 'delall');

switch($admin) {
	case 'adminext':
		adminvalid();
		adminExt();
		break;

	case 'banreq':
		adminvalid( 'Ban Request' );
		adminBanReq();
		break;
	case 'del':
		adminvalid();
		//admin_delete();
		break;
	case 'delall':
		adminvalid();
		admindelall();
		break;
	case 'delallbyip':
		adminvalid();
		delallbyip( $_POST[ 'ip' ], $_POST[ 'imgonly' ] );
		break;
	case 'ban':
		adminvalid( 'Ban User' );
		adminban();
		break;
	case 'opt':
		adminvalid( 'Thread Options' );
		adminopt();
		break;
	case 'spoiler':
		admin_toggle_spoiler();
	  break;
	case 'cleanup':
		adminvalid( 'Board Cleanup' );
		clean();
		break;
	case 'cpban':
		adminvalid();
		cpban((int)$_POST['no']);
		break;
  case 'rev':
    admin_reverse_ip();
    break;
  case 'reportqueue':
    adminvalid();
    adminreportqueue();
    break;
  case 'reportclear':
    adminvalid();
    adminreportclear();
    break;
  case 'banlist':
    adminvalid('Ban List');
    admin_banlist();
    break;
  case 'unban':
    adminvalid();
    admin_unban();
    break;
  case 'modlog':
    adminvalid('Moderation Log');
    admin_modlog();
    break;
  case 'wordfilters':
    adminvalid('Word Filters');
    admin_wordfilters();
    break;
  case 'blottermgr':
    adminvalid('Blotter Manager');
    admin_blotter();
    break;
  case 'stafflist':
    adminvalid('Staff List');
    admin_stafflist();
    break;
  case 'staffedit':
    adminvalid('Edit Staff');
    admin_staffedit();
    break;
  case 'getmanager':
    adminvalid('GET Manager');
    admin_getmanager();
    break;
  case 'appeals':
    adminvalid('Ban Appeals');
    admin_appeals();
    break;
	default:
		adminvalid();
		ob_end_flush();
		$board = BOARD_DIR;

		$threads = array();
		$db_board = YotsubaDB::board();
		$res = $db_board->query("SELECT no, sub, com, now FROM {$db_board->qi(BOARD_DIR)} WHERE resto = 0 ORDER BY no DESC LIMIT 20");
		while ($res && $row = $res->fetch(PDO::FETCH_ASSOC)) {
			$threads[] = $row;
		}

		$db_global = YotsubaDB::global();
		$boards_res = $db_global->query("SELECT dir FROM {$db_global->qi('boardlist')} ORDER BY dir");
		$board_links = array();
		while ($boards_res && $brow = $boards_res->fetch(PDO::FETCH_ASSOC)) {
			$d = $brow['dir'];
			$sel = ($d === $board) ? ' <b>(current)</b>' : '';
			$board_links[] = '<a href="/' . $d . '/admin">' . $d . '</a>' . $sel;
		}

		echo '<br clear="all"><div style="padding:10px">';
		echo '<h2>/' . htmlspecialchars($board) . '/ — Admin Panel</h2>';

		echo '<h3>Moderation</h3><ul>';
		echo '<li><a href="admin?admin=reportqueue">Report Queue</a> — review pending user reports</li>';
		echo '<li><a href="admin?admin=banlist">Ban List</a> — view/search bans, unban users</li>';
		echo '<li><a href="admin?admin=appeals">Ban Appeals</a> — review and resolve user ban appeals</li>';
		echo '<li><a href="admin?admin=modlog">Moderation Log</a> — audit trail of staff actions</li>';
		echo '</ul>';

		echo '<h3>Site Management</h3><ul>';
		echo '<li><a href="admin?admin=wordfilters">Word Filters</a> — manage word/phrase replacements</li>';
		echo '<li><a href="admin?admin=blottermgr">Blotter / News</a> — manage site announcements</li>';
		echo '<li><a href="admin?admin=cleanup">Board Cleanup</a> — prune orphaned posts and temp files</li>';
		echo '</ul>';

		if (has_level('admin')) {
			echo '<h3>Administration</h3><ul>';
			echo '<li><a href="admin?admin=stafflist">Staff List</a> — manage mods, janitors, admins</li>';
			echo '</ul>';
		}

		echo '<h3>Thread Actions</h3>';
		if (count($threads) > 0) {
			echo '<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;font-size:13px">';
			echo '<tr><th>No.</th><th>Subject/Comment</th><th>Date</th><th>Actions</th></tr>';
			foreach ($threads as $t) {
				$no = (int)$t['no'];
				$preview = $t['sub'] ?: strip_tags(substr($t['com'], 0, 60));
				if (!$preview) $preview = '(no text)';
				echo '<tr>';
				echo '<td>' . $no . '</td>';
				echo '<td>' . htmlspecialchars($preview) . '</td>';
				echo '<td>' . htmlspecialchars($t['now']) . '</td>';
				echo '<td>';
				echo '<a href="admin?admin=opt&id=' . $no . '">options</a> ';
				echo '<a href="admin?admin=ban&id=' . $no . '">ban OP</a>';
				echo '</td></tr>';
			}
			echo '</table>';
		} else {
			echo '<p>No threads on this board yet.</p>';
		}

		echo '<h3>Switch Board</h3>';
		echo '<p style="font-size:12px">' . implode(' / ', $board_links) . '</p>';

		echo '<h3>Quick Links</h3><ul>';
		echo '<li><a href="/' . htmlspecialchars($board) . '/">Return to /' . htmlspecialchars($board) . '/</a></li>';
		echo '</ul>';
		echo '</div></body></html>';
}
