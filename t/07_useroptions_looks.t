use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;

use Test::Mojo;
use Test::More tests => 1184;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = qw(test1 test1234 test2 test4321);

sub login  { Testinit::test_login(  $t, @_ ) }
sub logout { Testinit::test_logout( $t, @_ ) }
sub error  { Testinit::test_error(  $t, @_ ) }
sub info   { Testinit::test_info(   $t, @_ ) }

Testinit::test_add_users($t, $admin, $apass, $user1, $pass1, $user2, $pass2);

note 'check user without options';
login($user1, $pass1);
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr~Angemeldet als "$user1"~)
  ->content_unlike(qr'background-color:');

login($user2, $pass2);
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr~Angemeldet als "$user2"~)
  ->content_unlike(qr'background-color:');

###############################################################################
###############################################################################

test_bgcolor();
test_email();
test_autorefresh();
test_hidelastseen();
test_notifications();

###############################################################################
###############################################################################
sub test_bgcolor {
    note 'checking background colors';
    my @good = ( '#aaBB99', '#aabb99', '', 'SlateBlue', scalar('a' x 128), 'aa' );
    my @bad  = ( '#aabbfg', 'asdf ASD', '11$AA', '#aacc999', 'a', scalar('a' x 129), 'aa#bbcc' );
    my $goodmsg   = 'Hintergrundfarbe angepasst';
    my $goodreset = 'Hintergrundfarbe zurück gesetzt';
    my $badmsg    = 'Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden';

    note 'color reset without form parameter';
    login($user1, $pass1);
    $t->post_ok("/options/bgcolor/color", form => {})
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'active activeoptions">Konto<');
    info('Hintergrundfarbe zurück gesetzt');

    for my $c ( @good ) {
        login($user1, $pass1);
        if ( $c ) {
            $t->post_ok("/options/bgcolor/color", form => { bgcolor => $c })
              ->status_is(302)->content_is('')->header_is(Location => '/options/form');
            $t->get_ok('/options/form')->status_is(200);
            info($goodmsg);
        }
        else {
            $t->get_ok("/options/bgcolor/none")
              ->status_is(302)->content_is('')->header_is(Location => '/options/form');
            $t->get_ok('/options/form')->status_is(200);
            info($goodreset);
        }
        $t->status_is(200)
          ->content_like(qr'active activeoptions">Konto<');
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user1"~);
        if ( $c ) {
            $t->content_like(qr~background-color:\s*$c~);
        }
        else {
            $t->content_unlike(qr~background-color:~);
        }
        logout();
        $t->content_unlike(qr~background-color:~);

        login($user2, $pass2);
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user2"~)
          ->content_unlike(qr~background-color:~);
    }
    for my $c ( @bad ) {
        login($user1, $pass1);
        $t->post_ok("/options/bgcolor/color", form => { bgcolor => $c })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        $t->get_ok('/options/form')->status_is(200);
        error($badmsg);

        login($user2, $pass2);
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user2"~)
          ->content_unlike(qr~background-color:~);
    }
}

###############################################################################
###############################################################################
sub test_email {
    note 'checking email entry';
    login($user1, $pass1);
    $t->post_ok('/options/email')
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'active activeoptions">Konto<');
    info('Email-Adresse entfernt');
    $t->post_ok('/options/email', form => { email => '' })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Konto<');
    info('Email-Adresse entfernt');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 1025 ) })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Konto<');
    error('Email-Adresse darf maximal 1024 Zeichen lang sein');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 100 ) })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Konto<');
    error('Email-Adresse sieht komisch aus');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    is $dbh->selectall_arrayref(
        'SELECT newsmail FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 1, 'newsmail still active in database';
    $t->post_ok('/options/email', form => { email => 'me@home.de', newsmail => 0 })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr'active activeoptions">Konto<')
      ->content_like(qr'name="email" type="email" value="me@home.de"');
    info('Email-Adresse geändert');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 'me@home.de', 'emailadress set in database';
    for my $field ( qw(news hidee) ) {
        is $dbh->selectall_arrayref(
            "SELECT ${field}mail FROM users WHERE name=?"
            , undef, $user1)->[0]->[0], 0, "${field}mail now inactive in database";
        $t->post_ok('/options/email', form => { email => 'him@work.com', "${field}mail" => 1 })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        $t->get_ok('/options/form')->status_is(200)
          ->content_like(qr'active activeoptions">Konto<')
          ->content_like(qr'name="email" type="email" value="him@work.com"');
        info('Email-Adresse geändert');
        is $dbh->selectall_arrayref(
            'SELECT email FROM users WHERE name=?'
            , undef, $user1)->[0]->[0], 'him@work.com', 'emailadress set in database';
        is $dbh->selectall_arrayref(
            "SELECT ${field}mail FROM users WHERE name=?"
            , undef, $user1)->[0]->[0], 1, "${field}mail now active again in database";
        login($user2, $pass2);
        $t->get_ok('/options/form')
          ->status_is(200)
          ->content_like(qr'name="email" type="email" value=""')
          ->content_like(qr'active activeoptions">Konto<');
        is $dbh->selectall_arrayref(
            'SELECT email FROM users WHERE name=?'
            , undef, $user2)->[0]->[0], '', 'emailadress not set in database';
        is $dbh->selectall_arrayref(
            "SELECT ${field}mail FROM users WHERE name=?"
            , undef, $user1)->[0]->[0], 1, "${field}mail active in database";
        login($user1, $pass1);
        $t->get_ok('/options/form')
          ->status_is(200)
          ->content_like(qr'name="email" type="email" value="him@work.com"')
          ->content_like(qr'active activeoptions">Konto<');
    }
}

###############################################################################
###############################################################################
sub test_autorefresh {
    # Default prüfen
    login($user1, $pass1);
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+3,~);
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 3);
    login($user2, $pass2);
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+3,~);
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 3);

    # Fehlerhaftes umsetzen ohne Daten
    $t->post_ok('/options/autorefresh')
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+3,~);
    error('Zeit für das automatische Neuladen der Seite konnte nicht geändert werden');
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 3);

    # Fehlerhaftes umsetzen mit String
    my $new = 'xyz';
    $t->post_ok('/options/autorefresh', form => { refresh => $new })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+3,~);
    error('Zeit für das automatische Neuladen der Seite konnte nicht geändert werden');
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 3);

    # Korrektes Umsetzen
    $new = 5 + int rand 100;
    $t->post_ok('/options/autorefresh', form => { refresh => $new })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+$new,~);
    info('Zeit für das automatische Neuladen der Seite auf '.$new.' Sekunden eingestellt');
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', $new);

    # Deaktivieren
    $t->post_ok('/options/autorefresh', form => { refresh => 0 })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+0,~);
    info('Zeit für das automatische Neuladen der Seite deaktiviert');
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 0);

    # Korrektes Umsetzen
    $new = $new + 1 + int rand 100;
    $t->post_ok('/options/autorefresh', form => { refresh => $new })
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+$new,~);
    info('Zeit für das automatische Neuladen der Seite auf '.$new.' Sekunden eingestellt');
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', $new);

    # Schaun, dass der andere Benutzer nicht betroffen ist
    login($user1, $pass1);
    $t->get_ok('/')->status_is(200)
      ->content_like(qr~ffcdata.features.init\(\);~)
      ->content_like(qr~autorefresh:\s+3,~);
    $t->get_ok('/session')->status_is(200)
      ->json_is('/autorefresh', 3);
}

###############################################################################
###############################################################################
sub test_hidelastseen {
    login($user1, $pass1);

    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~name="hidelastseen" value="1" checked="checked" />~);
    is $dbh->selectall_arrayref(
        "SELECT hidelastseen FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 1, "hidelastseen active in database";

    is $dbh->selectall_arrayref(
        "SELECT CASE WHEN lastonline IS NULL THEN 0 ELSE 1 END FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 0, "lastseen is not logged in database";

    $t->post_ok('/options/hidelastseen', form => {hidelastseen => ''})
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');

    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~name="hidelastseen" value="1" />~);
    is $dbh->selectall_arrayref(
        "SELECT hidelastseen FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 0, "hidelastseen inactive in database";
    is $dbh->selectall_arrayref(
        "SELECT CASE WHEN lastonline IS NULL THEN 0 ELSE 1 END FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 1, "lastseen is logged in database";

    $t->post_ok('/options/hidelastseen', form => {hidelastseen => '1'})
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');

    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~name="hidelastseen" value="1" checked="checked" />~);
    is $dbh->selectall_arrayref(
        "SELECT hidelastseen FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 1, "hidelastseen inactive in database";
    is $dbh->selectall_arrayref(
        "SELECT CASE WHEN lastonline IS NULL THEN 0 ELSE 1 END FROM users WHERE name=?"
        , undef, $user1)->[0]->[0], 0, "lastseen is not logged in database";

    $t->post_ok('/options/hidelastseen', form => {hidelastseen => ''})
      ->status_is(302)->content_is('')->header_is(Location => '/options/form');

    login($user2, $pass2);

    $t->get_ok('/options/form')->status_is(200)
      ->content_like(qr~name="hidelastseen" value="1" checked="checked" />~);
    is $dbh->selectall_arrayref(
        "SELECT hidelastseen FROM users WHERE name=?"
        , undef, $user2)->[0]->[0], 1, "hidelastseen active in database";
    is $dbh->selectall_arrayref(
        "SELECT CASE WHEN lastonline IS NULL THEN 0 ELSE 1 END FROM users WHERE name=?"
        , undef, $user2)->[0]->[0], 0, "lastseen is not logged in database";
}

###############################################################################
###############################################################################
sub test_notifications {
    # Diag
    my $d = sub {
        my $t = shift() // $t;
        if ( not $t->{success} ) {
            my @caller = caller(1);
            diag("-- error came from '$caller[2]'");
        }
    };

    # Check, ob und wie Notifications gesetzt sind
    my $check = sub {
        my $on = shift() // 0; my $t = shift() // $t;
        $t->get_ok('/options/form')->status_is(200);
        if ( $on ) {
            $t->content_like(
                qr~<input type="checkbox" name="notifications" value="1" checked="checked" />~);
        }
        else {
            $t->content_like(
                qr~<input type="checkbox" name="notifications" value="1" />~);
        }
        $d->();
        $t->get_ok('/forum')->status_is(200);
        $t->content_like($on ? qr~notifications:\s*true~ : qr~notifications:\s*false~ );
        $d->();
        $t->get_ok('/chat')->status_is(200);
        $t->content_like($on ? qr~notifications:\s*true~ : qr~notifications:\s*false~ );
        $d->();
        if ( $on ) {
            $t->content_like(
                qr~<input type="checkbox" id="notifyswitch" value="1" checked="checked" />~);
        }
        else {
            $t->content_like(
                qr~<input type="checkbox" id="notifyswitch" value="1" />~);
        }
        $d->();
    };

    # Notifications setzen
    my $set = sub {
        my $on = shift() // 0; my $t = shift() // $t;
        $t->post_ok('/options/notifications', form => { notifications => $on })->status_is(302);
        $t->content_is('');
        $t->header_is( Location => '/options/form' );
    };

    # Default User 1
    login($user1, $pass1);
    $check->(0);

    # User 1 enable
    $set->(1);
    $check->(1);

    # User 1 logout and login, setting should be preserved
    logout($user1, $pass1);
    login($user1, $pass1);
    $check->(1);
    $set->(0);
    logout($user1, $pass1);
    login($user1, $pass1);
    $check->(0);

    # User 2 hat Default, auch wenn User 1 was gesetzt hat
    $set->(1);
    logout($user1, $pass1);
    login($user2, $pass2);
    $check->(0);

    # User 2 merkt sich das Setting
    $set->(1);
    $check->(1);
    logout($user2, $pass2);
    login($user2, $pass2);
    $check->(1);

    # User 2 Setting wird nicht an User 1 übertragen
    $set->(0);
    $check->(0);
    logout($user2, $pass2);
    login($user1, $pass1);
    $check->(1);
    $set->(0);
    $check->(0);

    # Zweite parallele Session für User 2
    logout($user1, $pass1);
    login($user2, $pass2);
    $set->(1);
    $check->(1);

    my $t2 = Test::Mojo->new('Ffc');
    my $login2  = sub {Testinit::test_login ($t2, $user2, $pass2)};
    my $logout2 = sub {Testinit::test_logout($t2, $user2, $pass2)};

    $login2->();
    $check->(0, $t2);
    $set->(1, $t2);
    $check->(1, $t2);

    # Wie schlägt sich derweil die user1 Session
    logout($user2, $pass2);
    login($user1, $pass1);
    $check->(0);
    $check->(1, $t2);
    $check->(0);
    $set->(1);
    $check->(1);
    $check->(1, $t2);
    $set->(0);
    $check->(1, $t2);
    $set->(1, $t2);
    $check->(0);
    logout($user1, $pass1);
    login($user2, $pass2);
    $check->(1);
    $set->(0);
    $check->(1,$t2);
}


