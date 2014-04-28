use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;

use Test::Mojo;
use Test::More tests => 711;

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
  ->content_unlike(qr'background-color:')
  ->content_unlike(qr'font-size:');

login($user2, $pass2);
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr~Angemeldet als "$user2"~)
  ->content_unlike(qr'background-color:')
  ->content_unlike(qr'font-size:');

test_font_size();
test_bgcolor();
test_theme_switcher();
test_email();
test_bgcolor_configoptions();

sub test_font_size {
    note 'checking font size changes';
    for my $i ( sort( {$a <=> $b} keys %Ffc::Plugin::Config::FontSizeMap ), 0 ) {
        my $s = $Ffc::Plugin::Config::FontSizeMap{$i};
        login($user1, $pass1);
        $t->get_ok("/options/fontsize/$i")
          ->status_is(200)
          ->content_like(qr'active activeoptions">Optionen<');
        info('Schriftgröße geändert');
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user1"~);
        if ( $i == 0 ) {
            $t->content_unlike(qr~font-size:~);
        }
        else {
            $t->content_like(qr~font-size:\s*${s}em~);
        }

        login($user2, $pass2);
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user2"~);
        if ( $i == 0 ) {
            $t->content_unlike(qr~font-size:~);
        }
        else {
            $t->content_like(qr~font-size:\s*${s}em~);
        }
    }
}

sub test_bgcolor {
    note 'checking background colors';
    my $i = int rand(@Ffc::Plugin::Config::Colors - 3);
    for my $c ( @Ffc::Plugin::Config::Colors[$i .. $i + 3], '' ) {
        login($user1, $pass1);
        if ( $c ) {
            $t->get_ok("/options/bgcolor/color/$c");
            info('Hintergrundfarbe angepasst');
        }
        else {
            $t->get_ok("/options/bgcolor/none");
            info('Hintergrundfarbe zurückgesetzt');
        }
        $t->status_is(200)
          ->content_like(qr'active activeoptions">Optionen<');
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
}

sub test_theme_switcher {
    note 'checking theme switcher';
    my $b = 0;
    for ( 0 .. 3 ) {
        $b = $b ? 0 : 1;
        login($user1, $pass1);
        $t->get_ok('/options/switchtheme')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user1"~)
          ->content_like(qr'active activeoptions">Optionen<');
        info('Ansicht gewechselt');
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user1"~)
          ->content_like(qr~href="$Ffc::Plugin::Config::Styles[$b]"~);
        login($user2, $pass2);
        $t->get_ok('/')
          ->status_is(200)
          ->content_like(qr~Angemeldet als "$user2"~)
          ->content_like(qr~href="$Ffc::Plugin::Config::Styles[$b]"~);
    }
}

sub test_email {
    note 'checking email entry';
    login($user1, $pass1);
    $t->post_ok('/options/email')
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<');
    error('Email-Adresse nicht gesetzt');
    $t->post_ok('/options/email', form => { email => '' })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Optionen<');
    error('Email-Adresse nicht gesetzt');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 1025 ) })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="a{1025}"')
      ->content_like(qr'active activeoptions">Optionen<');
    error('Email-Adresse darf maximal 1024 Zeichen lang sein');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => ('a' x 100 ) })
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="a{100}"')
      ->content_like(qr'active activeoptions">Optionen<');
    error('Email-Adresse sieht komisch aus');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], '', 'emailadress not set in database';
    $t->post_ok('/options/email', form => { email => 'me@home.de' })
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<')
      ->content_like(qr'name="email" type="email" value="me@home.de"');
    info('Email-Adresse geändert');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 'me@home.de', 'emailadress set in database';
    $t->post_ok('/options/email', form => { email => 'him@work.com' })
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<')
      ->content_like(qr'name="email" type="email" value="him@work.com"');
    info('Email-Adresse geändert');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user1)->[0]->[0], 'him@work.com', 'emailadress set in database';
    login($user2, $pass2);
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value=""')
      ->content_like(qr'active activeoptions">Optionen<');
    is $dbh->selectall_arrayref(
        'SELECT email FROM users WHERE name=?'
        , undef, $user2)->[0]->[0], '', 'emailadress not set in database';
    login($user1, $pass1);
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr'name="email" type="email" value="him@work.com"')
      ->content_like(qr'active activeoptions">Optionen<');
}

sub test_bgcolor_configoptions {
    my @Chars = ('a' .. 'z', 0 .. 9);
    note 'checking background chooser with default background color in config';
    my $sbgcolor = $t->app->configdata->{backgroundcolor} = 
        join '', 'c4', map {$Chars[int rand @Chars]} 1 .. 4;
    my $mbgcolor = 'my' . uc $sbgcolor;
    isnt $sbgcolor, $mbgcolor;

    $t->get_ok("/options/bgcolor/none");
    info('Hintergrundfarbe zurückgesetzt');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$sbgcolor~);

    $t->get_ok("/options/bgcolor/color/$mbgcolor");
    info('Hintergrundfarbe angepasst');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$mbgcolor~);

    $t->get_ok("/options/bgcolor/none");
    info('Hintergrundfarbe zurückgesetzt');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$sbgcolor~);

    note 'checking background chooser disabled via config param';
    $t->app->configdata->{fixbackgroundcolor} = 1;
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<')
      ->content_unlike(qr'Einstellungen zur Hintergrundfarbe');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$sbgcolor~);
    
    $t->get_ok("/options/bgcolor/color/$mbgcolor");
    error('Ändern der Hintergrundfarbe vom Forenadministrator deaktiviert');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$sbgcolor~);

    $t->get_ok("/options/bgcolor/none");
    info('Hintergrundfarbe zurückgesetzt');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~background-color:\s*$sbgcolor~);
}

