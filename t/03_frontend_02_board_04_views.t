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

use Test::More tests => 1369;

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
    } 1 .. 2 ),
);

my %users = map { $_->[1]->{user} => $_->[0] } @checks;
$users{u3} = Mock::Testuser->new_inactive_user();

my @testposts;

sub generate_testcases {
    for my $us (
        [qw(u1 u2)], [qw(u1 u3)], [qw(u2 u1)], [qw(u3 u1)],
        [qw(u2 u3)], [qw(u3 u2)]
      )
    {
        push @testposts, map { [ $us->[0], $us->[1], undef, 'msgs' ] } 1 .. 5;
    }
    for my $u (qw(u1 u2 u3)) {
        push @testposts, map { [ $u => $u, undef, 'notes' ] } 1 .. 5;
    }
    for my $cat ( undef, map { $_->[2] } @Test::General::Categories ) {
        for my $u (qw(u1 u2 u3)) {
            push @testposts, map { [ $u => undef, $cat, 'forum' ] } 1 .. 5;
        }
    }
    unshift @$_, Test::General::test_r() for @testposts;    # text
}

sub insert_tests {
    generate_testcases();
    for my $t (@testposts) {
        Ffc::Data::Board::Forms::insert_post( $users{ $t->[1] }->{name},
            $t->[0], $t->[3], ( $t->[2] ? $users{ $t->[2] }->{name} : undef ) );
    }
    sleep 2;
    for my $c (@checks) {
        my $u    = $users{ $c->[1]->{user} }->{name};
        my $cats = Ffc::Data::Board::Views::get_categories($u);
        $c->[1]->{notes} = Ffc::Data::Board::Views::count_notes($u);
        $c->[1]->{msgs}  = Ffc::Data::Board::Views::count_newmsgs($u);
        $c->[1]->{forum} = Ffc::Data::Board::Views::count_newposts($u);
        for my $cat (@$cats) {
            $c->[1]->{categories}->{ $cat->[1] }->[1] = $cat->[2];
        }
    }

}

sub check_header {
    my ( $t, $u, $ck, $cat, $sleep, $act ) = @_;
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
    if ( $ck->{notes} ) {
        $t->content_like(
            qr~>Notizen \(<span class="notecount">$ck->{notes}</span>\)</span>~
        );
    }
    else {
        $t->content_like(qr~>Notizen \($ck->{notes}\)</span>~);
    }
    $ck->{$act} = 0 if $act eq 'msgs';
}

sub check_categories {
    my ( $t, $u, $ck, $cat, $sleep, $act ) = @_;
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
}

sub check_content {
    my ( $t, $u, $ck, $cat, $sleep, $act ) = @_;
    note(qq'content check for "$act"');
    my @testcases = reverse grep {
        ( defined( $_->[3] ) and defined($cat) and $_->[3] eq $cat )
          or ( !defined( $_->[3] ) and !defined($cat) )
    } grep { $act eq $_->[4] } @testposts;
    check_pages( \@testcases, $t, $u, $ck, $cat, $sleep, $act );
}

sub check_pages {
    my ( $testcases, $t, $u, $ck, $cat, $sleep, $act ) = @_;
    my @testcases =()= @$testcases;
    my $page = 0;
    while ( my @tests = splice @testcases, 0, $Ffc::Data::Limit ) {
        $page++;
        if ( $page > 1 ) {
            $t->get_ok("/$page")->status_is(200);
            $t->content_unlike(qr(<textarea name="post" id="textinput"></textarea>));
        }
        else {
            $t->content_like(qr(<textarea name="post" id="textinput"></textarea>)) unless $act eq 'msgs';
        }
        $t->content_like(qr(<span class="actpage">\[$page\]</span>));
        for my $test (@tests) {
            $t->content_like(qr(<p>$test->[0]</p>));
            #die Dumper( { tests => [ map { "$_->[4] = $_->[0]" } @tests ], all   => [ map { "$_->[4] = $_->[0]" } @testposts ] });
            note('testing buttons at posts');
            my $url_editicon = $t->app->url_for("/themes/$Ffc::Data::Theme/img/icons/edit.png");
            my $url_deleteicon = $t->app->url_for("/themes/$Ffc::Data::Theme/img/icons/delete.png");
            my $url_msgicon = $t->app->url_for("/themes/$Ffc::Data::Theme/img/icons/msg.png");
            if ( $users{$test->[1]}->{active} ) { # keine buttons an inaktiven nutzern
                my $id = (Ffc::Data::dbh()->selectrow_array('SELECT id FROM '.$Ffc::Data::Prefix.'posts WHERE textdata=?', undef, $test->[0]))[0];
                my $url_edit = $t->app->url_for('edit_form', postid => $id);
                my $url_delete = $t->app->url_for('delete_check', postid => $id );
                my $usermsgname = $test->[1] eq $u ? $users{$test->[2]}->{name} : $users{$test->[1]}->{name};
                my $url_msg = $act eq 'msgs' ? $t->app->url_for('msgs_user', msgs_username => $usermsgname) : '';
                my $editlink = qr~<a href="$url_edit" title="Beitrag bearbeiten">\s*<img src="$url_editicon" alt="Ändern"></a>~;
                my $deletelink = qr~<a href="$url_delete" title="Beitrag löschen">\s*<img src="$url_deleteicon" alt="Löschen"></a>~;
                my $msglink = qr~<a href="$url_msg" title="Dem Benutzer &quot;$usermsgname&quot; eine private Nachricht zukommen lassen">\s*<img src="$url_msgicon" alt="Nachricht"></a>~;
                my $timestamp = qr(\s*\d+\.\d+\.\d+, \d+:\d+);
                my $start = qr(<h2>\s*<span class="titleinfo">);
                my $end = qr(\s*</span>:\s*</h2>\s*<p>$test->[0]</p>);
                if ( $act eq 'notes' ) {
                    $t->content_like(qr~$start$timestamp,\s*$editlink\s*$deletelink$end~);
                }
                if ( $act eq 'msgs' ) {
                }
                if ( $act eq 'forum' ) {
                }
            }
            else {
                $t->content_like(qr~<h2>\s*<span class="inactive">$users{$test->[1]}->{name}</span>\s*<span class="titleinfo">\(\s*\d+\.\d+\.\d+, \d+:\d+\s*\)</span>:\s*</h2>\s*<p>$t->[0]</p>~);
            }
        }
    }
}

sub check_msgs {
    my ( $t, $u, $p, $cat, $sleep, $act ) = @_;
    note('check user message system and correpsonding input forms and stuff');
    my @testcases = reverse grep { $_->[4] eq 'msgs' and ( $p->{user} and ( $_->[1] and $p->{user} eq $_->[1] ) or ( $_->[2] and $p->{user} eq $_->[2] ) )} @testposts;
    my %actusers = map {($_->[1] ne $p->{user} ? ($_->[1] => 1) : ()), ($_->[2] ne $p->{user} ? ($_->[2] => 1) : ())} @testcases;
    $t->content_unlike(qr(<textarea name="post" id="textinput"></textarea>));
    for my $user ( map {$users{$_}} keys %actusers ) {
        $t->get_ok("/msgs/$user->{name}")->status_is(200);
        $t->content_like(qr(<textarea name="post" id="textinput"></textarea>));
        check_pages( \@testcases, $t, $u, $p, $cat, $sleep, $act );
    }
}

sub check_page {
    my ( $t, $u, $ck, $cat, $sleep, $act ) = @_;
    check_header( $t, $u, $ck, $cat, $sleep, $act );
    check_categories( $t, $u, $ck, $cat, $sleep, $act ) if $act eq 'forum';
    check_content( $t, $u, $ck, $cat, $sleep, $act );
    check_msgs( $t, $u, $ck, $cat, $sleep, $act ) if $act eq 'msgs';
    sleep 2 if $sleep;
}

sub check_check {
    my ( $t, $sleep, $act, $ck, $u, $p ) = @_;
    if ( $act eq 'forum' ) {
        for my $cat ( '', map { $_->[2] } @Test::General::Categories ) {
            if ($cat) {
                $t->get_ok("/category/$cat")->status_is(200);
            }
            check_page( $t, $u, $p, $cat, $sleep, $act );
            $p->{forum} -= $p->{categories}->{$cat}->[1];
            $p->{categories}->{$cat}->[1] = 0;
        }
    }
    else {
        $t->get_ok("/$act")->status_is(200);
        check_page( $t, $u, $p, '', $sleep, $act );
    }
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
        $t->get_ok('/')->status_is(200);    # der redirect nach der anmeldung
        check_check( $t, $sleep, 'forum', $ck, $u, $p );
        check_check( $t, $sleep, 'msgs',  $ck, $u, $p );
        check_check( $t, $sleep, 'notes', $ck, $u, $p );
        sleep 2 if $sleep;
        $t->get_ok('/forum')->status_is(200); # das muss ja jetzt auch noch gehen
        check_check( $t, 0, 'forum', $ck, $u, $p );
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

