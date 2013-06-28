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

use Test::More tests => 6221;

my $t = Test::General::test_prepare_frontend('Ffc');

my %usertable = (
    u1 => Mock::Testuser->new_active_user(),
    u2 => Mock::Testuser->new_active_user(),
    u3 => Mock::Testuser->new_active_user(),
);
my %cats = map { $_->[2] => $_->[0] } @Test::General::Categories;

my @testmatrix;

{
    my @usertable = (

        # from  to       cat(s.u.)
        [ 'u1', undef ],
        [ 'u2', undef ],
        [ 'u1', 'u2' ],
        [ 'u2', 'u1' ],
        [ 'u1', 'u1' ],
        [ 'u2', 'u2' ],
    );

    for my $cat ( undef, keys %cats ) {
        push @testmatrix,
          map { my @tbl = @$_; push @tbl, $cat; \@tbl } @usertable;
    }
}

for my $test (@testmatrix) {
    my ( $from, $to, $cat ) = @$test;
    $from = $usertable{$from};
    $to = $usertable{$to} if $to;
    my $from_name = $from->{name};
    my $from_id   = Ffc::Data::Auth::get_userid($from_name);
    my $to_name   = $to ? $to->{name} : $to;
    my $to_id     = $to ? Ffc::Data::Auth::get_userid($to_name) : $to;
    note(   qq'testing from="$from_name", to="'
          . ( $to_name // '<undef>' )
          . '", cat="'
          . ( $cat // '<undef>' )
          . '"' );
    Ffc::Data::dbh()->do( 'DELETE FROM ' . $Ffc::Data::Prefix . 'posts' );
    $t->post_ok( '/login',
        form => { user => $from->{name}, pass => $from->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );

    my $is_notes = ( $to and $from eq $to ) ? 1 : 0;
    my $is_msgs = ( $to and $from ne $to ) ? 1 : 0;
    my $is_forum = ( $is_notes or $is_msgs ) ? 0 : 1;
    my $act = 'forum'; $act = 'msgs' if $is_msgs; $act = 'notes' if $is_notes;
    $act .= "/category/$cat" if $act eq 'forum' and $cat;
    my $reset = sub {
        $t->get_ok('/forum')->status_is(200)->content_like(qr(Forum));
        $t->get_ok("/forum/category/$cat")->status_is(200) if $cat;
        $t->get_ok('/notes')->status_is(200)->content_like(qr(Notizen))
          if $is_notes;
        $t->get_ok('/msgs')->status_is(200)->content_like(qr(Privatnachrichten))
          if $is_msgs;
    };
    {
        note(qq(testing the insert));
        $reset->();
        my $origtext = Test::General::test_r();
        $t->post_ok("/$act/new")->status_is(500)
          ->content_like(qr(Text des Beitrages ungültig));
        $t->post_ok( "/$act/new", form => { post => '' } )->status_is(500)
          ->content_like(qr(Text des Beitrages ungültig));
        if ($is_msgs) {
            $t->post_ok( "/msgs/user/$to_name/new", form => { post => $origtext } );
            $t->status_is(302)
             ->header_like( Location => qr{\Ahttps?://localhost:\d+}xms );
            $t->get_ok("/msgs/user/$to_name");
            $t->status_is(200)->content_like(qr($origtext));
            $t->get_ok("/msgs/user/$to_name")->status_is(200);
        }
        $t->post_ok( "/$act/new", form => { post => $origtext } );
        $t->status_is(302)
          ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
        $t->get_ok("/$act")->status_is(200)->content_like(qr($origtext))->content_like(qr'Beitrag wurde erstellt');

        my $msgid = -1;
        {
            eval {
                $msgid = (
                    Ffc::Data::dbh()->selectrow_array(
                        'SELECT id FROM '
                          . $Ffc::Data::Prefix
                          . 'posts WHERE textdata=?'
                          . ( ($act =~ m{\A/forum}xms and $cat) ? ' AND category=?' : ''),
                        undef,
                        $origtext,
                        ( ($act =~ m{\A/forum}xms and $cat) ? $cats{$cat} : () ),
                    )
                )[0];
            };
            ok( !$@, 'new message available in database' );
        }
        isnt( $msgid, -1, 'new message is correct in database' );

        note(qq(testing an update));
        $reset->();
        $t->get_ok("/$act/edit/$msgid");
        if ($is_msgs) {
            $t->status_is(500)
              ->content_like(
                qr(Privatnachrichten dürfen nicht geändert werden))
              ->content_unlike(
                qr~<textarea\s+name="post"\s+id="textinput"\s+class="(?:insert|update)_post"\s*>$origtext</textarea>~s);
        }
        else {
            $t->status_is(200)
              ->content_like(
                qr~<textarea\s+name="post"\s+id="textinput"\s+class="(?:insert|update)_post"\s*>$origtext</textarea>~s);
        }
        my $newtext = $origtext;
        $newtext = Test::General::test_r() while $newtext eq $origtext;
        $t->post_ok( "/$act/edit/$msgid", form => { post => $newtext } );
        if ($is_msgs) {
            $t->status_is(500)->content_unlike(qr(Beitrag wurde geändert))
              ->content_like(
                qr(Privatnachrichten dürfen nicht geändert werden));
            is(
                (
                    Ffc::Data::dbh()->selectrow_array(
                        'SELECT textdata FROM '
                          . $Ffc::Data::Prefix
                          . 'posts WHERE id=?',
                        undef,
                        $msgid,
                    )
                )[0],
                $origtext,
                'textdate has not been changed'
            );
        }
        else {
            $t->status_is(302)
             ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
            $t->get_ok("/$act");
            $t->status_is(200)->content_like(qr(Beitrag wurde geändert));
            is(
                (
                    Ffc::Data::dbh()->selectrow_array(
                        'SELECT textdata FROM '
                          . $Ffc::Data::Prefix
                          . 'posts WHERE id=?'
                          . ( ($act =~ m{\A/forum}xms and $cat) ? ' AND category=?' : ''),
                        undef,
                        $msgid,
                        ( ($act =~ m{\A/forum}xms and $cat) ? $cats{$cat} : () ),
                    )
                )[0],
                $newtext,
                'textdate has been changed'
            );
        }

        {
            $t->get_ok('/logout')->status_is(200);
            my $u3 = $usertable{u3};
            my $newtext = do { $is_msgs ? $origtext : $newtext };
            $t->post_ok( '/login',
                form => { user => $u3->{name}, pass => $u3->{password} } )
              ->status_is(302)
              ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
            note(qq(testing update from different user as failure));
            $reset->();
            my $newtext2 = $newtext;
            $newtext2 = Test::General::test_r() while $newtext eq $newtext2;
            $t->get_ok("/$act/edit/$msgid");
            if ($is_msgs) {
                $t->status_is(500)
                  ->content_like(
                    qr(Privatnachrichten dürfen nicht geändert werden));
            }
            else {
                $t->status_is(200)
                  ->content_like(
qr~<textarea\s+name="post"\s+id="textinput"\s+class="(?:insert|update)_post"\s*></textarea>~s
                  );
            }
            $t->post_ok("/$act/edit/$msgid", form => {post => $newtext2});
            if ($is_msgs) {
                $t->status_is(500)
                ->content_like(
                    qr(Privatnachrichten dürfen nicht geändert werden));
            }
            else {
                $t->status_is(302)
                  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
                $t->get_ok("/$act");
                $t->status_is(200)
                  ->content_like(
qr~<textarea\s+name="post"\s+id="textinput"\s+class="(?:insert|update)_post"\s*></textarea>~s
                  );
            }
            {
                my $posts = Ffc::Data::dbh()->selectall_arrayref('SELECT textdata FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $msgid);
                is( $posts->[0]->[0], $newtext, 'post is original');
                isnt( $posts->[0]->[0], $newtext2, 'post is unchanged');
            }
            note(qq(testing to delete from different user as failure));
            $t->get_ok("/$act/delete/$msgid");
            if ($is_msgs) {
                $t->status_is(500)
                ->content_like(
                    qr(Privatnachrichten dürfen nicht gelöscht werden));
            }
            else {
                $t->status_is(500)
                  ->content_like(qr(Kein Datensatz gefunden));
            }
            {
                my $posts = Ffc::Data::dbh()->selectall_arrayref('SELECT textdata FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $msgid);
                ok( @$posts, 'post still exists');
                is( $posts->[0]->[0], $newtext, 'post is original');
            }
            $reset->();
        }

        {

            note(qq(testing to delete));
            $t->get_ok('/logout')->status_is(200);
            $t->post_ok( '/login',
                form => { user => $from->{name}, pass => $from->{password} } )
              ->status_is(302)
              ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
            $reset->();
            $t->get_ok("/$act/delete/$msgid");
            if ($is_msgs) {
                $t->status_is(500)
                ->content_like(
                    qr(Privatnachrichten d.+rfen nicht gel.+scht werden));
            }
            else {
                $t->status_is(200)
                  ->content_like(
                    qr(Den oben angezeigten Beitrag wirklich l.+schen));
            }
            $t->post_ok("/$act/delete")->status_is(500);
            if ($is_msgs) {
                $t->content_like( qr(Privatnachrichten d.+rfen nicht gel.+scht werden));
            }
            else {
                $t->content_like(qr(Keine Postid angegeben|Beitrag konnte nicht gel.+scht werden));
            }
            $t->post_ok("/$act/delete", form => {postid => $msgid});
            if ($is_msgs) {
                $t->status_is(500)
                ->content_like(
                    qr(Privatnachrichten d.+rfen nicht gel.+scht werden));
            }
            else {
                $t->status_is(302)
                  ->header_like( Location => qr{\Ahttps?://localhost:\d+/}xms );
                $t->get_ok("/$act");
                $t->status_is(200)
                  ->content_like(
                    qr(Beitrag wurde gelöscht));
            }
            my $posts = Ffc::Data::dbh()->selectall_arrayref('SELECT textdata FROM '.$Ffc::Data::Prefix.'posts WHERE id=?', undef, $msgid);
            if ($is_msgs) {
                ok( @$posts, 'post still exists');
                is( $posts->[0]->[0], $origtext, 'post is original');
            }
            else {
                ok( !@$posts, 'post is gone');
            }
        }
    }
    $t->get_ok('/logout')->status_is(200);
}
