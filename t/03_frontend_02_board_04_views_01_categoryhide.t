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
use Mojo::Util;
use Mock::Testuser;
use Ffc::Data;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Forms;
use Ffc::Data::Board::OptionsUser;

use Test::More tests => 39;

srand;
my $t = Test::General::test_prepare_frontend('Ffc');

{
    {
        note 'category hide tests';
        my $user = Mock::Testuser->new_active_user();
        my %cats = map { $_->[1] => $_->[4] } grep { $_->[1] } @{ Ffc::Data::Board::Views::get_all_categories( $user->{name} ) };
        $t->post_ok( '/login',
                form => { user => $user->{name}, pass => $user->{password} } )
              ->status_is(302)
              ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
        $t->get_ok('/forum')->status_is(200);
        $t->content_like(qr(/forum/category/$_)) for keys %cats;
        for my $c ( ( keys %cats )[0..4] ) {
            Ffc::Data::Board::OptionsUser::update_show_category( $user->{name}, $c, 0 );
            $cats{$c} = 0;
        }
        $t->get_ok('/forum')->status_is(200);
        $cats{$_}
          ? $t->content_like(qr"/forum/category/$_")
          : $t->content_unlike(qr"/forum/category/$_")
            for keys %cats;
        $t->get_ok('/logout')->status_is(200)
          ->content_like(qr'bitte melden Sie sich erneut an');
    }

    {
        note 'check for empty category list display';
        my $user = Mock::Testuser->new_active_user();
        Ffc::Data::dbh()->do('DELETE FROM '.$Ffc::Data::Prefix.'categories');
        is $#{ Ffc::Data::Board::Views::get_all_categories( $user->{name} ) }, 0, 'no categories available (except "Allgemein")';
        $t->post_ok( '/login',
                form => { user => $user->{name}, pass => $user->{password} } )
              ->status_is(302)
              ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
        $t->get_ok('/forum')->status_is(200);
        $t->content_unlike(qr(<div\s+class="postbox\s+categorylinks">));
        $t->get_ok('/logout')->status_is(200)
          ->content_like(qr'bitte melden Sie sich erneut an');
    }
}
