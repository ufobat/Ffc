package Ffc::Options;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Options::Routes;
use Ffc::Options::User;
use Ffc::Options::UserPassword;
use Ffc::Options::AdminUser;
use Ffc::Options::AdminBoardsettings;

###############################################################################
# Farbcode-Prüfung
our $ColorRe = qr(\A(?:|\#[0-9a-f]{6}|\w{2,128})\z)xmsio;

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
# Formular inkl. der Daten für die Benutzereinstellungen vorbereiten
sub options_form {
    my $c = $_[0];

    # Formular aus der Datenbank für den Benutzer befüllen
    my $r = $c->dbh_selectall_arrayref(
        'SELECT email, newsmail, hideemail, birthdate, infos, hidelastseen FROM users WHERE id=?'
        , $c->session->{userid})->[0];
    $c->stash(
        email        => $r->[0],
        newsmail     => $r->[1],
        hideemail    => $r->[2],
        birthdate    => $c->stash('birthdate') // $r->[3],
        infos        => $c->stash('infos') // $r->[4],
        hidelastseen => $r->[5],
    );

    # Formular erzeugen
    $c->counting;
    $c->render(template => 'optionsform');
}

###############################################################################
# Formular inkl. der Daten für die Administratoreneinstellungen vorbereiten
sub admin_options_form {
    my $c = $_[0];

    # Benutzerdaten speziell für die Administration der Benutzerverwaltung auslesen
    my $userlist = $c->dbh_selectall_arrayref(
            'SELECT u.id, u.name, u.active, u.admin, u.email FROM users u WHERE UPPER(u.name) != UPPER(?) ORDER BY UPPER(u.name) ASC'
            , $c->session->{user});

    # Themenliste speziell für die Auswahl eines Default-Themas auslesen, welches als "Startseite" angezeigt wird
    my $topics = $c->dbh_selectall_arrayref(
            'SELECT "id", SUBSTR("title", 0, ?) FROM "topics" ORDER BY UPPER("title")'
             , $c->configdata->{urlshorten});

    # Formulardaten vorbereiten und Formular erzeugen
    $c->stash(
        useremails    => join( '; ', map { $_->[4] || () } @$userlist ),
        userlist      => $userlist,
        configoptions => \@Ffc::Options::Settings,
        themes        => $topics,
    );
    $c->counting;
    $c->render(template => 'adminform');
}

1;
