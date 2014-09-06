use strict;
use warnings;
use utf8;
use 5.010;

use Testinit;
use Test::Mojo;
use Data::Dumper;

our $Postlimit = 3;
our $Urlpref = '/';
our $Check_env = sub { die 'not implemented' };

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my @entries;

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );

sub logina { Testinit::test_login( $t, $admin, $apass ) }
sub login1 { Testinit::test_login( $t, $user1, $pass1 ) }
sub login2 { Testinit::test_login( $t, $user2, $pass2 ) }

sub info    { Testinit::test_info(    $t, @_ ) }
sub error   { Testinit::test_error(   $t, @_ ) }
sub warning { Testinit::test_warning( $t, @_ ) }

sub set_postlimit {
    logina();
    $t->post_ok('/options/admin/boardsettings/postlimit',
        form => { optionvalue => $Postlimit })
      ->status_is(200);
    info('Beitragsanzahl geändert');
}

sub ck { $Check_env->($t, \@entries) }

sub run_tests {
    ( $Urlpref, $Check_env ) = @_;
    set_postlimit($t);

    ck();

    $t->post_ok("$Urlpref/new", form => {})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');

    login1();
    map { insert_text() } 1 .. $Postlimit * 2 + 1;
    ck();
}

sub insert_text {
    my ( $user ) = @_;
    my $str = Testinit::test_randstring();
    $t->post_ok("$Urlpref/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~http://localhost:\d+$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200)->content_like(qr~$str~);
    unshift @entries, my $entry = [$#entries + 2, $str, $user // $user1];
    return $entry;
}

# prüft alle einträge, ob sie in der richtigen seite auftauchen
sub check_pages {
    login1();
    if ( @entries ) {
        my $pages = @entries / $main::Postlimit;
        $pages = 1 + int $pages if int($pages) != abs($pages);
        $t->get_ok($Urlpref)->status_is(200);
        for my $e ( @entries[0 .. $main::Postlimit - 1] ) {
            next unless $e;
            $t->content_like(qr/$e->[1]/);
        }
        for my $page ( 1 .. $pages ) {
            my $offset = ( $page - 1 ) * $main::Postlimit;
            my $limit = $offset + $main::Postlimit - 1;

            $t->get_ok( "$Urlpref/$page" )->status_is(200);
            
            if ( $page > 1 ) {
                $t->content_like(qr~href="$Urlpref"~);
            }
            if ( $limit <= $#entries ) {
                my $str = "$Urlpref/" . ($page + 1);
                $t->content_like(qr~href="$str"~);
            }
            if ( $page > 2 ) {
                my $str = "$Urlpref/" . ($page - 1);
                $t->content_like(qr~href="$str"~);
            }
            
            for my $i ( $offset .. $limit ) {
                next if $i < 0;
                my $e = $entries[$i];
                next unless $e;
                $t->content_like(qr/$e->[1]/);
            }
        }
        $t->get_ok("/notes/display/$_->[0]")
          ->status_is(200)
          ->content_like(qr~$_->[1]~)
            for @entries;
    }
    else {
        $t->get_ok( '/notes' )->status_is(200);
    }
}
1;

