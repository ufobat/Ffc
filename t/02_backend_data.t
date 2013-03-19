#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Config;

use Test::More tests => 32;

srand;

sub r { '>>> ' . rand(10000) . ' <<<' }

BEGIN { use_ok('Ffc::Data') }

my $config = Mock::Config->new->{config};

note('checking configuration loading');
my $app = Mojolicious->new();
$app->log->level('error');
ok( Ffc::Data::set_config($app), 'config set returned true' );

{
    note('checking database configuration');
    my $dbh = Ffc::Data::dbh();
    is( ref($dbh), 'DBI::db', 'got dbi handle' );
    ok( $dbh->{Name}, 'database name set' );
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
    note('checking sensible config values');

    ok( keys( %{ $app->config } ), 'config stored in application' );

    is( Ffc::Data::cryptsalt(),
        $config->{cryptsalt}, 'cryptsalt is ok' );

    is( $app->secret, $config->{cookiesecret}, 'secret is ok' );

    ok( !exists( $app->config()->{cookiesecret} ),
        'secret deleted from config' );
    ok( !exists( $app->config()->{cryptsalt} ), 'secret deleted from config' );

    note('checking ordinary config values');
    {
        my %order = (
            dbprefix        => 'Prefix',
            postlimit       => 'Limit',
            pagelinkpreview => 'Pagelinkpreview',
            title           => 'Title',
            sessiontimeout  => 'SessionTimeout',
            debug           => 'Debug',
            theme           => 'Theme',
        );
        while ( my ( $k, $v ) = each %order ) {
            no strict 'refs';
            is( ${"Ffc::Data::$v"},
                $config->{$k},
                qq(config files "$k" matches application configs "$v") );
        }
    }

    note('checking computed config values');
    like($Ffc::Data::Themedir, qr/themes/, 'theme dir ok');
    like($Ffc::Data::Themebasedir, qr/$FindBin::Bin/, 'theme base dir inside project directory');
    like($Ffc::Data::Themedir, qr/$Ffc::Data::Themedir/, 'theme base dir ok');
    like($Ffc::Data::DefaultConfig, qr/$FindBin::Bin/, 'default config inside project directory');
    like($Ffc::Data::DefaultConfig, qr/etc/, 'default config in something with "etc" in it');
    like($Ffc::Data::DefaultConfig, qr/ffc\.json/, 'default config looks good');
    like($Ffc::Data::DbTemplate, qr/database.sql/, 'database template file looks good');
    like($Ffc::Data::DbTestdata, qr/testdata.sql/, 'testdata file looks good');

    my @themes;
    {
        opendir my $dh, $Ffc::Data::Themebasedir
            or die qq(could not open theme dir "$Ffc::Data::Themebasedir": $!);
        while ( my $file = readdir $dh ) {
            next unless $file =~ m/\A\w+\z/xms;
            push @themes, $file;
        }
    }
    
    ok( @Ffc::Data::Themes, 'themes from directory are available');
    is_deeply( \@Ffc::Data::Themes, \@themes, 'avaiable themes figured out correctly' );

    ok( keys(%Ffc::Data::Acttitles), 'custom activity titles are available');
    is_deeply( \%Ffc::Data::Acttitles, $config->{acttitles}, 'custom activity titles from config ok' );
}
