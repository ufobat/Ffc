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
my $attcnt = 1;

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

sub ck { $Check_env->($t, shift() // \@entries, @_) }

sub run_tests {
    ( $Urlpref, $Check_env ) = @_;
    set_postlimit($t);

    ck();

# test new entries
    $t->post_ok("$Urlpref/new", form => {})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');

    login1();
    map { insert_text() } 1 .. $Postlimit * 2 + 1;
    ck();

# test text updates
    login2();
    update_text($user2, 0);

    login1();
    update_text($user1, $_) for 1, 3, 6;
    ck();

# test query filter
    login2();
    query_string($entries[0][1]);
    ck();
    login1();
    my $filter = query_string();
    ck([$entries[$filter]], scalar(@entries));

# test add attachements
    login2();
    add_attachement($user2, 0);

    login1();
    add_attachement($user1, $_) for 1, 3, 3, 5, 5, 5, 6;
    ck();
}

sub query_string {
    my $filter = $Postlimit + 1;
    my $str = $entries[$filter][1];
    $t->post_ok("$Urlpref/query", form => { query => $str })
      ->status_is(200)
      ->content_like(qr~<input\s+class="activesearch"\s+name="query"\s+type="text"\s+value="$str"\s+\/>~);
    for my $i ( 0 .. $#entries ) {
        next if $i == $filter;
        $t->content_unlike(qr~$entries[$i][1]~);
    }
    return $filter;
}

sub add_attachement {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my ( $str, $nam ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
    $nam .= '.png';
    $t->get_ok("$Urlpref/upload/$entry->[0]")->status_is(200);
    if ( $entry->[2] eq $user ) { 
        $t->content_like(qr~<p>\s*$entry->[1]\s*</p>~xms);
        $t->content_like(qr~<form action="$Urlpref/upload/$entry->[0]"\s+accept-charset="UTF-8"\s+enctype="multipart/form-data"\s+method="POST">~);
    }
    else {
        $t->content_unlike(qr~<p>\s*$entry->[1]\s*</p>~xms);
        warning('Keine passenden Beiträge gefunden');
    }
    $t->post_ok("$Urlpref/upload/$entry->[0]", 
        form => { 
            postid => $entry->[0],
            attachement => {
                file => Mojo::Asset::Memory->new->add_chunk($str),
                filename => $nam,
                content_type => 'image/png',
            },
        }
    );
    $t->status_is(302)->content_is('')
      ->header_like(location => qr~http://localhost:\d+$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entry->[2] eq $user ) {
        push @{$entry->[4]}, [ $attcnt++, $str, $nam ];
        info('Datei an den Beitrag angehängt');
    }
    else {
        error('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
    }
}

sub update_text {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my $str = Testinit::test_randstring();
    $t->get_ok("$Urlpref/edit/$entry->[0]")->status_is(200);
    if ( $entry->[2] eq $user ) { 
        $t->content_like(qr~$entry->[1]\s*</textarea>~xms);
    }
    else {
        $t->content_unlike(qr~$entry->[1]\s*</textarea>~xms);
        warning('Keine passenden Beiträge gefunden');
    }
    $t->post_ok("$Urlpref/edit/$entry->[0]", 
        form => { textdata => $str, postid => $entry->[0] })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~http://localhost:\d+$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entry->[2] eq $user ) {
        $entry->[1] = $str;
        info('Der Beitrag wurde geändert');
    }
    else {
        error('Kein passender Beitrag zum ändern gefunden');
    }
}

sub insert_text {
    my ( $from, $to ) = @_;
    my $str = Testinit::test_randstring();
    $t->post_ok("$Urlpref/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~http://localhost:\d+$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200)->content_like(qr~$str~);
    unshift @entries, my $entry = [$#entries + 2, $str, $from // $user1, $to, []];
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
            $t->content_like(qr~<p>\s*$e->[1]\s*</p>~);
        }
        for my $page ( 1 .. $pages ) {
            my $offset = ( $page - 1 ) * $main::Postlimit;
            my $limit = $offset + $main::Postlimit - 1;
            my $plink = "$Urlpref/$page";

            $t->get_ok( $plink )->status_is(200);
            
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
                check_attachements($e->[4]);
                $t->get_ok( $plink )->status_is(200);
            }
        }
        $t->get_ok("$Urlpref/display/$_->[0]")
          ->status_is(200)
          ->content_like(qr~<p>\s*$_->[1]\s*</p>~)
            for @entries;
    }
    else {
        $t->get_ok( $Urlpref )->status_is(200);
    }
}

sub check_attachements {
    my ( $attachements ) = @_;
    for my $att ( @$attachements ) {
        $t->content_like(qr"$Urlpref/download/$att->[0]")
          ->content_like(qr~alt="$att->[2]"~);
    }
    for my $att ( @$attachements ) {
        $t->get_ok("$Urlpref/download/$att->[0]")
          ->status_is(200)
          ->content_like(qr~$att->[1]~);
    }
}

1;

