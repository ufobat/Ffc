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
use Ffc::Data::Board::Views;

use Test::More tests => 665;

my $t = Test::General::test_prepare_frontend('Ffc');

my @checks = (
    map( {
            ;
              [
                Mock::Testuser->new_active_user() => {
                    forum => 0,
                    msgs  => 0,
                    notes => 0,
                    categories =>
                      { map { $_->[2] => [ $_->[1], 0 ] } ['', 'Allgemeine Beiträge', ''], @Test::General::Categories }
                }
              ]
    } 0 .. 3 ),
);

sub check_page {
    my ( $t, $u, $ck, $cat ) = @_;
    $t->content_like(qr~<span class="username">$u->{name}</span>~);
    $t->content_like(qr~>Forum \($ck->{forum}\)</span>~);
    $t->content_like(qr~>Nachrichten \($ck->{msgs}\)</span>~);
    $t->content_like(qr~>Notizen \($ck->{notes}\)</span>~);
    my $cats = $ck->{categories};
    for my $k ( sort keys %$cats ) {
        my $n = $cats->{$k}->[0];
        my $e = Mojo::Util::xml_escape($n);
        my $c = $cats->{$k}->[1];
        if ( $k eq $cat ) {
            $t->content_like(qr~<span class="active">\s*$e\s*</span>~);
        }
        else {
            if ( $c ) {
                $t->content_like(qr~>$e \($c\)</a>~);
            }
            else {
                $t->content_like(qr~>$e</a>~);
            }
        }
    }
}

sub checkall_tests {
    for my $ck ( @checks ) {
        my $u = $ck->[0];
        my $p = $ck->[1];
        $t->post_ok( '/login',
            form => { user => $u->{name}, pass => $u->{password} } )
          ->status_is(302)
          ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
        $t->get_ok('/')->status_is(200);
        check_page( $t, $u, $p, '' );
        for my $cat ( map { $_->[2] } @Test::General::Categories ) {
            $t->get_ok("/category/$cat")->status_is(200);
            $p->{categories}->{$cat}->[1] = 0;
            check_page($t, $u, $p, $cat);
        }
        $t->get_ok('/logout')->status_is(200)->content_like(qr'bitte melden Sie sich erneut an');
    }
}

note('empty checks');
checkall_tests();
note('insert some test postings');
note('checks with test postings');

