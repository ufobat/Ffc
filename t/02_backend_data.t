#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use File::Temp;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mojo::JSON 'j';
use DBI;

use Test::More tests => 10;
my $config;

srand;

BEGIN {
    sub r { '>>> ' . rand(10000) . ' <<<' }
    $config = {
        "cookie_secret" => r(),
        "dsn"           => "DBI:SQLite:database=",
        "user"          => "",
        "password"      => "",
        "dbprefix"      => join( '',
            map { ( 'a' .. 'z' )[ int rand 26 ] } ( 0 .. int( rand 15 ) ) )
          . '_',
        "cryptsalt"       => int( rand 100000 ),
        "postlimit"       => int( rand 30 ),
        "title"           => r(),
        "pagelinkpreview" => int( rand 15 ),
        "sessiontimeout"  => int( rand 10000 ),
        "theme"           => r(),
        "debug"           => 0,
        "acttitles"       => {
            "forum"   => r(),
            "notes"   => r(),
            "msgs"    => r(),
            "auth"    => r(),
            "options" => r(),
        }
    };

    sub generate_configfile {
        my ( $cfh,  $configfilename ) = File::Temp::tempfile();
        my ( $dbfh, $dbfilename )     = File::Temp::tempfile();
        close $dbfh;
        unlink $dbfilename;
        DBI->connect( "DBI:SQLite:database=$dbfilename", '', '' )
          or die q(could not create database);
        $config->{dsn} .= $dbfilename;
        print $cfh j($config);
        return $configfilename, $dbfilename;
    }

    ( $ENV{ASB_CONFIG}, $ENV{ASB_DATABASE} ) = generate_configfile();
    use_ok('AltSimpleBoard::Data');
}

diag('checking configuration loading');
my $app = Mojolicious->new();
ok( AltSimpleBoard::Data::set_config($app), 'config set returned true' );

{
    diag('checking database configuration');
    my $dbh = AltSimpleBoard::Data::dbh();
    is( ref($dbh), 'DBI::db', 'got dbi handle' );
    ok( $dbh->{Name}, 'database name set');
    is( $dbh->{Name}, "database=$ENV{ASB_DATABASE}", 'database name ok' );
    {
        my $ret;
        my $exp = r();
        eval { $ret = $dbh->selectall_arrayref( 'SELECT ?', undef, $exp ) };
        ok( !$@, 'no errors from sql query ok' );
        is( ref($ret), 'ARRAY', 'array reference returned from sql query' );
        is( ref( $ret->[0] ),
            'ARRAY', 'array of array reference returned from sql query' );
        is( $ret->[0]->[0], $exp, 'returned value ok from sql query' );
    }
}

{
    diag('checking config values');

    is( AltSimpleBoard::Data::cryptsalt(),
        $config->{cryptsalt}, 'cryptsalt is ok' );
}

die Dumper $app->config;

END {
    unlink $ENV{ASB_CONFIG};
    unlink $ENV{ASB_DATABASE};
}

