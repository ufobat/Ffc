#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;

use Mock::Controller;

use Test::More tests => 319;

srand;
sub c  { Mock::Controller->new() }
sub r  { '>>> ' . rand(10000) . ' <<<' }
sub gs { r(), '', c(), r() }

##############################################################################
BEGIN { use_ok('Ffc::Errors'); }
##############################################################################

##############################################################################
note('=== error ===');
##############################################################################
# - info string erzeugen
{
    my $icode = \&Ffc::Errors::error_stash;
    my ( $r, $x, $c, $e ) = gs();
    my $f = $c->{stash};
    ok(!$f->{error}, 'no error available yet');
    $icode->($c, $r);
    ok($f->{error}, 'error available');
    like($f->{error}, qr($r), 'error looks good #1');
    unlike($f->{error}, qr($e), 'error looks good #2');
    $icode->($c, $e);
    like($f->{error}, qr($r), 'error looks good #3');
    like($f->{error}, qr($e), 'error looks good #4');
}

##############################################################################
note('=== info ===');
##############################################################################
# - info string erzeugen
{
    my $icode = \&Ffc::Errors::info;
    my ( $r, $x, $c, $e ) = gs();
    my $f = $c->{flash};
    ok(!$f->{info}, 'no info available yet');
    $icode->($c, $r);
    ok($f->{info}, 'info available');
    like($f->{info}, qr($r), 'info looks good #1');
    unlike($f->{info}, qr($e), 'info looks good #2');
    $icode->($c, $e);
    like($f->{info}, qr($r), 'info looks good #3');
    like($f->{info}, qr($e), 'info looks good #4');
}

##############################################################################
note('=== info_stash ===');
##############################################################################
# - info string erzeugen
{
    my $icode = \&Ffc::Errors::info_stash;
    my ( $r, $x, $c, $e ) = gs();
    my $s = $c->{stash};
    ok(!$s->{info}, 'no info available yet');
    $icode->($c, $r);
    ok($s->{info}, 'info available');
    like($s->{info}, qr($r), 'info looks good #1');
    unlike($s->{info}, qr($e), 'info looks good #2');
    $icode->($c, $e);
    like($s->{info}, qr($r), 'info looks good #3');
    like($s->{info}, qr($e), 'info looks good #4');
}

##############################################################################
note('=== handle_silent ===');
##############################################################################
# - etwas ausführen, aber fehler unterdrücken
# - stattdessen mit true oder false antworten, obs geklappt hat
{
    my $h = sub { &Ffc::Errors::handle_silent };
    note('test wrong call');
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
        note('test with good code');
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ),
            'handling code without errors, check for errors silently' );
        is( $x, $r, 'code without errors has been silently executed' );
    }
    {
        note('test with bad code');
        my ( $r, $x, $c, $e ) = gs();
        my $ret;
        eval {
            $ret = $h->( $c, sub { die $e } );
        };
        ok( !$@,   'bad code died, death was unnoticed from the outside' );
        ok( !$ret, 'silent handling of error-prone code returns false' );
    }
    {
        note('test with bad code, check for error message');
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
note(q{=== handle ===});
##############################################################################
{
    my $h = sub { &Ffc::Errors::handle };
    my $ra = sub {
        my $msg = shift;
        my ( $r, $x, $c, $e ) = gs();
        my $l = $c->app->log->error;
        my $y = $x;
        my $ret;
        my $code = sub { $x = $r; die $e; $y = $r };
        eval { $ret = $h->( $c, $code, ( $msg // () ) ) };
        if ($Ffc::Data::Debug) {
            ok( $@, 'bad code died in debug mode' );
            like( $@, qr/$e/, 'error message ok in debug mode' );
            ok( !@$l,                  'log is empty' );
            ok( !$c->{stash}->{error}, 'stash error empty' );
        }
        else {
            ok( !$@, 'bad code died, death was unnoticed from the outside' );
            like(
                $l->[0],
                qr{system error message: $e},
                'system error catched'
            );
            if ($msg) {
                is(
                    $l->[1],
                    'user presented error message: ' . $msg,
                    'empty user error catched'
                );
                like( $c->{stash}->{error},
                    qr($msg), 'error message in stash received' );
            }
            else {
                is(
                    $l->[1],
                    'user presented error message: ',
                    'empty user error catched'
                );
                like( $c->{stash}->{error},
                    qr/$e/i, 'error message in stash received' );
            }
        }
        ok( !$ret, 'bad code returns false' );
        is( $x, $r, 'errorprone code has been run, even if it died' );
        isnt( $y, $r, 'errorprone code has been run, but died ok' );
        return $r, $x, $c, $e, $l;

    };
    note('test wrong call');
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
        note('checking good code');
        my ( $r, $x, $c, $e ) = gs();
        isnt( $x, $r, 'check before running the code' );
        ok( $h->( $c, sub { $x = $r } ), 'good code runs without any issues' );
        ok( !$c->{stash}->{error}, 'good code produces no errors' );
    }
    {
        note('checking bad code without an error message without debugging');
        $Ffc::Data::Debug = 0;
        my ( $r, $x, $c, $e, $l ) = $ra->();
    }
    {
        note('checking bad code without an error message with debugging');
        $Ffc::Data::Debug = 1;
        my ( $r, $x, $c, $e, $l ) = $ra->();
    }
    {
        note('checking bad code with an error message and without debugging');
        $Ffc::Data::Debug = 0;
        my $msg = r();
        my ( $r, $x, $c, $e, $l ) = $ra->($msg);
    }
    {
        note('checking bad code with an error message and with debugging');
        $Ffc::Data::Debug = 1;
        my $msg = r();
        my ( $r, $x, $c, $e, $l ) = $ra->($msg);
    }
}

##############################################################################
note(q{=== handling ===});
##############################################################################
{
    $Ffc::Data::Debug = 0;
    my $h = sub { &Ffc::Errors::handling };
    {
        note('wrong call, no controller');
        eval { $h->() };
        ok( $@, 'no controller kills' );
        like( $@, qr/no controller/i, 'error message ok' );
    }
    {
        note('wrong call, no params');
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->($c) };
        ok( $@, 'no params kill' );
        like( $@, qr/params not set/i, 'error message ok' );
    }
    {
        note('wrong call, neighter params nor code as argument');
        my ( $r, $x, $c, $e ) = gs();
        eval { $h->( $c, [] ) };
        ok( $@, 'no params kill' );
        like( $@, qr/no hash params/i, 'error message ok' );
    }
    {
        note('plain error message, no after_error');
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
    my $ck = sub {
        my $params  = shift;
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
        {
            note('* good code');
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
            note('* bad code');
            my ( $r, $x, $c, $e, $params, $checks, $y, $ret ) =
              $prepare->($params);
            my $l = $c->app->log->error;
            $params->{code} = sub { $x = $r; die $e; $y = $r };
            eval { $ret = $h->( $c, $params ) };
            ok( !$ret, 'the call did not return' );
            is( $x, $r, 'errorprone code has been run, even if it died' );
            isnt( $y, $r, 'errorprone code has been run, but died ok' );
            isnt(
                $checks->{after_ok}->{got},
                $checks->{after_ok}->{expected},
                'after_ok did not run'
            ) if exists $params->{after_ok};

            if ($Ffc::Data::Debug) {
                ok( $@,   'we died in debug mode' );
                ok( !@$l, 'log is empty, as expected' );
                isnt(
                    $checks->{after_error}->{got},
                    $checks->{after_error}->{expected},
                    'after_error did not run'
                ) if exists $params->{after_error};
            }
            else {
                ok( !$@, 'no one died, everything is fine' );
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
                is(
                    $checks->{after_error}->{got},
                    $checks->{after_error}->{expected},
                    'after_error ran, as expected'
                ) if exists $params->{after_error};
            }
        }
    };
    $Ffc::Data::Debug = 0;
    note('without anything, no debug');
    $ck->( [] );
    note('with error message and nothing else, no debug');
    $ck->( [qw(msg)] );
    note('with error message and just after_ok, no debug');
    $ck->( [qw(msg after_ok)] );
    note('with error message and just after_error, no debug');
    $ck->( [qw(msg after_error)] );
    note('with error message, after_ok and after_error, no debug');
    $ck->( [qw(msg after_ok after_error)] );
    note('without error message and just after_ok, no debug');
    $ck->( [qw(after_ok)] );
    note('without error message and just after_error, no debug');
    $ck->( [qw(after_error)] );
    note('without error message, after_ok and after_error, no debug');
    $ck->( [qw(after_ok after_error)] );
    $Ffc::Data::Debug = 1;
    note('without anything, with debug');
    $ck->( [] );
    note('with error message and nothing else, with debug');
    $ck->( [qw(msg)] );
    note('with error message and just after_ok, with debug');
    $ck->( [qw(msg after_ok)] );
    note('with error message and just after_error, with debug');
    $ck->( [qw(msg after_error)] );
    note('with error message, after_ok and after_error, with debug');
    $ck->( [qw(msg after_ok after_error)] );
    note('without error message and just after_ok, with debug');
    $ck->( [qw(after_ok)] );
    note('without error message and just after_error, with debug');
    $ck->( [qw(after_error)] );
    note('without error message, after_ok and after_error, with debug');
    $ck->( [qw(after_ok after_error)] );
}

##############################################################################
note(q{=== run code, return something special at errors, don't die ===});
##############################################################################
{
    my $ck = sub {
        my $code = shift;
        my $st   = shift;
        my $nt   = shift;
        {
            note('* good code');
            my $c = c();
            my $ret;
            eval {
                $ret = $code->( $c, sub { return $st } );
            };
            ok( !$@,  'no one died, everything is fine' );
            ok( $ret, 'the call returned something' );
            my $l = $c->app->log->error;
            is( scalar(@$l), 0, 'no errors reported' );
            ok( !$c->{stash}->{error}, 'no error in stash' );
            is_deeply( $ret, $st, 'the returned value is ok' );
        }
        {
            note('* bad code');
            my ( $r, $x, $c, $e ) = gs();
            my $ret;
            my $y = '';
            eval {
                $ret =
                  $code->( $c, sub { $x = $r; die $e; $y = $r; return $st } );
            };
            ok( !$@, 'no one died, everything is fine' );
            my $l = $c->app->log->error;
            ok( !$c->{stash}->{error}, 'no error in stash' );
            ok( scalar(@$l),           'errors reported' );
            like( $l->[0], qr/$e/, 'correct errors reported' );
            is( $x, $r, 'errorprone code has been run, even if it died' );
            isnt( $y, $r, 'errorprone code has been run, but died ok' );
            is_deeply( $ret, $nt,
                'the call returned the expected default thingy' );
        }
    };
##############################################################################
    note(q{or_empty -> []});
##############################################################################
    {
        my $o = sub { &Ffc::Errors::or_empty };
        $ck->( $o, [ ( r() ) x rand(50) ], [] );
    }

##############################################################################
    note(q{or_nostring -> ''});
##############################################################################
    {
        my $o = sub { &Ffc::Errors::or_nostring };
        $ck->( $o, r(), '' );
    }

##############################################################################
    note(q{or_undef -> undef});
##############################################################################
    {
        my $o = sub { &Ffc::Errors::or_undef };
        $ck->( $o, r(), undef );
    }

##############################################################################
    note(q{or_zero -> 0});
##############################################################################
    {
        my $o = sub { &Ffc::Errors::or_zero };
        $ck->( $o, r(), 0 );
    }
}

