<?php
/**
 * DNSBL (DNS Blacklist) checking for post submissions.
 * Ported from vichan, adapted for Yotsuba's architecture.
 */

$dnsbl_providers = array(
  'zen.spamhaus.org',
  array('rbl.efnetrbl.org', 4),
  array('dnsbl.dronebl.org', array(2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19)),
);

$dnsbl_exceptions = array();

function dnsbl_reverse_ip($ip) {
  return implode('.', array_reverse(explode('.', $ip)));
}

function dnsbl_lookup($host) {
  $ip_addr = gethostbyname($host);
  if ($ip_addr === $host) {
    return false;
  }
  return $ip_addr;
}

function dnsbl_check($ip) {
  global $dnsbl_providers, $dnsbl_exceptions;

  if (strpos($ip, ':') !== false) {
    return false;
  }

  if (preg_match('/^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|0\.|255\.)/', $ip)) {
    return false;
  }

  if (in_array($ip, $dnsbl_exceptions)) {
    return false;
  }

  $reversed = dnsbl_reverse_ip($ip);

  foreach ($dnsbl_providers as $blacklist) {
    if (!is_array($blacklist)) {
      $blacklist = array($blacklist);
    }

    $lookup = str_replace('%', $reversed, $blacklist[0]);
    if ($lookup === $blacklist[0]) {
      $lookup = $reversed . '.' . $blacklist[0];
    }

    $result = dnsbl_lookup($lookup);
    if (!$result) {
      continue;
    }

    $provider_name = isset($blacklist[2]) ? $blacklist[2] : $blacklist[0];

    if (!isset($blacklist[1])) {
      return $provider_name;
    } elseif (is_array($blacklist[1])) {
      foreach ($blacklist[1] as $octet) {
        if ($result === '127.0.0.' . $octet) {
          return $provider_name;
        }
      }
    } else {
      if ($result === $blacklist[1] || $result === '127.0.0.' . $blacklist[1]) {
        return $provider_name;
      }
    }
  }

  return false;
}
