#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Mojo;
use Test::General;
use Mock::Testuser;

use Test::More tests => 61;

my $t = Test::General::test_prepare_frontend('Ffc');

{
    note('Normalen Benutzer testen');
    $t->get_ok('/logout');
    my $user = Test::General::test_get_rand_user();
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    {
        my $c = $t->get_ok('/options')->status_is(200);
        $c->content_like(qr(Einstellungen));
        $c->content_unlike(qr(Benutzerverwaltung));
    }
    $t->post_ok( '/optionsadmin',
        form => { overwriteok => 1, username => $user->{name}, active => 0 } )
      ->content_like(qr{Nur Administratoren dürfen das});
    diag('Da fehlt noch die Benutzergeschichte');
    $t->get_ok('/logout');
}

{
    note('Administrator testen');
    $t->get_ok('/logout');
    my $user  = Test::General::test_get_rand_user();
    my $admin = Mock::Testuser->new_active_admin();
    $t->post_ok( '/login',
        form => { user => $admin->{name}, pass => $admin->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    {
        my $c = $t->get_ok('/options')->status_is(200);
        $c->content_like(qr(Einstellungen));
        $c->content_like(qr(Benutzerverwaltung));
    }
    my $call = sub { 
        $t->post_ok( '/optionsadmin', form => shift );
        for my $p ( @_ ) {
            given ( ref $p ) {
                when ( 'SCALAR' ) { $t->content_like(qr{$p}) }
                when ( 'Regexp' ) { $t->content_like($p)     }
                when ( ''       ) { $t->content_like(qr{$p}) }
                when ( 'CODE'   ) { $p->($t)                 }
                default           { die q{parameter type '}.ref($p).q{' illegal: }.Dumper(\@_) }
            }
        }
        return $t;
    };
    {
        note('passwort setzen');
        my $check = sub { return Ffc::Data::Auth::check_password(Ffc::Data::Auth::get_userid($user->{name}), shift // $user->{password}) };
        my $oldpw = $user->{password};
        ok($check->(), 'old password works');
        $user->alter_password;
        my $newpw = $user->{password};
        ok(!$check->(), 'new password does not work yet before anything');
        $call->({username => $user->{name}, overwriteok => 1, active => 1, newpw1 => '', newpw2 => $newpw});
        $t->status_is(200); # Passwortändern wegen mangelnder Eingaben nicht vorgenommen
        ok(!$check->(), 'new password does not work yet (#1)');
        $call->({username => $user->{name}, overwriteok => 1, active => 1, newpw1 => $newpw, newpw2 => ''});
        $t->status_is(200); # Passwortändern wegen mangelnder Eingaben nicht vorgenommen
        ok(!$check->(), 'new password does not work yet (#2)');
        $call->({username => $user->{name}, active => 1, newpw1 => $newpw, newpw2 => $newpw});
        $t->status_is(500); # Overwrite fehlt
        ok(!$check->(), 'new password does not work yet (#3)');
        $call->({username => $user->{name}, active => 1, newpw1 => $newpw, newpw2 => $oldpw});
        $t->status_is(500); # Passworte unterscheiden sich
        ok(!$check->(), 'new password does not work yet (#4)');
        $call->({username => $user->{name}, overwriteok => 1, active => 1, newpw1 => $newpw, newpw2 => $newpw});
        ok($check->(), 'new password works now');
    }
    {
        note('aktiv setzen');
        my $check = sub {(Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'users WHERE name=? AND active=1', undef, $user->{name} ))[0] ? 1 : 0 };
        ok($check->(), 'user is active');
        for my $c ( 0, 1 ) {
            isnt( $check->(), $c, $c ? 'user is inactive' : 'user is active' );
            $call->({username => $user->{name}, active => $c});
            isnt( $check->(), $c, $c ? 'user is still inactive' : 'user is still active' );
            $call->({username => $user->{name}, active => $c, overwriteok => 1});
            is( $check->(), $c, $c ? 'user is now active' : 'user is now inactive' );
        }
        ok($check->(), 'user is active');
    }
    {
        note('admin setzen');
        my $check = sub {(Ffc::Data::dbh()->selectrow_array('SELECT COUNT(id) FROM '.$Ffc::Data::Prefix.'users WHERE name=? AND admin=1', undef, $user->{name} ))[0] ? 1 : 0 };
        ok(!$check->(), 'user is no admin');
        for my $c ( 1, 0 ) {
            isnt( $check->(), $c, $c ? 'user is no admin' : 'user is admin' );
            $call->({username => $user->{name}, admin => $c});
            isnt( $check->(), $c, $c ? 'user is still no admin' : 'user is still admin' );
            $call->({username => $user->{name}, admin => $c, overwriteok => 1});
            is( $check->(), $c, $c ? 'user is now admin' : 'user is now no admin' );
        }
        ok(!$check->(), 'user is no admin');
    }
    {
        note('benutzer erzeugen');
    }
    $t->get_ok('/logout');
}

