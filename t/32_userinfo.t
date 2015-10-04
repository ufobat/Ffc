use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Test::Mojo;
use Test::More tests => 238;

###############################################################################
note q~Testsystem vorbereiten~;
###############################################################################
my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1 ) = ( Testinit::test_randstring(), Testinit::test_randstring() );
Testinit::test_add_users( $t, $admin, $apass, $user1, $pass1 );
sub login_admin { Testinit::test_login( $t, $admin, $apass ) }
sub login_user1 { Testinit::test_login( $t, $user1, $pass1 ) }
sub info    { Testinit::test_info(    $t, @_ ) }
sub error   { Testinit::test_error(   $t, @_ ) }
sub warning { Testinit::test_warning( $t, @_ ) }
my $timeqr = qr~(?:jetzt|(\d?\d\.\d?\d\.\d\d\d\d, )?\d?\d:\d\d)~;

###############################################################################
note q~Testdaten~;
###############################################################################
my ( $emailon, $seeonline, $birthdate, $infos ) = (0, 0, '', '');
my $email = Testinit::test_randstring() . '@' . Testinit::test_randstring() . '.de';

###############################################################################
note q~Emailadresse eintragen~;
###############################################################################
login_user1();
$t->post_ok('/options/email', form => { email => $email, hideemail => 1 })
  ->status_is(302)->content_is('')->header_is(Location => '/options/form');
$t->get_ok('/options/form')->status_is(200)
  ->content_like(qr'active activeoptions">Benutzerkonto<')
  ->content_like(qr~name="email" type="email" value="$email"~);

###############################################################################
note q~Testroutinen~;
###############################################################################
sub check_data {
    note q~checking data~;
    login_admin();
    $t->get_ok('/pmsgs')->status_is(200)
      ->content_like(qr~<a href="/pmsgs/2">$user1</a>~);
    if ( $emailon ) {
        $t->content_like(qr~<th>Email:</th><td>$email</td>~);
    }
    else {
        $t->content_unlike(qr~<th>Email:</th><td>$email</td>~)
          ->content_unlike(qr~$email~);
    }
    if ( $seeonline ) {
        $t->content_like(qr~zuletzt online: $timeqr~);
    }
    else {
        $t->content_unlike(qr~zuletzt online~)
          ->content_unlike(qr~zuletzt online: $timeqr~);
    }
    if ( $birthdate ) {
        $t->content_like(qr~<th>Geboren:</th><td>$birthdate</td>~);
    }
    else {
        $t->content_unlike(qr~<th>Geboren:</th>~);
    }
    if ( $infos ) {
        $t->content_like(qr~<td rowspan="2" class="userinfobox"><pre>$infos</pre></td>~);
    }
    else {
        $t->content_unlike(qr~<td rowspan="2" class="userinfobox"><pre>~);
    }
}

sub test_data {
    note q~altering data~;
    my %keys = map {$_ => 1} qw(
        HideMail HideMailOkMsg
        HideLastSeen HideLastSeenOkMsg
        BirthDate BirthDateOkMsg BirthDateError 
        Info InfoOkMsg InfoError
    );
    my %p = @_;
    exists $keys{$_} or confess ("Key '$_' not allowed") 
        for keys %p;
    login_user1();
    if ( exists $p{HideMail} ) {
        confess "If 'HideMail' than 'HideMailOkMsg' is needed"
            unless $p{HideMailOkMsg};
        $t->post_ok('/options/email', form => { hideemail => $p{HideMail}, email => $email })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        my $chk = $p{HideMail} ? ' checked="checked"' : '';
        $t->get_ok('/options/form')->status_is(200)
          ->content_like(qr~<input type="checkbox" name="hideemail" value="1"$chk />~);
        $emailon = $p{HideMail} ? 0 : 1;
    }
    if ( exists $p{HideLastSeen} ) {
        confess "If 'HideLastSeen' than 'HideLastSeenOkMsg' is needed"
            unless $p{HideLastSeenOkMsg};
        $t->post_ok('/options/hidelastseen', form => { hidelastseen => $p{HideLastSeen} })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        $t->get_ok('/options/form')->status_is(200);
        my $chk = $p{HideLastSeen} ? ' checked="checked"' : '';
        $t->content_like(qr~<input type="checkbox" name="hidelastseen" value="1"$chk />~);
        $seeonline = $p{HideLastSeen} ? 0 : 1;
    }
    if ( exists $p{BirthDate} or exists $p{Info} ) {
        confess "If 'BirthDate' than 'BirthDateOkMsg' xor 'BirthDateError' is needed"
            if exists $p{BirthDate} and not ( $p{BirthDateOkMsg} xor $p{BirthDateError} );
        confess "If 'Info' than 'InfoOkMsg' xor 'InfoError' is needed"
            if exists $p{Info} and not ( $p{InfoOkMsg} xor $p{InfoError} );
        my $bd = $p{BirthDate} // $birthdate;
        my $io = $p{Info} // $infos;
        $t->post_ok('/options/infos', form => { birthdate => $bd, infos => $io })
          ->status_is(302)->content_is('')->header_is(Location => '/options/form');
        $t->get_ok('/options/form')->status_is(200);
        if ( exists $p{BirthDate} and not ( exists $p{BirthDateError} and $p{BirthDateError} ) ) {
            $birthdate = $bd;
        }
        $t->content_like(qr~<input type="date" name="birthdate" value="$birthdate" />~);
        if ( exists $p{Info} and not ( exists $p{InfoError} and $p{InfoError} ) ) {
            $infos = $io;
        }
        $t->content_like(qr~<input type="date" name="info" value="$infos" />~);
    }
    for my $err ( qw(BirthDateError InfoError ) ) {
        error($p{$err}) if exists $p{$err}
    }
    for my $inf ( qw(HideMailOkMsg LastOnlineOkMsg BirthDateOkBsg InfoOkMsg) ) {
        info($p{$inf}) if exists $p{$inf};
    }
}

###############################################################################
note q~Tests laufen lassen~;
###############################################################################
note q~Ausgangslage checken~;
check_data();

note q~Online-Status-Anzeige umschalten~;
test_data(HideLastSeen => 0, HideLastSeenOkMsg => 'Letzter Online-Status wird für andere Benutzer angezeigt');
check_data();
test_data(HideLastSeen => 1, HideLastSeenOkMsg => 'Letzter Online-Status wird versteckt');
check_data();
test_data(HideLastSeen => 0, HideLastSeenOkMsg => 'Letzter Online-Status wird für andere Benutzer angezeigt');
check_data();

note q~Email-Adress-Anzeige umschalten~;
test_data(HideMail => 0, HideMailOkMsg => 'Email-Adresse geändert');
check_data();
test_data(HideMail => 1, HideMailOkMsg => 'Email-Adresse geändert');
check_data();
test_data(HideMail => 0, HideMailOkMsg => 'Email-Adresse geändert');
