use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;

use Test::Mojo;
use Test::More tests => 494;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = qw(test1 test1234 test2 test4321);

sub login { Testinit::test_login( $t, @_ ) }
sub error { Testinit::test_error( $t, @_ ) }
sub info  { Testinit::test_info(  $t, @_ ) }

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

note 'checking font size changes';
for my $i ( sort {$a <=> $b} keys %Ffc::Plugin::Config::FontSizeMap, 0 ) {
    my $s = $Ffc::Plugin::Config::FontSizeMap{$i};
    login($user1, $pass1);
    $t->get_ok("/options/fontsize/$i")
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<');
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

note 'checking background colors';
my $i = int rand(@Ffc::Plugin::Config::Colors - 3);
for my $c ( @Ffc::Plugin::Config::Colors[$i .. $i + 3], '' ) {
    login($user1, $pass1);
    if ( $c ) {
        $t->get_ok("/options/bgcolor/color/$c");
    }
    else {
        $t->get_ok("/options/bgcolor/none");
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

    login($user2, $pass2);
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~Angemeldet als "$user2"~)
      ->content_unlike(qr~background-color:~);
}

note 'checking theme switcher';
my $b = 0;
login($user1, $pass1);
for ( 0 .. 3 ) {
    $b = $b ? 0 : 1;
    $t->get_ok('/options/switchtheme')
      ->status_is(200)
      ->content_like(qr~Angemeldet als "$user1"~)
      ->content_like(qr'active activeoptions">Optionen<');
    $t->get_ok('/')
      ->status_is(200)
      ->content_like(qr~Angemeldet als "$user1"~)
      ->content_like(qr~href="$Ffc::Plugin::Config::Styles[$b]"~);
}

note 'checking image disable switch';

