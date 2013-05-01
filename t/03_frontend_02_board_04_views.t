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

use Test::More tests => 997;

srand;
my $t = Test::General::test_prepare_frontend('Ffc');
$Ffc::Data::Limit = 3;

my @checks = (
    map( {
            ;
              [
                Mock::Testuser->new_active_user() => {
                    user       => "u$_",
                    forum      => 0,
                    msgs       => 0,
                    notes      => 0,
                    categories => {
                        map { $_->[2] => [ $_->[1], 0 ] }
                          [ '', 'Allgemeine Beiträge', '' ],
                        @Test::General::Categories
                    }
                }
              ]
    } 1 .. 3 ),
);

my %users = map { $_->[1]->{user} => $_->[0] } @checks;

my @testposts;
for my $us (
    [qw(u1 u2)], [qw(u1 u3)], [qw(u2 u1)], [qw(u3 u1)],
    [qw(u2 u3)], [qw(u3 u2)]
  )
{
    push @testposts, map { [ $us->[0], $us->[1], undef ] } 1 .. 5;
}
for my $u (qw(u1 u2 u3)) {
    push @testposts, map { [ $u => $u, undef ] } 1 .. 5;
}
for my $cat ( undef, map { $_->[2] } @Test::General::Categories ) {
    for my $u (qw(u1 u2 u3)) {
        push @testposts, map { [ $u => undef, $cat ] } 1 .. 5;
    }
}
unshift @$_, Test::General::test_r() for @testposts;    # text

sub insert_tests {
    for my $t (@testposts) {
        Ffc::Data::Board::Forms::insert_post( $users{ $t->[1] }->{name},
            $t->[0], $t->[3], ( $t->[2] ? $users{ $t->[2] }->{name} : undef ) );
    }
    sleep 2;
    for my $c (@checks) {
        my $u    = $users{$c->[1]->{user}}->{name};
        my $cats = Ffc::Data::Board::Views::get_categories($u);
        $c->[1]->{notes} = Ffc::Data::Board::Views::count_notes(    $u );
        $c->[1]->{msgs}  = Ffc::Data::Board::Views::count_newmsgs(  $u );
        $c->[1]->{forum} = Ffc::Data::Board::Views::count_newposts( $u );
        for my $cat ( @$cats ) {
            $c->[1]->{categories}->{$cat->[1]}->[1] = $cat->[2];
        }
    }

}

sub check_page {
    my ( $t, $u, $ck, $cat, $sleep ) = @_;
    $t->content_like(qr~<span class="username">$u->{name}</span>~);
    if ( $ck->{forum} ) {
        $t->content_like(
            qr~>Forum \(<span class="mark">$ck->{forum}</span>\)</span>~);
    }
    else {
        $t->content_like(qr~>Forum \($ck->{forum}\)</span>~);
    }
    if ( $ck->{msgs} ) {
        $t->content_like(
            qr~>Nachrichten \(<span class="mark">$ck->{msgs}</span>\)</span>~);
    }
    else {
        $t->content_like(qr~>Nachrichten \($ck->{msgs}\)</span>~);
    }
    if ( $ck->{msgs} ) {
        $t->content_like(qr~>Notizen \(<span class="notecount">$ck->{notes}</span>\)</span>~);
    }
    else {
        $t->content_like(qr~>Notizen \($ck->{notes}\)</span>~);
    }
    my $cats = $ck->{categories};
    for my $k ( sort keys %$cats ) {
        my $n = $cats->{$k}->[0];
        my $e = Mojo::Util::xml_escape($n);
        my $c = $cats->{$k}->[1];
        if ( $k eq $cat ) {
            if ($c) {
                $t->content_like(
                    qr~<span class="active">\s*$e\s+\($c\)\s*</span>~);
            }
            else {
                $t->content_like(qr~<span class="active">\s*$e\s*</span>~);
            }
        }
        else {
            if ($c) {
                $t->content_like(qr~>$e \(<span class="mark">$c</span>\)</a>~);
            }
            else {
                $t->content_like(qr~>$e</a>~);
            }
        }
    }
    $ck->{forum} -= $cats->{$cat}->[1];
    $cats->{$cat}->[1] = 0;
    sleep 2 if $sleep;
}

sub checkall_tests {
    my $sleep = shift;
    for my $ck (@checks) {
        my $u = $ck->[0];
        my $p = $ck->[1];
        $t->post_ok( '/login',
            form => { user => $u->{name}, pass => $u->{password} } )
          ->status_is(302)
          ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
        $t->get_ok('/')->status_is(200);
        check_page( $t, $u, $p, '', $sleep );
        for my $cat ( map { $_->[2] } @Test::General::Categories ) {
            $t->get_ok("/category/$cat")->status_is(200);
            check_page( $t, $u, $p, $cat, $sleep );
        }
        $t->get_ok('/logout')->status_is(200)
          ->content_like(qr'bitte melden Sie sich erneut an');
    }
}

note('empty checks');
checkall_tests(0);
sleep 2;
note('insert some test postings');
insert_tests();
sleep 2;
note('checks with test postings');
checkall_tests(1);

