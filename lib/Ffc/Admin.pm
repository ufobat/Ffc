package Ffc::Admin;
use 5.18.0;
use strict; use warnings; use utf8;

use Mojo::Base 'Mojolicious::Controller';

use Ffc::Admin::Routes;
use Ffc::Admin::User;
use Ffc::Admin::Boardsettings;

###############################################################################
# Einstellungs-Schema
our @Settings = (
#   [ optkey => realname, valid-regex, regexcheck, inputtype
#               optionsheading, optionsexplaination, errormessage, optsub ],
    [ title => 'Webseitentitel', qr(\A.{2,256}\z)xmso, 1, 'text',
        'Webseitentitel ändern',
        'Diese Überschrift wird üblicherweise in der Titelleiste des Browserfensters und dergleichen dargestellt',
        'Der Titel muss zwischen zwei und 256 Zeichen lang sein' ],
    [ cookiename => 'Cookie-Name', qr(\A.{2,256}\z)xmso, 1, 'text',
        'Name für Cookies ändern',
        'Hier kann der Name für Cookies geändert werden, über den die Anmeldungen verwaltet werden. Der Name sollte geändert werden, falls mehrere Foren parallel betrieben werden',
        'Der Name für Cookies muss zwischen zwei und 256 Zeichen lang sein',
        sub { $_[0]->app->sessions->cookie_name($_[2] || $Ffc::Plugin::Config::Defaults{cookiename}) }, ],
    [ sessiontimeout => 'Maximale Benutzersitzungsdauer', qr(\A\d+\z)xmso, 1, 'number',
        'Maximale Länge einer Benutzersitzung bei Untätigkeit ändern',
        'Hier kann die Zeit (in Sekunden) angegeben werden, bis eine Benutzersitzung abgelaufen ist, wenn ein Benutzer den Browser schließt, ohne sich abzumelden',
        'Die Zeit der Benutzersitzungsmaximallänge muss eine Zahl in Sekunden sein',
        sub { $_[0]->app->sessions->default_expiration($_[2] || $Ffc::Plugin::Config::Defaults{sessiontimeout}) }, ],
    [ maxscore => 'Bewertungslimit', qr(\A\d+\z)xmso, 1, 'number',
        'Maximal mögliche Berwertung in positive und negative Richtung',
        'Hierüber kann eingestellt werden, wie weit Bewertungen von Beiträgen gehen dürfen in positive sowie umgekehrt in negative Richtung',
        'Die maximale Bewertung muss eine Ganzzahl sein' ],
    [ urlshorten => 'Maximale Länge für die URL-Darstellung', qr(\A\d+\z)xmso, 1, 'number',
        'Längen-Kürzung für URL-Anzeige ändern',
        'URLs werden in Beiträgen und im Foren-Popup im Menü auf diese Anzahl von Zeichen in der Darstellung zurecht gekürzt, damit die in den Beiträgen nicht zu lang werden, die gesamte URL ist jedoch im Tooltip ersichtlich',
        'Die Länge, auf die URLs in der Anzeige gekürzt werden, muss eine Zahl sein' ],
    [ chatloglength => 'Maximale Länge des in der Datenbank gespeicherten Chat-Logs', qr(\A\d+\z)xmso, 1, 'number',
        'Anzahl Einträge aus dem Chat-Log in der Datenbank',
        'Es wird nur eine bestimmte Anzahl von Einträgen im Chat-Log in der Datenbank vorgehalten. Wird diese Anzahl überschritten, werden alte Einträge entsprechend gelöscht.',
        'Die Anzahl der Chat-Log-Einträge in der Datenbank muss eine Zahl sein' ],
    [ backgroundcolor => 'Hintergrundfarbe', sub { $Ffc::Options::ColorRe }, 1, 'color',
        'Hintergrundfarbe für die Webseite ändern',
        'Hier kann die Hintergrundfarbe für die Webseite in hexadezimaler Schreibweise mit führender Raute ("#") oder als Webfarbenname angegeben werden, welche Benutzer stanardmäßig angezeigt bekommen, Achtung: Wenn man selber eine Hintergrundfarbe bei sich eingestellt hat, dann zeigt diese Option bei einem selbst keine Wirkung, falls Benutzern erlaubt ist, die Hintergrundfarbe zu ändern',
        'Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden' ],
    [ customcss => 'Eigene CSS-Stylesheet-Datei', qr(\A.{0,256}\z)xmso, 1, 'url',
        'Link zu einer CSS-Datei für eigene Stylesheet-Angaben ändern',
        'Dieser Link wird verwendet, um, falls da was angegeben ist, zusätzlich zum Foren-Stylesheet eine weitere Datei einzubinden, in der man mit eigenen CSS-Angaben das Aussehen des Forums noch sehr viel detaillierter anpassen kann',
        'Die URL zur CSS-Datei darf höchstens 256 Zeichen lang sein' ],
    [ maxuploadsize => 'Maximale Dateigröße in Megabyte', qr(\A\d+\z)xmso, 1, 'number',
        'Maximale Größe von hochzuladenden Dateien ändern',
        'Die maximale Größe, die eine Datei haben kann, die hochgeladen werden soll',
        'Die Dateigröße wird in Megabyte angegeben und muss eine Zahl sein' ],
    [ inlineimage => 'Bilderlinks darstellen', undef, 0, 'checkbox',
        'Bildanzeige in Beiträgen und Chatnachrichten',
        'Sollen externe Links auf Bilder direkt im Text von Forenbeiträgen als Bilder angezeigt werden oder sollen nur die Links angezeigt werden',
        'Dieser Wert muss angehakt werden oder nicht' ],
);

# RegEx für die Settings
our $Optky = do {
    my $str = join '|', map {$_->[0]} @Settings;
    qr~$str~xmso
};

###############################################################################
# Prüfung, ob jemand als Admin eingetragen ist und ggf. eine Meldung ausliefern
sub check_admin {
    unless ( $_[0]->session->{admin} ) {
        $_[0]->set_error_f('Nur Administratoren dürfen das')
             ->redirect_to('options_form');
        return;
    }
    return 1;
}

###############################################################################
# Formular inkl. der Daten für die Administratoreneinstellungen vorbereiten
sub admin_options_form {
    my $c = $_[0];

    # Benutzerdaten speziell für die Administration der Benutzerverwaltung auslesen
    my $userlist = $c->dbh_selectall_arrayref(
            'SELECT u.id, u.name, u.active, u.admin, u.email FROM users u WHERE u.id!=? ORDER BY UPPER(u.name) ASC'
            , $c->session->{userid});

    # Themenliste speziell für die Auswahl eines Default-Themas auslesen, welches als "Startseite" angezeigt wird
    my $topics = $c->dbh_selectall_arrayref(
            'SELECT "id", SUBSTR("title", 0, ?) FROM "topics" ORDER BY UPPER("title")'
             , $c->configdata->{urlshorten});

    # Formulardaten vorbereiten und Formular erzeugen
    $c->stash(
        useremails    => join( '; ', map { $_->[4] || () } @$userlist ),
        userlist      => $userlist,
        configoptions => \@Settings,
        themes        => $topics,
    );
    $c->counting;
    $c->render(template => 'adminform');
}

1;
