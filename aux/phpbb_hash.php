<?php
    define('IN_PHPBB',1);
    $phpbb_root_path = $argv[1];
    $phpEx = 'php';
    include "$phpbb_root_path/common.php";
    if ( phpbb_check_hash($argv[2], $argv[3]) ) {
        echo 1;
    }
    else {
        echo 0;
    }
?>
