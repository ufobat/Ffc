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

use Test::More tests => 31;

srand;

sub r { '>>> ' . rand(10000) . ' <<<' }

BEGIN { use_ok('AltSimpleBoard::Data') }

my $config = Mock::Config->new->{config};

diag('checking configuration loading');
my $app = Mojolicious->new();
ok( AltSimpleBoard::Data::set_config($app), 'config set returned true' );

{
    diag('checking database configuration');
    my $dbh = AltSimpleBoard::Data::dbh();
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
    diag('checking sensible config values');

    ok( keys( %{ $app->config } ), 'config stored in application' );

    is( AltSimpleBoard::Data::cryptsalt(),
        $config->{cryptsalt}, 'cryptsalt is ok' );

    is( $app->secret, $config->{cookiesecret}, 'secret is ok' );

    ok( !exists( $app->config()->{cookiesecret} ),
        'secret deleted from config' );
    ok( !exists( $app->config()->{cryptsalt} ), 'secret deleted from config' );

    diag('checking ordinary config values');
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
            is( ${"AltSimpleBoard::Data::$v"},
                $config->{$k},
                qq(config files "$k" matches application configs "$v") );
        }
    }

    diag('checking computed config values');
    like($AltSimpleBoard::Data::Themedir, qr/themes/, 'theme dir ok');
    like($AltSimpleBoard::Data::Themebasedir, qr/$FindBin::Bin/, 'theme base dir inside project directory');
    like($AltSimpleBoard::Data::Themedir, qr/$AltSimpleBoard::Data::Themedir/, 'theme base dir ok');
    like($AltSimpleBoard::Data::DefaultConfig, qr/$FindBin::Bin/, 'default config inside project directory');
    like($AltSimpleBoard::Data::DefaultConfig, qr/etc/, 'default config in something with "etc" in it');
    like($AltSimpleBoard::Data::DefaultConfig, qr/altsimpleboard\.json/, 'default config looks good');

    my @themes;
    {
        opendir my $dh, $AltSimpleBoard::Data::Themebasedir
            or die qq(could not open theme dir "$AltSimpleBoard::Data::Themebasedir": $!);
        while ( my $file = readdir $dh ) {
            next unless $file =~ m/\A\w+\z/xms;
            push @themes, $file;
        }
    }
    
    ok( @AltSimpleBoard::Data::Themes, 'themes from directory are available');
    is_deeply( \@AltSimpleBoard::Data::Themes, \@themes, 'avaiable themes figured out correctly' );

    ok( keys(%AltSimpleBoard::Data::Acttitles), 'custom activity titles are available');
    is_deeply( \%AltSimpleBoard::Data::Acttitles, $config->{acttitles}, 'custom activity titles from config ok' );
}
