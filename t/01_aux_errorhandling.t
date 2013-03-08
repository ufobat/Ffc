#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;

use MockController;

use Test::More tests => 154;

srand;
sub c  { MockController->new() }
sub r  { '>>> ' . rand(10000) . ' <<<' }
sub gs { r(), '', c(), r() }

##############################################################################
BEGIN { use_ok('AltSimpleBoard::Errors'); }
##############################################################################

##############################################################################
diag('=== prepare ===');
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
diag('=== handle_silent ===');
##############################################################################
# - etwas ausführen, aber fehler unterdrücken
# - stattdessen mit true oder false antworten, obs geklappt hat
{
    my $h = sub { &AltSimpleBoard::Errors::handle_silent };
    diag('test wrong call');
    {
        eval { $h->() };
        ok( $@, 'died due to wrong call (no controller)' );
        like(
            $@,
            qr/no controller provided as first parameter/,
            'died with correct message with wrong call'
        );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->($c) };
        ok( $@, 'died due to wrong call (no code)' );
        like(
            $@,
            qr/no code provided as second parameter/,
            'died with correct message with wrong call'
        );
    }
    {
        diag('test with good code');
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ),
            'handling code without errors, check for errors silently' );
        is( $x, $r, 'code without errors has been silently executed' );
    }
    {
        diag('test with bad code');
        my ( $r, $x, $c, $e ) = gs();
        my $ret;
        eval {
            $ret = $h->( $c, sub { die $e } );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'silent handling of error-prone code returns false' );
    }
    {
        diag('test with bad code, check for error message');
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
diag(q{=== handle ===});
##############################################################################
{
    my $h = sub { &AltSimpleBoard::Errors::handle };
    my $ra = sub {
        my $msg = shift;
        my ( $r, $x, $c, $e ) = gs();
        my $y = $x;
        my $ret;
        my $code = sub { $x = $r; die $e; $y = $r };
        eval { $ret = $h->( $c, $code, ( $msg // () ) ) };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        my $l = $c->app->log->error;
        like( $l->[0], qr{system error message: $e}, 'system error catched' );
        return $r, $x, $c, $e, $l;

    };
    diag('test wrong call');
    {
        eval { $h->() };
        ok( $@, 'died due to wrong call (no controller)' );
        like(
            $@,
            qr/no controller provided as first parameter/,
            'died with correct message with wrong call'
        );
    }
    {
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->($c) };
        ok( $@, 'died due to wrong call (no code)' );
        like(
            $@,
            qr/no code provided as second parameter/,
            'died with correct message with wrong call'
        );
    }
    {
        diag('checking good code');
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ), 'good code runs without any issues' );
        ok( !$c->{stash}->{error}, 'good code produces no errors' );
    }
    {
        diag('checking bad code without an error message without debugging');
        $AltSimpleBoard::Data::Debug = 0;
        my ( $r, $x, $c, $e, $l ) = $ra->();
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
        $AltSimpleBoard::Data::Debug = 1;
        my ( $r, $x, $c, $e, $l ) = $ra->();
        is(
            $l->[1],
            'user presented error message: ',
            'empty user error catched'
        );
        like( $c->{stash}->{error}, qr/$e/i,
            'error message in stash reseived' );
    }
    {
        diag('checking bad code with an error message and without debugging');
        $AltSimpleBoard::Data::Debug = 0;
        my $msg = r();
        my ( $r, $x, $c, $e, $l ) = $ra->($msg);
        is(
            $l->[1],
            'user presented error message: ' . $msg,
            'empty user error catched'
        );
        is( $c->{stash}->{error}, $msg, 'error message in stash reseived' );
    }
    {
        diag('checking bad code with an error message and with debugging');
        $AltSimpleBoard::Data::Debug = 1;
        my $msg = r();
        my ( $r, $x, $c, $e, $l ) = $ra->($msg);
        is(
            $l->[1],
            'user presented error message: ' . $msg,
            'empty user error catched'
        );
        like( $c->{stash}->{error}, qr/$e/i,
            'error message in stash reseived' );
    }
}

##############################################################################
diag(q{=== handling ===});
##############################################################################
{
    my $h = sub { &AltSimpleBoard::Errors::handling };
    {
        diag('wrong call, no controller');
        eval { $h->() };
        ok( $@, 'no controller kills' );
        like( $@, qr/no controller/i, 'error message ok' );
    }
    {
        diag('wrong call, no params');
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->($c) };
        ok( $@, 'no params kill' );
        like( $@, qr/params not set/i, 'error message ok' );
    }
    {
        diag('wrong call, neighter params nor code as argument');
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->( $c, [] ) };
        ok( $@, 'no params kill' );
        like( $@, qr/no hash params/i, 'error message ok' );
    }
    {
        diag('plain error message, no after_error');
        my ( $r, $x, $c, $e ) = gs();
        my $ret = 1;
        eval { $ret = $h->( $c, { plain => $e } ) };
        ok( !$@,   'no one really died, everything is fine' );
        ok( !$ret, 'but the call returned false' );
        my $l = $c->app->log->error;
        like( $l->[0], qr/system error message: $e/i, 'system error catched' );
        is(
            $l->[1],
            'user presented error message: ' . $e,
            'user error catched'
        );
        like( $c->{stash}->{error}, qr/$e/, 'error message presented correct' );
    }
    my $prepare = sub {
        my $params = shift;
        $params = { map { $_ => 1 } @$params };
        my ( $r, $x, $c, $e ) = gs();
        if ( exists $params->{msg} ) {
            $params->{msg} = $e;
        }
        else {
            $e = '';
        }
        my $checks = {};
        for my $check (qw(after_ok after_error)) {
            next unless exists $params->{$check};
            $checks->{$check} = {};
            $checks->{$check}->{expected} = my $w = r();
            $params->{$check} = sub { $checks->{$check}->{got} = $w };
        }
        return $r, $x, $c, $e, $params, $checks, '', undef;
    };
    my $ck = sub {
        my $params = shift;
        {
            diag('* good code');
            my ( $r, $x, $c, $e, $params, $checks, $y, $ret ) =
              $prepare->($params);
            $params->{code} = sub { $x = $r };
            eval { $ret = $h->( $c, $params ) };
            ok( !$@,  'no one died, everything is fine' );
            ok( $ret, 'the call returned true' );
            my $l = $c->app->log->error;
            is( scalar(@$l), 0, 'no errors reported' );
            ok( !$c->{stash}->{error}, 'no error in stash' );
            is(
                $checks->{after_ok}->{got},
                $checks->{after_ok}->{expected},
                'after_ok ran'
            ) if exists $params->{after_ok};
            isnt(
                $checks->{after_error}->{got},
                $checks->{after_error}->{expected},
                'after_error did not run'
            ) if exists $params->{after_error};
        }
        {
            diag('* bad code');
            my ( $r, $x, $c, $e, $params, $checks, $y, $ret ) =
              $prepare->($params);
            $params->{code} = sub { $x = $r; die $e; $y = $r };
            eval { $ret = $h->( $c, $params ) };
            ok( !$@,   'no one died, everything is fine' );
            ok( !$ret, 'the call returned true' );
            my $l = $c->app->log->error;
            cmp_ok( scalar(@$l), '>', 0, 'no errors reported' );
            like(
                $l->[0],
                qr/system error message: $e/i,
                'system error catched'
            );
            is(
                $l->[1],
                'user presented error message: ' . $e,
                'user error catched'
            );
            isnt(
                $checks->{after_ok}->{got},
                $checks->{after_ok}->{expected},
                'after_ok ran'
            ) if exists $params->{after_ok};
            is(
                $checks->{after_error}->{got},
                $checks->{after_error}->{expected},
                'after_error did not run'
            ) if exists $params->{after_error};
        }
    };
    diag('without anything');
    $ck->( [] );
    diag('with error message and nothing else');
    $ck->( [qw(msg)] );
    diag('with error message and just after_ok');
    $ck->( [qw(msg after_ok)] );
    diag('with error message and just after_error');
    $ck->( [qw(msg after_error)] );
    diag('with error message, after_ok and after_error');
    $ck->( [qw(msg after_ok after_error)] );
    diag('without error message and just after_ok');
    $ck->( [qw(after_ok)] );
    diag('without error message and just after_error');
    $ck->( [qw(after_error)] );
    diag('without error message, after_ok and after_error');
    $ck->( [qw(after_ok after_error)] );
}

##############################################################################
diag(q{=== or_empty    -> [] ===});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_empty };

}

##############################################################################
diag(q{=== or_nostring -> '' ===});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_nostring };

}

##############################################################################
diag(q{=== or_undef    -> undef ===});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_undef };

}

##############################################################################
diag(q{=== or_zero     -> 0 ===});
##############################################################################
{
    my $o = sub { &AltSimpleBoard::Errors::or_zero };
}

