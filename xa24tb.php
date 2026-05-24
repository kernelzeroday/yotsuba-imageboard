<?php
/*
define('DEV_MODE', $_SERVER['REMOTE_ADDR'] === '51.159.28.165');

if (!DEV_MODE) {
  http_response_code(404);
  echo('File not found.');
  die();
}
else {
  ini_set('display_errors', 1);
  error_reporting(E_ALL & ~E_NOTICE);
  $mysql_suppress_err = false;
}
*/
require_once 'lib/db.php';
require_once 'lib/userpwd.php';

define('CURRENCY_CODE', '_');
define('STARTING_AMOUNT', 1000);
define('MAX_BUY_SELL_SIZE', 1000);

const STOCK_LIST = [
  'PEPE', 'WOJK', 'ANIME', 'CHAD', 'CLOWN', 'LOL', 'SICP', 'AUTSM', 'BANE',
  'CIA', 'BOOB', 'RDDT', 'DESU', 'JANNY', 'GME', 'CHUCK', 'YTSB', 'GACHI'
];

function output_json($data) {
  header('Content-Type: application/json');
  echo json_encode($data);
}

function output_error($msg) {
  output_json(['error' => $msg]);
  die();
}

function create_account() {
  $user_ip = $_SERVER['REMOTE_ADDR'];

  if (isset($_COOKIE['4chan_pass'])) {
    $userpwd = new UserPwd($user_ip, '4chan.org', $_COOKIE['4chan_pass']);
  }
  else {
    $userpwd = new UserPwd($user_ip, '4chan.org');
  }

  $user_id = $userpwd->getPwd();

  $db = YotsubaDB::global();
  $res = $db->query("SELECT id FROM {$db->qi('april_stock_users')} WHERE user_id = ? LIMIT 1", [$user_id]);

  if ($res->rowCount()) {
    $account = get_account_balance($user_id);
    output_json($account);
    die();
  }

  $cur_code = CURRENCY_CODE;
  $cur_amount = (int)STARTING_AMOUNT;

  $res = $db->query("INSERT INTO {$db->qi('april_stock_users')} (user_id, stock, amount) VALUES (?, ?, ?)", [$user_id, $cur_code, $cur_amount]);

  if (!$res) {
    output_error('Internal Server Error (frac0)');
  }
  
  $userpwd->setCookie('.4chan.org');
  
  output_json([
    'balance' => $cur_amount
  ]);
}

function get_account_balance($user_id) {
  $db = YotsubaDB::global();
  $res = $db->query("SELECT stock, SUM(amount) as amount FROM {$db->qi('april_stock_users')} WHERE user_id = ? GROUP BY stock", [$user_id]);

  $data = [];

  while ($row = $res->fetch(PDO::FETCH_ASSOC)) {
    if ($row['stock'] == CURRENCY_CODE) {
      $amount = (int)$row['amount'];
      
      if ($amount < 0) {
        $amount = 0;
      }
      
      $data['balance'] = $amount;
    }
    else if (in_array($row['stock'], STOCK_LIST)) {
      $amount = (int)$row['amount'];
      
      if ($amount <= 0) {
        continue;
      }
      
      $data[$row['stock']] = $amount;
    }
  }
  
  return $data;
}

function get_account() {
  $user_ip = $_SERVER['REMOTE_ADDR'];
  
  if (!isset($_COOKIE['4chan_pass'])) {
    output_error('Account not found');
  }
  
  $userpwd = new UserPwd($user_ip, '4chan.org', $_COOKIE['4chan_pass']);
  
  if ($userpwd->isNew()) {
    output_error('Account not found');
  }
  
  $user_id = $userpwd->getPwd();
  
  $data = get_account_balance($user_id);
  
  return [$user_id, $data];
}

function get_stock_price($stock) {
  if ($stock == CURRENCY_CODE) {
    output_error('Stock not found');
  }

  $db = YotsubaDB::global();
  $res = $db->query("SELECT price FROM {$db->qi('april_stock_prices')} WHERE stock = ? ORDER BY id DESC LIMIT 1", [$stock]);

  $price = (int)$res->fetchColumn();
  
  if ($price <= 0) {
    return false;
  }
  
  return $price;
}

function get_stock_http_param() {
  if (!isset($_POST['stock']) || !$_POST['stock'] || $_POST['stock'] == CURRENCY_CODE) {
    return false;
  }
  
  return $_POST['stock'];
}

function get_amount_http_param() {
  if (!isset($_POST['amount']) || !$_POST['amount']) {
    return false;
  }
  
  $amount = (int)$_POST['amount'];
  
  if ($amount < 1 || $amount > MAX_BUY_SELL_SIZE) {
    return false;
  }
  
  return $amount;
}

function get_price_http_param() {
  if (!isset($_POST['price']) || !$_POST['price']) {
    return false;
  }
  
  $price = (int)$_POST['price'];
  
  if ($price < 1) {
    return false;
  }
  
  return $price;
}

function enforce_cooldown($user_id) {
  $db = YotsubaDB::global();
  $res = $db->query("SELECT id FROM {$db->qi('april_stock_users')} WHERE user_id = ? AND created_on > " . $db->dateInterval($db->now(), 10, 'SECOND'), [$user_id]);

  if ($res->rowCount()) {
    output_error('You can only make an order once every 10 seconds');
  }

  return false;
}

/**
 * BUY
 */

function buy_stock() {
  $stock = get_stock_http_param();
  
  if (!$stock) {
    output_error('Stock not found');
  }
  
  $amount = get_amount_http_param();
  
  if (!$amount) {
    output_error('Invalid amount');
  }
  
  $user_price = get_price_http_param();
  
  if (!$user_price) {
    output_error('Invalid price');
  }
  
  $price = get_stock_price($stock);
  
  if (!$price) {
    output_error('Invalid price');
  }
  
  if ($user_price != $price) {
    output_error('The price has changed.');
  }
  
  $total_price = $amount * $price;
  
  list($user_id, $account) = get_account();
  
  if ($total_price > $account['balance']) {
    output_error('Your account balance is too low');
  }
  
  enforce_cooldown($user_id);
  
  // Decrement balance
  $cur_code = CURRENCY_CODE;

  $db = YotsubaDB::global();
  $res = $db->query("INSERT INTO {$db->qi('april_stock_users')} (user_id, stock, amount) VALUES (?, ?, ?)", [$user_id, $cur_code, -$total_price]);

  if (!$res) {
    output_error('Internal Server Error (bi05-2)');
  }

  // Increment the stock amount
  $res = $db->query("INSERT INTO {$db->qi('april_stock_users')} (user_id, stock, amount) VALUES (?, ?, ?)", [$user_id, $stock, $amount]);

  if (!$res) {
    output_error('Internal Server Error (bi05-2)');
  }

  $account = get_account_balance($user_id);

  output_json($account);
}

/**
 * SELL
 */
function sell_stock() {
  $stock = get_stock_http_param();
  
  if (!$stock) {
    output_error('Stock not found');
  }
  
  $amount = get_amount_http_param();
  
  if (!$amount) {
    output_error('Invalid amount');
  }
  
  $user_price = get_price_http_param();
  
  if (!$user_price) {
    output_error('Invalid price');
  }
  
  $price = get_stock_price($stock);
  
  if (!$price) {
    output_error('Invalid price');
  }
  
  if ($user_price != $price) {
    output_error('The price has changed.');
  }
  
  $total_price = $amount * $price;
  
  list($user_id, $account) = get_account();
  
  if ($amount > $account[$stock]) {
    output_error('Your account balance is too low');
  }
  
  // Cooldown
  enforce_cooldown($user_id);
  
  // Decrement the stock amount
  $db = YotsubaDB::global();
  $res = $db->query("INSERT INTO {$db->qi('april_stock_users')} (user_id, stock, amount) VALUES (?, ?, ?)", [$user_id, $stock, -$amount]);

  if (!$res) {
    output_error('Internal Server Error (bi05-2)');
  }

  // Increment balance
  $cur_code = CURRENCY_CODE;

  $res = $db->query("INSERT INTO {$db->qi('april_stock_users')} (user_id, stock, amount) VALUES (?, ?, ?)", [$user_id, $cur_code, $total_price]);

  if (!$res) {
    output_error('Internal Server Error (bi05-2)');
  }

  $account_balance = get_account_balance($user_id);

  output_json($account_balance);
}

output_error('The market is closed');

if (isset($_POST['create'])) {
  create_account();
}
else if (isset($_POST['mode'])) {
  if ($_POST['mode'] === 'buy') {
    buy_stock();
  }
  else if ($_POST['mode'] === 'sell') {
    sell_stock();
  }
  else {
    output_error('Bad request');
  }
}
else {
  output_error('Bad request');
}
