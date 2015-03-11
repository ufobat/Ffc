package Ffc::Options; # AdminBoardsettings
use strict; use warnings; use utf8;

our @Settings = (
#   [ optkey => realname, valid-regex, regexcheck, inputtype
#               optionsheading, optionsexplaination, errormessage ],
    [ title => 'Webseitentitel', qr(\A.{2,256}\z)xmso, 1, 'text',
        'Webseitentitel ändern',
        'Diese Überschrift wird üblicherweise in der Titelleiste des Browserfensters und dergleichen dargestellt',
        'Der Titel muss zwischen zwei und 256 Zeichen lang sein' ],
    [ cookiename => 'Cookie-Name', qr(\A.{2,256}\z)xmso, 1, 'text',
        'Name für Cookies ändern',
        'Hier kann der Name für Cookies geändert werden, über den die Anmeldungen verwaltet werden. Der Name sollte geändert werden, falls mehrere Foren parallel betrieben werden',
        'Der Name für Cookies muss zwischen zwei und 256 Zeichen lang sein' ],
    [ sessiontimeout => 'Maximale Benutzersitzungsdauer', qr(\A\d+\z)xmso, 1, 'number',
        'Maximale Länge einer Benutzersitzung bei Untätigkeit ändern',
        'Hier kann die Zeit (in Sekunden) angegeben werden, bis eine Benutzersitzung abgelaufen ist, wenn ein Benutzer den Browser schließt, ohne sich abzumelden',
        'Die Zeit der Benutzersitzungsmaximallänge muss eine Zahl in Sekunden sein' ],
    [ urlshorten => 'Maximale Länge für die URL-Darstellung', qr(\A\d+\z)xmso, 1, 'number',
        'Längen-Kürzung für URL-Anzeige ändern',
        'URLs werden in Beiträgen und im Foren-Popup im Menü auf diese Anzahl von Zeichen in der Darstellung zurecht gekürzt, damit die in den Beiträgen nicht zu lang werden, die gesamte URL ist jedoch im Tooltip ersichtlich',
        'Die Länge, auf die URLs in der Anzeige gekürzt werden, muss eine Zahl sein' ],
    [ backgroundcolor => 'Hintergrundfarbe', qr(\A(?:|\#[0-9a-f]{6}|\w{2,128})\z)msoi, 1, 'color',
        'Hintergrundfarbe für die Webseite ändern',
        'Hier kann die Hintergrundfarbe für die Webseite in hexadezimaler Schreibweise mit führender Raute ("#") oder als Webfarbenname angegeben werden, welche Benutzer stanardmäßig angezeigt bekommen, Achtung: Wenn man selber eine Hintergrundfarbe bei sich eingestellt hat, dann zeigt diese Option bei einem selbst keine Wirkung, falls Benutzern erlaubt ist, die Hintergrundfarbe zu ändern',
        'Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden' ],
    [ customcss => 'Eigene CSS-Stylesheet-Datei', qr(\A.{0,256}\z)xmso, 1, 'url',
        'Link zu einer CSS-Datei für eigene Stylesheet-Angaben ändern',
        'Dieser Link wird verwendet, um, falls da was angegeben ist, zusätzlich zum Foren-Stylesheet eine weitere Datei einzubinden, in der man mit eigenen CSS-Angaben das Aussehen des Forums noch sehr viel detaillierter anpassen kann',
        'Die URL zur CSS-Datei darf höchstens 256 Zeichen lang sein' ],
);

{
    my $str = join '|', map {$_->[0]} @Settings;
    $Ffc::Optky = qr~$str~xmso;
}

sub boardsettingsadmin {
    my $c = shift;
    my $optkey = $c->param('optionkey') // '';
    my $optvalue = $c->param('optionvalue') // '';
    my @setting = grep {$optkey eq $_->[0]} @Settings;
    unless ( @setting ) {
        $c->redirect_to('options_form');
        return; # theoretisch nicht möglich laut routen
    }
    my ( $tit, $re, $rechk, $err ) = @{$setting[0]}[1,2,3,7];
    unless ( $tit ) {
        $c->redirect_to('options_form');
        return; # theoretisch nicht möglich laut routen
    }
    if ( ( $rechk and $optvalue =~ $re ) or ( not $rechk and ( $optvalue eq '1' or not $optvalue ) ) ) {
        $c->dbh->do('UPDATE "config" SET "value"=? WHERE "key"=?',
            undef, $optvalue, $optkey);
        $c->configdata->{$optkey} = $optvalue;
        $c->set_info_f("$tit geändert");
    }
    else {
        $c->set_error_f($err);
    }

    $c->redirect_to('options_form');
}

sub set_starttopic {
    my $c = shift;
    my $tid = $c->param('topicid');
    $tid = 0 unless $tid;
    if ( $tid =~ $Ffc::Digqr ) {
        $c->dbh->do(q~UPDATE "config" SET "value"=? WHERE "key"='starttopic'~,
            undef, $tid);
        $c->configdata->{starttopic} = $tid;
        $c->set_info_f("Startseitenthema geändert");
    }
    else {
        $c->set_error_f('Fehler beim Setzen der Startseite');
    }
    $c->redirect_to('options_form');
}

1;

