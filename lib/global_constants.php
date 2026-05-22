<?php
// If captcha is already defined we have included global_config.ini already.
if( defined( 'CAPTCHA' ) ) return;
define( 'ONLY_PARSE_INI', true );

require_once 'localchan_config.php';