<?php
define('IN_PHPBB',1);
$phpbb_root_path = $argv[2];
$phpEx = 'php';
include "$phpbb_root_path/common.php";
print phpbb_hash($argv[1]); 
?>
