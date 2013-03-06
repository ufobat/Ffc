#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More tests => 47;

srand;

##############################################################################
package MockController;
##############################################################################
use strict;
use warnings;
use utf8;
use 5.010;

sub new {
    bless { session => {}, stash => {}, app => MockController::App->new() },
      shift;
}
sub session { shift->{session} }
sub app     { shift->{app} }

sub stash {
    my $stash = shift->{stash};
    my $key   = shift;
    my $value = shift;
    if ( $key and not defined $value ) {
        $stash->{$key} = undef unless exists $stash->{$key};
        return $stash->{$key};

    }
    return $stash->{$key} = $value if $key and $value;
    return;
}

##############################################################################
package MockController::App;
##############################################################################
use strict;
use warnings;
use utf8;
use 5.010;

sub new { bless { log => MockController::Log->new() }, shift }
sub log { shift->{log} }

##############################################################################
package MockController::Log;
##############################################################################
use strict;
use warnings;
use utf8;
use 5.010;

sub new { bless { error => [] }, shift }

sub error {
    my $l = shift;
    my $m = shift;
    push @{ $l->{error} }, $m if $m;
    return $l->{error};
}

##############################################################################
package main;
##############################################################################
use strict;
use warnings;
use utf8;
use 5.010;
use Data::Dumper;

sub c  { MockController->new() }
sub r  { '>>> ' . rand(10000) . ' <<<<' }
sub gs { r(), '', c(), r() }

##############################################################################
BEGIN { use_ok('AltSimpleBoard::Errors'); }
##############################################################################

##############################################################################
diag('prepare');
##############################################################################
# - stash für fehlerbehandlung vorbereiten
# - sollte mittlerweile automatisch passieren
{
    my $p = sub { &AltSimpleBoard::Errors::prepare };
    {
        eval { $p->() };
        ok( $@, 'dies when prepared without controller' );
        like(
            $@,
            qr/no mojolicious controller given/,
            'barks correctly, when prepared without controller'
        );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        $p->($c);
        ok( exists( $c->{stash}->{error} ), 'error-stash-variable created' );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        $p->( $c, $r );
        is( $c->{stash}->{error},
            $r, 'error-stash-variable createt with message as expected' );
        $p->( $c, $r );
        is( $c->{stash}->{error},
            $r, 'error-stash-variable createt after it allready exsisted' );
    }
}

##############################################################################
diag('handle_silent');
##############################################################################
# - etwas ausführen, aber fehler unterdrücken
# - stattdessen mit true oder false antworten, obs geklappt hat
{
    my $h = sub { &AltSimpleBoard::Errors::handle_silent };
    {
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ),
            'handling code without errors, check for errors silently' );
        is( $x, $r, 'code without errors has been silently executed' );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        my $ret;
        eval {
            $ret = $h->( $c, sub { die $e} );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'silent handling of error-prone code returns false' );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        isnt( $x, $r, 'check before running the code' );
        my $ret;
        eval {
            $ret = $h->( $c, sub { $x = $r; die $e; $y = $r } );
        };
        ok( !$@, 'bad code died, death was unnoticed from the outside' );
        ok( !$ret,
            'silent handling of error-prone code (run test) returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
    }
}

##############################################################################
diag(q{handle});
##############################################################################
{
    my $h = sub { &AltSimpleBoard::Errors::handle };
    {
        diag('checking good code');
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ), 'good code runs without any issues' );
        ok( !$c->{stash}->{error}, 'good code produces no errors' );
    }
    {
        diag('checking bad code without an error message without debugging');
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        my $ret;
        $AltSimpleBoard::Data::Debug = 0; 
        eval {
            $ret = $h->( $c, sub { $x = $r; die $e; $y = $r } );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        my $l = $c->app->log->error;
        like(
            $l->[0],
            qr{system error message: $e},
            'system error catched'
        );
        is(
            $l->[1],
            'user presented error message: ',
            'empty user error catched'
        );
        like( $c->{stash}->{error},
            qr/Fehler/i, 'error message in stash reseived' );
    }
    {
        diag('checking bad code without an error message with debugging');
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        my $ret;
        $AltSimpleBoard::Data::Debug = 1; 
        eval {
            $ret = $h->( $c, sub { $x = $r; die $e; $y = $r } );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        my $l = $c->app->log->error;
        like(
            $l->[0],
            qr{system error message: $e},
            'system error catched'
        );
        is(
            $l->[1],
            'user presented error message: ',
            'empty user error catched'
        );
        like( $c->{stash}->{error}, qr/$e/i, 'error message in stash reseived' );
    }
    {
        diag('checking bad code with an error message and without debugging');
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        my $msg = r();
        my $ret;
        $AltSimpleBoard::Data::Debug = 0; 
        eval {
            $ret = $h->( $c, sub { $x = $r; die $e; $y = $r }, $msg );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        my $l = $c->app->log->error;
        like(
            $l->[0],
            qr{system error message: $e}i,
            'system error catched'
        );
        is(
            $l->[1],
            'user presented error message: '.$msg,
            'empty user error catched'
        );
        is( $c->{stash}->{error}, $msg, 'error message in stash reseived' );
    }
    {
        diag('checking bad code with an error message and with debugging');
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        my $msg = r();
        my $ret;
        $AltSimpleBoard::Data::Debug = 1; 
        eval {
            $ret = $h->( $c, sub { $x = $r; die $e; $y = $r }, $msg );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        my $l = $c->app->log->error;
        like(
            $l->[0],
            qr{system error message: $e}i,
            'system error catched'
        );
        is(
            $l->[1],
            'user presented error message: '.$msg,
            'empty user error catched'
        );
        like( $c->{stash}->{error}, qr/$e/i, 'error message in stash reseived' );
    }
}

##############################################################################
diag(q{handling});
##############################################################################
{
    my $h = sub { &AltSimpleBoard::Errors::handling };
}

##############################################################################
diag(q{or_empty    -> []});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_empty };

}

##############################################################################
diag(q{or_nostring -> ''});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_nostring };

}

##############################################################################
diag(q{or_undef    -> undef});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_undef };

}

##############################################################################
diag(q{or_zero     -> 0});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_zero };
}

