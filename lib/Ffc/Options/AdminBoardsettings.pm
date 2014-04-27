package Ffc::Options; # AdminBoardsettings
use strict; use warnings; use utf8;

# title  postlimit  sessiontimeout  commoncattitle  urlshorten  backgroundcolor  fixbackgroundcolor  favicon
our @Settings = (
#   [ optkey => realname, valid-regex, inputtype
#               optionsheading, optionsexplaination, errormessage ]
    [ title => 'Webseitentitel', qr(.{2,256})xmso, 'text',
        'Webseitentitel ändern',
        'Diese Überschrift wird üblicherweise in der Titelleiste des Browserfensters und dergleichen dargestellt',
        'Der Titel muss zwischen zwei und 256 Zeichen lang sein' ],
    [ postlimit => 'Beitragsanzahl', qr(\d+)xmso, 'number',
        'Anzahl der auf einer Seite angezeigten Beiträge ändern',
        'Hier kann die Anzahl der auf einer Seite gleichzeitig angezeigten Forenbeiträge beschränkt werden',
        'Die Anzahl gleichzeitig angezeigter Beiträge muss eine Zahl sein' ],
    [ sessiontimeout => 'Maximale Benutzersitzungsdauer', qr(\d+)xmso, 'number',
        'Maximale Länge einer Benutzersitzung bei Untätigkeit ändern',
        'Hier kann die Zeit (in Sekunden) angegeben werden, bis eine Benutzersitzung abgelaufen ist, wenn ein Benutzer den Browser schließt, ohne sich abzumelden',
        'Die Zeit der Benutzersitzungsmaximallänge muss eine Zahl (Sekunden) sein' ],
    [ commoncattitle => 'Titel der allgemeinen Kategorie', qr(.{2,256})xmso, 'text',
        'Standardkategorietitel ändern',
        'Diese Überschrift wird für die erste Kategorie verwendet, welche immer da ist und bei der man üblicherweise startet als Benutzer, sie wird jedoch nicht angezeigt, wenn keine weiteren Kategorien definiert und sichtbar sind',
        'Der Name der allgemeinen Kategorie muss zwischen zwei und 256 Zeichen lang sein' ],
    [ urlshorten => 'Maximale Länge für die URL-Darstellung', qr(\d+)xmso, 'number',
        'Längen-Kürzung fürURL-Anzeige ändern',
        'URLs werden in Beiträgen auf diese Anzahl von Zeichen in der Darstellung zurecht gekürzt, damit die in den Beiträgen nicht zu lang werden, die gesamte URL ist jedoch im Tooltip ersichtlich',
        'Die Länge, auf die URLs in der Anzeige gekürzt werden, muss eine Zahl sein' ],
    [ backgroundcolor => 'Hintergrundfarbe', qr(\#[a-f0-9]{6}|\w{2,128})xmsoi, 'text',
        'Hintergrundfarbe für die Webseite ändern',
        'Hier kann die Hintergrundfarbe für die Webseite in hexadezimaler Schreibweise mit führender "#" oder als Webfarbenname angegeben werden, welche Benutzer stanardmäßig angezeigt bekommen',
        'Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender "#" oder als Webfarbenname angegeben werden' ],
    [ fixbackgroundcolor => 'Hintergrundfarbe unveränderlich vorgegeben', qr(1?), 'checkbox',
        'Hintergrundfarbe für Benutzer unveränderbar machen',
        'Hier kann man die vorgegebene Hintergrundfarbe für alle Benutzer zwingend machen, so dass die Benutzer die Farbe nicht ändern können und auch keinen entsprechenden Dialog in den Optionen angeboten bekommen, ist das Häkchen gesetzt, können Benutzer die Hintergrundfarbe nicht ändern',
        'Der Hintergrundfarbzwang muss ein Schalter sein' ],
    [ favicon => 'Favoritenicon-Link', qr(.{2,256})xmso, 'text',
        'Link zum Favoritenicon ändern',
        'Dieser Link kann statt des Standard-Favoritenicons verwendet werden, welches verwendet wird, sollte diese Option leer gelassen werden',
        'Die URL zum Favoritenicon muss zwischen zwei und 256 Zeichen lang sein' ],
);

sub boardsettingsadmin {
    my $c = shift;
    my $optkey = $c->param('optionkey') // '';
    my $optvalue = $c->param('optionvalue') // '';

    my ( $tit, $re, $err ) = @{ ( grep {$optkey eq $_->[0]} @Settings )[0] }[1,2,6];
    if ( $optvalue =~ $re ) {
# ...
        $c->set_info("$tit geändert");
    }
    else {
        $c->set_error($err);
    }

    $c->options_form();
}

1;

