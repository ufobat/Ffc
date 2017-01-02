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
my ( @entries, @delatts, @delents );
my $attcnt = 1;

my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
my ( $user2, $pass2 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1, $user2, $pass2 );
our @Users = ( $admin, $user1, $user2 );
sub users { $Users[$_[0]] }

sub logina { Testinit::test_login( $t, $admin, $apass ) && note 'logina' }
sub login1 { Testinit::test_login( $t, $user1, $pass1 ) && note 'login1' }
sub login2 { Testinit::test_login( $t, $user2, $pass2 ) && note 'login2' }

sub info    { Testinit::test_info(    $t, @_ ) }
sub error   { Testinit::test_error(   $t, @_ ) }
sub warning { Testinit::test_warning( $t, @_ ) }

sub set_postlimit {
    $t->get_ok("$Urlpref/limit/$Postlimit")
      ->status_is(302)->content_is('')->header_is(Location => $Urlpref);
    $t->get_ok($Urlpref)->status_is(200);
    info("Anzahl der auf einer Seite der Liste angezeigten Beiträge auf $Postlimit geändert.");
}

sub ck { 
    note 'HERKUNFT: ' . join ' ; ', map {; join ', ', (caller($_))[1,2] } 0 .. 3; 
    my $entries = shift() // \@entries;
    note Dumper $entries, \@delents, \@delatts, \@_;
    $Check_env->($t, $entries, \@delents, \@delatts, @_);
}

sub run_tests {
    my ( $from, $to, $do_attachements, $do_edit, $do_delete );
    ( $from, $to, $Urlpref, $Check_env, $do_attachements, $do_edit, $do_delete ) = @_;
    logina();
    note 'setting the postlimit';
    set_postlimit($t);

    ck();

    login1();
    set_postlimit($t);
    login2();
    set_postlimit($t);
    login1();
    note 'test new entries';

    note 'Leerer Beitrag';
    $t->post_ok("$Urlpref/new", form => {})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
    $t->post_ok("$Urlpref/new", form => {textdata => ''})->status_is(200);
    error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');

    note 'neue Beitraege: 1 .. ' . ($Postlimit * 2 + 1) ;
    map { insert_text($Users[$from], ( $to && $Users[$to] ) ) } 1 .. $Postlimit * 2 + 1;
    die "Neue Beiträge mit Uploads testen!!!";
    ck();

    if ( $do_edit ) {
        note 'test text updates fail';
        login2();
        update_text($user2, 0);

        note 'test text updates work';
        login1();
        update_text($user1, $_) for 1, 3, 6;
        ck();
    }
    else {
        note 'check, that no edits are possible';
        login1();
        no_update_text($user1, 6);
        ck();
    }

    note 'test query filter';
    login2();
    query_string($entries[0][1]);
    ck();
    login1();
    my $filter = query_string();
    note "Filter: $filter";
    ck([$entries[$filter]], scalar(@entries), $filter);

    if ( $do_attachements ) {
        note 'test add attachements fails';
        login2();
        add_attachement($user2, 0);

        note 'test add attachements works';
        login1();
        add_attachement($user1, $_) for 1, 3, 3, 5, 5, 5, 6; # array id's
        ck();

        note 'test delete single attachements fails';
        login2();
        del_attachement($user2, 6 => 7);

        note 'test delete single attachements works';
        login1();
        del_attachement($user1, @$_) for [1 => 1], [5 => 6], [5 => 5]; # array id's to db id's!!!
        ck();

        # diag 'test attache a no image file';
        login2();
        add_attachement($user2, 0, 1);
        ck();
    }
    else {
        # diag 'check, that no attachement-operations are available';
        login1();
        no_attachements($user1, 1);
        ck();
    }

    if ( $do_delete ) {
        note 'test delete complete posts (check attachements) fails';
        login2();
        del_post($user2, 1);

        note 'test delete complete posts (check attachements) works';
        login1();
        del_post($user1, 3);
        ck();
    }
    else {
        # diag 'check, that no delete operations on the entries is available';
        login1();
        no_delete($user1, 3);
        ck();
    }

    if ( $do_attachements ) {
        note 'test add multi attachements works';
        login1();
        add_attachement($user1, 1, undef, 3);
        ck();
    }
}

sub no_delete {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my $str = Testinit::test_randstring();
    $t->get_ok("$Urlpref/delete/$entry->[0]")
      ->status_is(404);
    $t->post_ok("$Urlpref/delete/$entry->[0]", 
        form => { textdata => $str, postid => $entry->[0] })
      ->status_is(404);
}

sub del_post {
    my ( $user, $eid ) = @_;
    my $edbid = $entries[$eid][0];
    $t->get_ok("$Urlpref/delete/$edbid");
    if ( $entries[$eid][2] eq $user ) {
        $t->status_is(200)
          ->content_like(qr~<form\s+action="$Urlpref/delete/$edbid"\s+accept-charset="UTF-8"\s+method="POST">\s*<p>Möchten Sie den unten gezeigten Beitrag wirklich komplett und unwiederruflich entfernen\?</p>\s*<p>\s*<button\s+type="submit"\s+class="linkalike\s+send">Entfernen</button>\s*</p>\s*</form>~);
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        error('Konnte keinen passenden Beitrag zum Löschen finden');
        seen_entries();
    }
    $t->post_ok("$Urlpref/delete/$edbid")
      ->status_is(302)->content_is('')
      ->header_like(location => qr~$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entries[$eid][2] eq $user ) {
        push @delatts, @{ $entries[$eid][4] };
        push @delents, $entries[$eid];
        $entries[$eid][4] = [];
        splice @entries, $eid, 1;
        info('Der Beitrag wurde komplett entfernt');
    }
    else {
        error('Konnte keinen passenden Beitrag zum Löschen finden');
    }
}

sub no_attachements {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my $str = Testinit::test_randstring();
    my $nam = Testinit::test_randstring();
    $t->get_ok("$Urlpref/upload/$entry->[0]")
      ->status_is(404);
    $t->post_ok("$Urlpref/upload/$entry->[0]", 
        form => { 
            postid => $entry->[0],
            attachement => {
                file => Mojo::Asset::Memory->new->add_chunk($str),
                filename => $nam,
                content_type => 'image/png',
            },
        }
    )->status_is(404);
    $t->get_ok("$Urlpref/upload/delete/$entry->[0]/1")
      ->status_is(404);
    $t->post_ok("$Urlpref/upload/delete/$entry->[0]/1")
      ->status_is(404);
}

sub del_attachement {
    my ( $user, $eid, $aid ) = @_;
    my $edbid = $entries[$eid][0];
    $t->get_ok("$Urlpref/upload/delete/$edbid/$aid");
    #diag Dumper $entries[$eid];
    if ( $entries[$eid][2] eq $user or ( $entries[$eid][3] and $entries[$eid][3] eq $user ) ) {
        $t->status_is(200)
          ->content_like(qr~<form\s+action="$Urlpref/upload/delete/$edbid/$aid"\s+accept-charset="UTF-8"\s+method="POST">\s*<button\s+type="submit"\s+class="linkalike\s+send">Entfernen</button>\s*</form>~)
          ->content_like(qr~Möchten Sie den gezeigten Anhang zu unten gezeigtem Beitrag wirklich löschen\?~);
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        seen_entries();
        error('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
    }
    $t->post_ok("$Urlpref/upload/delete/$edbid/$aid")
      ->status_is(302)->content_is('')
      ->header_like(location => qr~$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entries[$eid][2] eq $user ) {
        info(qq~Anhang entfernt~);
        push @delatts, grep { $aid == $_->[0] } @{ $entries[$eid][4] };
        $entries[$eid][4] = [ grep { $aid != $_->[0] } @{ $entries[$eid][4] } ];
    }
    else {
        if ( $entries[$eid][3] and $entries[$eid][3] eq $user ) {
            error('Sie dürfen diesen Anhang nicht löschen, da der Beitrag nicht von Ihnen erstellt wurde');
        }
        else {
            error('Konnte keinen passenden Beitrag zum Löschen der Anhänge finden');
        }
    }
}

sub query_string {
    my $filter = $Postlimit + 1;
    my $str = $entries[$filter][7];
    $t->post_ok("$Urlpref/query", form => { query => $str })
      ->status_is(200)
      ->content_like(qr~<input\s+class="activesearch"\s+name="query"\s+type="text"\s+value="$str"(?:\s+\/)?>~);
    for my $i ( 0 .. $#entries ) {
        next if $i == $filter;
        ok $entries[$i][7], 'searchstring available';
        like $entries[$i][1], qr~\b$entries[$i][7]\b~, 'viewstring contaings searchstring';
        $t->content_unlike(qr~\b$entries[$i][7]\b~);
        unless ( $t->success ) {
            use Data::Dumper; die Dumper \@entries;
        }
    }
    return $filter;
}

sub add_attachement {
    my ( $user, $i, $ext, $multi ) = @_;
    note 'HERKUNFT: ' . join ' ; ', map {; join ', ', (caller($_))[1,2] } 0 .. 3; 
    note '( $user, $i, $ext, $multi ) = (' . join ', ', map {$_ // ''} $user, $i, $ext, $multi;
    $multi ||= 1;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    $ext = $ext ? 'exe' : 'png';

    my @atts = map {;
            [Testinit::test_randstring(), Testinit::test_randstring() . ".$ext"]
        } 1 .. $multi;

    $t->get_ok("$Urlpref/upload/$entry->[0]");
    if ( $entry->[2] eq $user or ( $entry->[3] and $entry->[3] eq $user ) ) { 
        $t->status_is(200);
        $t->content_like(qr~<p>\s*$entry->[1]\s*</p>~xms);
        $t->content_like(qr~<form action="$Urlpref/upload/$entry->[0]"\s+accept-charset="UTF-8"\s+enctype="multipart/form-data"\s+method="POST">~);
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        seen_entries();
        error('Konnte keinen passenden Beitrag um Anhänge hochzuladen finden');
    }
    # Dateiupload ohne Dateien failed
    $t->post_ok("$Urlpref/upload/$entry->[0]", form => { postid => $entry->[0], attachement => [] } )
      ->status_is(302)->content_is('')->header_like(Location => qr~$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entry->[2] eq $user ) { error('Kein Dateianhang angegeben.') }
    else                        { error('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.') }
    # Richtiger Upload
    $t->post_ok("$Urlpref/upload/$entry->[0]", 
        form => { 
            postid => $entry->[0],
            attachement => [
                map {;
                    {
                        file => Mojo::Asset::Memory->new->add_chunk($_->[0]),
                        filename => $_->[1],
                        'Content-Type' => $ext ? '*/exe' : 'image/png',
                    }
                } @atts
            ]
        }
    );
    $t->status_is(302)->content_is('')
      ->header_like(location => qr~$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entry->[2] eq $user ) {
        push @{$entry->[4]}, map {[ $attcnt++, $_->[0], $_->[1] ]} @atts;
        info('Dateien an den Beitrag angehängt');
    }
    else {
        error('Zum angegebene Beitrag kann kein Anhang hochgeladen werden.');
    }
}

sub format_text {
    my $str = shift;
    $str =~ s~:-\)~<img class="smiley" src="/theme/img/smileys/smile.png" alt=":-\\)" title=":-\\)" />~go;
    $str =~ s~\n+~</p>\\n<p>~gmso;
    $str =~ s~\s~\\s~gmso;
    return $str;
}

sub format_for_re {
    my $str = shift;
    $str =~ s~:-\)~:-\\)~gmso;
    $str =~ s~\n~\\n~msgo;
    return $str;
}

sub get_randstring {
    my $str = Testinit::test_randstring();
    return 
             Testinit::test_randstring() 
           . '<b>' 
           . $str 
           . "</b>abc:-)\n\n" 
           . Testinit::test_randstring(),
        $str
}

sub update_text {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my ( $str, $search ) = get_randstring();
    $t->get_ok("$Urlpref/edit/$entry->[0]");
    if ( $entry->[2] eq $user ) { 
        $t->status_is(200);
#        use Data::Dumper; warn Dumper \@entries, $user, $i;
        $t->content_like(qr~$entry->[6]\s*</textarea>~xms);
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        error('Konnte keinen passenden Beitrag zum Ändern finden');
        seen_entries();
    }
    
    # leerer Text
    $t->post_ok("$Urlpref/edit/$entry->[0]", form => {postid => $entry->[0]});
    if ( $entry->[2] eq $user ) {
        $t->status_is(200);
        error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\) Konnte keinen passenden Beitrag zum Ändern finden');
        seen_entries();
    }
    $t->post_ok("$Urlpref/edit/$entry->[0]", form => {textdata => '', postid => $entry->[0]});
    if ( $entry->[2] eq $user ) {
        $t->status_is(200);
        error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\)');
    }
    else {
        $t->status_is(302)->content_is('')
          ->header_like(location => qr~$Urlpref~);
        $t->get_ok($Urlpref)->status_is(200);
        error('Es wurde zu wenig Text eingegeben \\(min. 2 Zeichen\\) Konnte keinen passenden Beitrag zum Ändern finden');
        seen_entries();
    }

    # Funktionierendes Edit
    $t->post_ok("$Urlpref/edit/$entry->[0]", 
        form => { textdata => $str, postid => $entry->[0] })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~$Urlpref~);
    $t->get_ok($Urlpref)->status_is(200);
    if ( $entry->[2] eq $user ) {
        $entry->[1] = format_text($str);
        $entry->[6] = format_for_re($str);
        $entry->[7] = $search;
        $entry->[5] = 1;
        info('Der Beitrag wurde geändert');
    }
    else {
        error('Kein passender Beitrag zum ändern gefunden');
    }
    seen_entries();
}

sub no_update_text {
    my ( $user, $i ) = @_;
    my $entry = $entries[$i] or die "no entry count '$i' available";
    my $str = Testinit::test_randstring();
    $t->get_ok("$Urlpref/edit/$entry->[0]")
      ->status_is(404);
    $t->post_ok("$Urlpref/edit/$entry->[0]", 
        form => { textdata => $str, postid => $entry->[0] })
      ->status_is(404);
}

sub insert_text {
    my ( $from, $to ) = @_;
    my ($str,$search)  = get_randstring();
    $t->post_ok("$Urlpref/new", form => { textdata => $str })
      ->status_is(302)->content_is('')
      ->header_like(location => qr~$Urlpref~);
    my $str1 = format_text($str);
    $t->get_ok($Urlpref)->status_is(200)->content_like(qr~$str1~);
# $entry = [ $id, $textdata, $userfromid, $usertoid, [$attachements], $is_new_or_altered, $rawdata, $partialsearchstr ];
    return add_entry_testarray($str1, $from, $to, [], 1, format_for_re($str), $search);
}

{
    my $lastid = 0;
    sub lastid { $lastid = shift }
    sub add_entry_testarray {
        my ( $str, $from, $to, $attsarray, $changed, $rawdata, $search ) = @_;
        unshift @entries, my $entry = [++$lastid, $str, $from // $user1, $to, $attsarray, $changed, $rawdata, $search];
        return $entry;
    }
}

# prüft alle einträge, ob sie in der richtigen seite auftauchen
sub check_pages {
    if ( my $loginsub = shift() ) {
        $loginsub->();
    }
    else {
        login1();
    }
    local $Urlpref = shift() || $Urlpref;
    if ( @entries ) {
        my $pages = @entries / $main::Postlimit;
        $pages = 1 + int $pages if int($pages) != abs($pages);
        $t->get_ok($Urlpref)->status_is(200);
        for my $i ( 0 .. $main::Postlimit - 1 ) {
            if ( $i <= $#entries and my $e = $entries[$i] ) {
                $t->content_like(qr~<p>\s*$e->[1]\s*</p>~);
            }
        }
        for my $page ( 1 .. $pages ) {
            my $offset = ( $page - 1 ) * $main::Postlimit;
            my $limit = $offset + $main::Postlimit - 1;
            my $plink = "$Urlpref/$page";

            note "page=$page, offset=$offset, limit=$limit, postlimit=$main::Postlimit, entrix=$#entries, scalar=" . scalar @entries;
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

            for my $e ( @delents ) {
                $t->content_unlike(qr~$e->[7]~);
                like $e->[1], qr~$e->[7]~, 'viewstring contaings searchstring';
            }
            
            for my $i ( $offset .. $limit ) {
                next if $i < 0;
                my $e = $entries[$i];
                next unless $e;
                $t->content_like(qr/$e->[1]/)
                  ->content_like(qr~$Urlpref/display/$e->[0]~);
                check_attachements($e->[4]);
                $t->get_ok( $plink )->status_is(200);
                check_delattachements();
            }
        }
        for my $e ( @entries ) {
            $t->get_ok("$Urlpref/display/$e->[0]")
              ->status_is(200)
              ->content_like(qr~<p>\s*$e->[1]\s*</p>~);
            check_delattachements();
        }
    }
    else {
        $t->get_ok( $Urlpref )->status_is(200);
    }
    for my $att ( @delatts ) {
        $t->get_ok("$Urlpref/download/$att->[0]")
          ->status_is(404)
          ->content_unlike(qr~alt="$att->[2]"~);
    }
    for my $e ( @delents ) {
        like $e->[1], qr~$e->[7]~, 'viewstring contaings searchstring';
        $t->get_ok("$Urlpref/display/$e->[0]")
          ->status_is(200)
          ->content_unlike(qr~$e->[7]~);
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
          ->content_like(qr~$att->[1]~)
          ->header_like('Content-Disposition', qr~(?:inline|attachment);\s*filename=.*~xmsio);
        my ( $isimage, $filename ) = (
            $t->tx->res->headers->{headers}->{'content-disposition'}->[0] =~ m~(inline|attachment);\s*filename=(.*)~xmsio
                ? ( $1, $2 ) : ( '', '' ) );
        ok $filename eq qq~"$att->[2]"~, 'file name in header is ok';
        if ( $filename =~ m~\.png"\z~xmsio ) {
            ok $isimage eq 'inline', 'attachement is an image';
            $t->header_is('Content-Type', 'image/png');
        }
        else {
            ok $isimage eq 'attachment', 'attachement is no image';
            $t->header_is('Content-Type', '*/txt');
        }
    }
}

sub check_delattachements {
    for my $att ( @delatts ) {
        $t->content_unlike(qr~$Urlpref/download/$att->[0]"~)
          ->content_unlike(qr~alt="$att->[2]"~);
    }
}

sub seen_entries {
    $_->[5] = 0 for @entries;
    note 'marked all entries as seen';
}

$t;

