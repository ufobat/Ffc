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

srand;

sub r { '>>> ' . rand(10000) . ' <<<' }

BEGIN {
    my $config = {
        "cookie_secret"   => "geh doch heim",
        "dsn"             => "DBI:SQLite:database=",
        "user"            => "",
        "password"        => "",
        "dbprefix"        => "asb_",
        "cryptsalt"       => "123456789",
        "postlimit"       => "10",
        "title"           => "Alternatives Einfaches Brett",
        "pagelinkpreview" => 2,
        "sessiontimeout"  => 3600,
        "theme"           => "default",
        "debug"           => 0,
        "acttitles"       => {
            "forum"   => "Forenboard",
            "notes"   => "Notizen",
            "msgs"    => "Privatnachrichten",
            "auth"    => "Anmeldung",
            "options" => "Einstellungen"
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

my $app = Mojolicious->new();
ok( AltSimpleBoard::Data::set_config($app), 'config set returned true' );
my $dbh = AltSimpleBoard::Data::dbh();
is( ref($dbh), 'DBI::db', 'got dbi handle' );

END {
    unlink $ENV{ASB_CONFIG};
    unlink $ENV{ASB_DATABASE};
}

