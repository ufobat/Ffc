use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use utf8;

use Carp;
use Data::Dumper;
use Test::Mojo;
use Test::More tests => 1668;

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
        if ( defined($p{BirthDate}) and not ( defined($p{BirthDateError}) and $p{BirthDateError} ) ) {
            note qq~Geburtsdatum wird im Test global umgesetzt auf "$bd"~;
            if ( $bd =~ m~\A(\d\d?)\.(\d\d?)\.(\d\d\d\d)?~xsmo ) {
                if ( $3 ) { $birthdate = sprintf '%02d.%02d.%04d', $1, $2, $3 }
                else      { $birthdate = sprintf '%02d.%02d.',     $1, $2     }
            }
            else {
                $birthdate = '';
            }
        }
        $t->content_like(qr~<input type="date" name="birthdate" value="$birthdate" />~);
        if ( defined($p{Info}) and not ( defined($p{InfoError}) and $p{InfoError} ) ) {
            note qq~Info wird im Test global umgesetzt auf "$io"~;
            $infos = $io;
        }
        $t->content_like(qr~<textarea name="infos" class="infos" id="textinput">$infos</textarea>~);
    }
    if ( $p{BirthDateError} or $p{InfoError} ) {
        error(join ' ', grep {$_} @p{qw(BirthDateError InfoError)});
    }
    if ( $p{BirthDateOkMsg} or $p{InfoOkMsg} ) {
        $p{BirthDateInfoOkMsg} = join ' ', grep {$_} @p{qw(BirthDateOkMsg InfoOkMsg)}
    }
    for my $inf ( qw(HideMailOkMsg LastOnlineOkMsg BirthDateInfoOkMsg) ) {
        info($p{$inf}) if exists $p{$inf};
    }
}

###############################################################################
note q~Tests laufen lassen~;
###############################################################################
note q~Ausgangslage checken~;
check_data();

sub test_online_status {
    note q~Online-Status-Anzeige umschalten~;
    test_data(HideLastSeen => 0, HideLastSeenOkMsg => 'Letzter Online-Status wird für andere Benutzer angezeigt');
    check_data();
    test_data(HideLastSeen => 1, HideLastSeenOkMsg => 'Letzter Online-Status wird versteckt');
    check_data();
    test_data(HideLastSeen => 0, HideLastSeenOkMsg => 'Letzter Online-Status wird für andere Benutzer angezeigt');
    check_data();
}

sub test_email_visible {
    note q~Email-Adress-Anzeige umschalten~;
    test_data(HideMail => 0, HideMailOkMsg => 'Email-Adresse geändert');
    check_data();
    test_data(HideMail => 1, HideMailOkMsg => 'Email-Adresse geändert');
    check_data();
    test_data(HideMail => 0, HideMailOkMsg => 'Email-Adresse geändert');
    check_data();
}

my @bdakt = (BirthDateOkMsg => 'Geburtsdatum aktualisiert');
my @bdentf = (BirthDateOkMsg => 'Geburtsdatum entfernt');
my @bderr = (BirthDateError => 'Geburtsdatum muss gültig sein und die Form &quot;##.##.####&quot; haben, wobei das Jahr weggelassen werden kann.');
my @infakt = (InfoOkMsg => 'Informationen aktualisiert');
my @infentf = (InfoOkMsg => 'Informationen entfernt');
my @inferr = (InfoError => 'Benutzerinformationen dürfen maximal 1024 Zeichen enthalten.');
my %params;
sub test_one_data {
    my ( $i, $str, @msgs ) = @_;
    my $p = sprintf '%s%02d', $str, $i;
    #note qq~Test-Set '$p': ~ . Dumper($params{$p});
    if ( exists $params{$p} ) { $p = $params{$p} }
    else { confess "Testvariable '$p' unbekannt: erlaubt: " . keys %params  }
    test_data(@$p, @msgs);
    check_data();
}

%params = ( %params,
    BirthDateError01 => [ BirthDate => 'asdfasdfas' ],
    BirthDateError02 => [ BirthDate => '    ' ],
    BirthDateError03 => [ BirthDate => '00000000' ],
    BirthDateError04 => [ BirthDate => '00.00.0000' ],
    BirthDateError05 => [ BirthDate => '03.00.' ],
    BirthDateError06 => [ BirthDate => '03.13.' ],
    BirthDateError07 => [ BirthDate => '0.03.' ],
    BirthDateError08 => [ BirthDate => '32.03.' ],
    BirthDateError09 => [ BirthDate => '03.03.0000' ],
    BirthDateError10 => [ BirthDate => '03.03.000' ],
    BirthDateOk01 => [ BirthDate => '03.03.' ],
    BirthDateOk02 => [ BirthDate => '4.04.' ],
    BirthDateOk03 => [ BirthDate => '05.5.' ],
    BirthDateOk04 => [ BirthDate => '6.6.' ],
    BirthDateOk05 => [ BirthDate => '7.7.1001' ],
    BirthDateOk06 => [ BirthDate => '08.8.1002' ],
    BirthDateOk07 => [ BirthDate => '9.09.1003' ],
    BirthDateOk08 => [ BirthDate => '' ],
);
sub test_birthdate_single {
    note q~Geburtstdatum einzeln testen~;
    test_one_data($_, 'BirthDateError', @bderr,  @infentf) for 1 .. 3;
    test_one_data($_, 'BirthDateOk',    @bdakt,  @infentf) for 1 .. 7;
    test_one_data($_, 'BirthDateError', @bderr,  @infentf) for 4 .. 6;
    test_one_data($_, 'BirthDateOk',    @bdentf, @infentf) for 8;
    test_one_data($_, 'BirthDateError', @bderr,  @infentf) for 7 .. 10;
}

%params = ( %params,
    InfosError01 => [ Info => 'x' x 1025 ],
    InfosOk01 => [ Info => 'x' x 1024 ],
    InfosOk02 => [ Info => Testinit::test_randstring() ],
    InfosOk03 => [ Info => Testinit::test_randstring() ],
    InfosOk04 => [ Info => '' ],
);
sub test_infos_single {
    note q~Infos einzeln testen~;
    test_one_data(1, 'InfosError', @inferr, @bdentf);
    test_one_data(1, 'InfosOk', @infakt, @bdentf);
    test_one_data(2, 'InfosOk', @infakt, @bdentf);
    test_one_data(4, 'InfosOk', @infentf, @bdentf);
    test_one_data(1, 'InfosOk', @infakt, @bdentf);
    test_one_data(1, 'InfosError', @inferr, @bdentf);
    test_one_data(4, 'InfosOk', @infentf, @bdentf);
    test_one_data(1, 'InfosError', @inferr, @bdentf);
}

sub test_two_data {
    my ( $ik, $im, $dk, $dm ) = @_;
    confess qq~Erster Info-Key "$ik" nicht bekannt~
        unless exists $params{$ik};
    confess qq~Zweiter Geburtsdatum-Key "$dk" nicht bekannt~
        unless exists $params{$dk};
    test_data(@{$params{$ik}}, @$im, @{$params{$dk}}, @$dm);
    check_data();
}
sub test_both_infos_and_birthdate {
    note q~Geburtstdatum und Infos im Zusammenspiel testen~;
    my @ips = (
        [InfosError01 => \@inferr],
        [InfosOk01 => \@infakt],
        #[InfosOk02 => \@infakt],
        #[InfosOk03 => \@infakt],
        [InfosOk04 => \@infentf],
    );
    my @bds = (
        #map({;[sprintf('BirthDateOk%02d',$_) => \@bdakt]} 1 .. 7),
        map({;[sprintf('BirthDateOk%02d',$_) => \@bdakt]} 1 .. 2), # sollte reichen für den test, sonst ufert das aus
        [BirthDateOk08 => \@bdentf],
        #map({;[sprintf('BirthDateError%02d',$_) => \@bderr]} 1 .. 10),
        map({;[sprintf('BirthDateError%02d',$_) => \@bderr]} 1 .. 2), # sollte reichen für den test, sonst ufert das aus
    );
    for my $i ( @ips ) {
        for my $d ( @bds ) {
            test_two_data(@$i, @$d);
        }
    }
}

###############################################################################
note q~Tests laufen lassen~;
###############################################################################

test_online_status();
test_email_visible();
test_birthdate_single();
test_infos_single();
test_both_infos_and_birthdate();

