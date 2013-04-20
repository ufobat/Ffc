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
use Ffc::Data::Board::Views;

use Test::More tests => 2485;

my $t = Test::General::test_prepare_frontend('Ffc');

my %usertable = (
    u1 => Mock::Testuser->new_active_user(),
    u2 => Mock::Testuser->new_active_user(),
);
my %cats  = map { $_->[2] => $_->[0] } @Test::General::Categories;

my @testmatrix;

{
    my @usertable = (

        # from  to       cat(s.u.)
        [ 'u1', undef ],
        [ 'u2', undef ],
        [ 'u1', 'u2'  ],
        [ 'u2', 'u1'  ],
        [ 'u1', 'u1'  ],
        [ 'u2', 'u2'  ],
    );

    for my $cat ( undef, keys %cats ) {
        push @testmatrix, map { my @tbl = @$_; push @tbl, $cat; \@tbl } @usertable;
    }
}

for my $test ( @testmatrix ) {
    my ( $from, $to, $cat ) = @$test;
    $from = $usertable{$from};
    $to = $usertable{$to} if $to;
    my $from_name = $from->{name};
    my $from_id = Ffc::Data::Auth::get_userid($from_name);
    my $to_name = $to ? $to->{name} : $to;
    my $to_id   = $to ? Ffc::Data::Auth::get_userid($to_name) : $to;
    note(qq'testing from="$from_name", to="'.($to_name//'<undef>').'", cat="'.($cat//'<undef>').'"');
    Ffc::Data::dbh()->do('DELETE FROM '.$Ffc::Data::Prefix.'posts');
    $t->post_ok( '/login',
        form => { user => $from->{name}, pass => $from->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );

    my $is_notes = ( $to and $from eq $to )  ? 1 : 0;
    my $is_msgs  = ( $to and $from ne $to )  ? 1 : 0;
    my $is_forum = ( $is_notes or $is_msgs ) ? 0 : 1;
    my $reset = sub {
        $t->get_ok('/forum')->status_is(200)->content_like(qr(Forum));
        $t->get_ok("/category/$cat")->status_is(200) if $cat;
        $t->get_ok('/notes')->status_is(200)->content_like(qr(Notizen)) if $is_notes;
        $t->get_ok('/msgs')->status_is(200)->content_like(qr(Privatnachrichten)) if $is_msgs;
    };
    {
        note(qq(testing the insert));
        $reset->();
        my $origtext = Test::General::test_r();
        $t->post_ok( '/new' )->status_is(500)->content_like(qr(Text des Beitrages ungültig));
        $t->post_ok( '/new', form => {post => ''} )->status_is(500)->content_like(qr(Text des Beitrages ungültig));
        if ( $is_msgs ) {
            $t->post_ok( '/new', form => {post => $origtext} )->status_is(200)->content_unlike(qr($origtext));
            $t->get_ok( "/msgs/$to_name" )->status_is(200);
        }
        $t->post_ok( '/new', form => {post => $origtext} )->status_is(200)->content_like(qr($origtext));

        my $msgid = -1;
        {
            eval { $msgid = (Ffc::Data::dbh()->selectrow_array('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $origtext))[0] };
            ok(!$@, 'new message available in database');
        }
        isnt($msgid, -1, 'new message is correct in database');

        note(qq(testing an update));
        $reset->();
        $t->get_ok("/edit/$msgid");
        if ( $is_msgs ) {
            $t->status_is(500)->content_like(qr(Privatnachrichten dürfen nicht geändert werden))->content_unlike(qr(<textarea name="post" id="textinput">$origtext</textarea>));
        }
        else {
            $t->status_is(200)->content_like(qr(<textarea name="post" id="textinput">$origtext</textarea>));
        }

        note(qq(testing to delete));
        $reset->();
    }
    $t->get_ok('/logout')->status_is(200);
}
