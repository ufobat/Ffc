use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;

use Test::Mojo;
use Test::More tests => 501;

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

test_bgcolor();
test_email();

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
      ->status_is(200)
      ->content_like(qr'active activeoptions">Einstellungen<');
    info('Hintergrundfarbe zurück gesetzt');

    for my $c ( @good ) {
        login($user1, $pass1);
        if ( $c ) {
            $t->post_ok("/options/bgcolor/color", form => { bgcolor => $c });
            info($goodmsg);
        }
        else {
            $t->get_ok("/options/bgcolor/none");
            info($goodreset);
        }
        $t->status_is(200)
          ->content_like(qr'active activeoptions">Einstellungen<');
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
        $t->post_ok("/options/bgcolor/color", form => { bgcolor => $c });
        error($badmsg);

        login($user2, $pass2);
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user2"~)
          ->content_unlike(qr~background-color:~);
    }
}

sub test_email {
    note 'checking email entry';
    login($user1, $pass1);
    $t->post_ok('/options/email')
      ->status_is(200)
      ->content_like(qr'active activeoptions">Einstellungen<');
    error('Email-Adresse nicht gesetzt');
    $t->post_ok('/options/email', form => { email => '' })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Einstellungen<');
    error('Email-Adresse nicht gesetzt');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 1025 ) })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="a{1025}"')
      ->content_like(qr'active activeoptions">Einstellungen<');
    error('Email-Adresse darf maximal 1024 Zeichen lang sein');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 100 ) })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="a{100}"')
      ->content_like(qr'active activeoptions">Einstellungen<');
    error('Email-Adresse sieht komisch aus');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    is $dbh->selectall_arrayref(
        'SELECT newsmail FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 1, 'newsmail still active in database';
    $t->post_ok('/options/email', form => { email => 'me@home.de', newsmail => 0 })
      ->status_is(200)
      ->content_like(qr'active activeoptions">Einstellungen<')
      ->content_like(qr'name="email" type="email" value="me@home.de"');
    info('Email-Adresse geändert');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 'me@home.de', 'emailadress set in database';
    is $dbh->selectall_arrayref(
        'SELECT newsmail FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 0, 'newsmail now inactive in database';
    $t->post_ok('/options/email', form => { email => 'him@work.com', newsmail => 1 })
      ->status_is(200)
      ->content_like(qr'active activeoptions">Einstellungen<')
      ->content_like(qr'name="email" type="email" value="him@work.com"');
    info('Email-Adresse geändert');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 'him@work.com', 'emailadress set in database';
    is $dbh->selectall_arrayref(
        'SELECT newsmail FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 1, 'newsmail now active again in database';
    login($user2, $pass2);
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Einstellungen<');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user2)->[0]->[0], '', 'emailadress not set in database';
    is $dbh->selectall_arrayref(
        'SELECT newsmail FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 1, 'newsmail active in database';
    login($user1, $pass1);
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="him@work.com"')
      ->content_like(qr'active activeoptions">Einstellungen<');
}

