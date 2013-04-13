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

use Test::More tests => 20;

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
        $t->post_ok( '/optionsadmin', form => shift )->status_is(200);
        for my $p ( @_ ) {
            given ( ref $p ) {
                when ( 'SCALAR' ) { $t->content_like($p) }
                when ( 'Regexp' ) { $t->content_like($p) }
                when ( 'CODE'   ) { $p->($t, $p)         }
            }
        }
        return $t;
    };
    {
        note('passwort setzen');
        my $c = $call->({}, 'blubb');
    }
    {
        note('aktiv setzen');
    }
    {
        note('admin setzen');
    }
    {
        note('benutzer erzeugen');
    }
    $t->get_ok('/logout');
}

