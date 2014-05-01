use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;

use Test::Mojo;
use Test::More tests => 601;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test test1234);
Testinit::test_add_user( $t, $admin, $apass, $user, $pass );
my @testkats;
sub admin { Testinit::test_login( $t, $admin, $apass ) }
sub user  { Testinit::test_login( $t, $user,  $pass  ) }
sub error { Testinit::test_error( $t, @_             ) }
sub info  { Testinit::test_info(  $t, @_             ) }
sub rstr  { Testinit::test_randstring(               ) }

my @Settings = (
#   [ optkey => realname, inputtype
#               [good values], [bad values],
#               optionsheading, optionsexplaination, errormessage ]
    [ title => 'Webseitentitel', 'text',
        [rstr(), rstr(), scalar('a' x 256)], ['a', scalar('a' x 257)],
        'Der Titel muss zwischen zwei und 256 Zeichen lang sein' ],
    [ postlimit => 'Beitragsanzahl', 'number',
        [10 + int( rand 90),110 + int(rand 90)],['asdf'],
        'Die Anzahl gleichzeitig angezeigter Beiträge muss eine Zahl sein' ],
    [ sessiontimeout => 'Maximale Benutzersitzungsdauer', 'number',
        [10 + int( rand 90),110 + int(rand 90)],['asdf'],
        'Die Zeit der Benutzersitzungsmaximallänge muss eine Zahl in Sekunden sein' ],
    [ commoncattitle => 'Titel der allgemeinen Kategorie', 'text',
        [rstr(), rstr(), scalar('a' x 256)], ['a', scalar('a' x 257)],
        'Der Name der allgemeinen Kategorie muss zwischen zwei und 256 Zeichen lang sein' ],
    [ urlshorten => 'Maximale Länge für die URL-Darstellung', 'number',
        [10 + int( rand 90),110 + int(rand 90)],['asdf'],
        'Die Länge, auf die URLs in der Anzeige gekürzt werden, muss eine Zahl sein' ],
    [ backgroundcolor => 'Hintergrundfarbe', 'text',
        ['#aaBB99', '#aabb99', '', 'SlateBlue', scalar('a' x 128), 'aa'], ['#aabbfg', 'asdf ASD', '11$AA', '#aacc999', 'a', scalar('a' x 129), 'aa#bbcc'],
        'Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden' ],
    [ fixbackgroundcolor => 'Hintergrundfarbe unveränderlich vorgegeben', 'checkbox',
        [0,1,'',1], ['asdf', 22],
        'Der Hintergrundfarbzwang muss ein Schalter sein' ],
    [ favicon => 'Favoritenicon-Link', 'text',
        [rstr(), '', rstr(), scalar('a' x 256)], [scalar('a' x 257)],
        'Die URL zum Favoritenicon darf höchstens 256 Zeichen lang sein' ],
);

note qq~checking that admins have input fields available for boardsettings~;
admin();
$t->get_ok('/options/form')
  ->status_is(200)
  ->content_like(qr~<input type="(?:text|number|checkbox)" name="optionvalue" value="[^"]*"(?: checked="checked")? />~)
  ->content_like(qr'active activeoptions">Optionen<');

for my $s ( @Settings ) {
    my ( $key, $title, $itype, $goodv, $badv, $error ) = @$s;
    note qq~checking option "$key"~;

    note qq~checking that no normal user can reach option "$key"~;
    user();
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_unlike(qr~<form action="/options/admin/boardsettings/$key#boardsettingsadmin" method="POST">~)
      ->content_unlike(qr~<input type="$itype" name="optionvalue" value="[^"]*" (?:checked="checked")? />~)
      ->content_like(qr'active activeoptions">Optionen<');
    $t->post_ok("/options/admin/boardsettings/$key")
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<');
    error('Nur Administratoren dürfen das');
    
    note qq~checking that admin users can reach option "$key"~;
    admin();
    $t->get_ok('/options/form')
      ->status_is(200)
      ->content_like(qr~<form action="/options/admin/boardsettings/$key#boardsettingsadmin" method="POST">~);

    note qq~checking wrong input for "$key"~;
    my $url = "/options/admin/boardsettings/$key";
    my $info = "$title geändert";
    $t->post_ok($url)
      ->status_is(200)
      ->content_like(qr'active activeoptions">Optionen<');
    if ( $key =~ m/favicon|backgroundcolor|fixbackgroundcolor/xmso ) {
        info($info);
    }
    else {
        error($error);
    }
    for my $i ( @$badv ) {
        note qq~testing with bad value "$i"~;
        $t->post_ok($url, form => { optionvalue => $i } )
          ->status_is(200)
          ->content_like(qr'active activeoptions">Optionen<');
        error($error);
    }
    for my $i ( @$goodv ) {
        note qq~testing with good value "$i"~;
        $t->post_ok($url, form => { optionvalue => $i } )
          ->status_is(200)
          ->content_like(qr'active activeoptions">Optionen<');
        info($info);
        $t->get_ok('/config')
          ->status_is(200)
          ->json_is("/$key", $i);
        my $r = $dbh->selectall_arrayref('SELECT value FROM config WHERE key=?', undef, $key);
        is ref($r), 'ARRAY', 'config value retrieved from database';
        is $r->[0]->[0], $i, 'config value in database ok';
    }
}

