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

use Test::More tests => 202;

my $t_notloggedin = sub {
    my $t = shift;
    $t->get_ok('/')->status_is(200)->content_like(qr{Bitte melden Sie sich an});
    $t->get_ok('/msgs')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->get_ok('/notes')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->get_ok('/options')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/options/email_save')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/options/password_save')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/options/theme_save')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/options/showimages_save')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/options/admin_save')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/search')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/forum/category/aaa')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->get_ok('/forum/delete/123')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/forum/delete')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/forum/new')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->get_ok('/forum/edit/123')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
    $t->post_ok('/forum/edit/123')->status_is(200)
      ->content_like(qr{Bitte melden Sie sich an});
};

my $t = Test::General::test_prepare_frontend('Ffc');
{
    note('test without login');
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
    $t_notloggedin->($t);
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
}
my $user = Test::General::test_get_rand_user();
{
    note('test login');
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    note('test with login');
    $t->get_ok('/')->status_is(200)
      ->content_like(qr{Keine Daten für die Anzeige vorhanden});
    $t->get_ok('/msgs')->status_is(200)
      ->content_like(qr{Keine Daten für die Anzeige vorhanden});
    $t->get_ok('/notes')->status_is(200)
      ->content_like(qr{Keine Daten für die Anzeige vorhanden});
    $t->get_ok('/options')->status_is(200)->content_like(qr{Einstellungen});
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
}
{
    note('test logout');
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
    $t_notloggedin->($t);
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
}

{
    note('test settings alternation');
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
    my $set_settings = sub {
        my $u = shift;
        Ffc::Data::dbh()->do('UPDATE '.$Ffc::Data::Prefix
            .'users SET show_images=?, theme=?, bgcolor=?, fontsize=?'
            .' WHERE LOWER(name)=LOWER(?)',
            undef,
            (
                $u->{show_images} = 3 + int rand 10,
                $u->{theme}       = Test::General::test_r(),
                $u->{bgcolor}     = Test::General::test_r(),
                $u->{fontsize}    = 3 + int rand 10,
            ),
            $u->{name});
        return 1;
    };
    my $check_settings = sub {
        my $u = shift;
        $t->get_ok('/session')
          ->json_is('/theme',      $u->{theme}     )
          ->json_is('/bgcolor',    $u->{bgcolor}   )
          ->json_is('/fontsize',   $u->{fontsize}  )
          ->json_is('/show_image', $u->{show_image})
          ->json_is('/admin',      $u->{admin}     )
        ;
    };

    $set_settings->($user);
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    $check_settings->($user);
    $set_settings->($user);
    $check_settings->($user);
}
        
{
    note('test login with wrong password');
    $t->get_ok('/logout')->status_is(200)
       ->content_like(qr{melden Sie sich});
    $user->alter_password;
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(500)
      ->content_like(
        qr'Benutzer oder Passwort passen nicht oder der Benutzer ist inaktiv');
    $t_notloggedin->($t);
}

