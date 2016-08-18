package Ffc::Options;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Options::Routes;
use Ffc::Options::User;
use Ffc::Options::UserPassword;

###############################################################################
# Farbcode-Prüfung
our $ColorRe = qr(\A(?:|\#[0-9a-f]{6}|\w{2,128})\z)xmsio;

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

1;
