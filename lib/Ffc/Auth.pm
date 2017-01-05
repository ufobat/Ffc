package Ffc::Auth;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

###############################################################################
# Anmelderouten für den Anwendungsstart einrichten
sub install_routes {
    my $r = $_[0]->routes;

    # Anmeldehandling und Anmeldeprüfung
    $r->post('/login')->to('auth#login')->name('login');
    $r->get('/login')->to('auth#loginform')->name('loginform'); # just in case
    $r->get('/logout')->to('auth#logout')->name('logout');

    # Bridge-Auslieferung
    return $r->under('/')
             ->to('auth#check_login')
             ->name('login_check');
}

###############################################################################
# Anmeldung überprüfen
sub check_login {
    my $c = shift;
    if ( $c->session->{user} ) { # User ist angemeldet
        my $s = $c->session();

        # Aktuelle User-Konfigurationsdaten abholen
        my $r = $c->dbh_selectall_arrayref(
            'SELECT "admin", "bgcolor", "name", "autorefresh", 
                "chronsortorder",
                "hidelastseen", "newsmail"
            FROM "users" WHERE "active"=1 AND "id"=?',
            $s->{userid});

        # Session mit Aktualisierungen befüllen
        if ( $r and @$r and $r->[0]->[2] eq $s->{user} ) { 
            @$s{qw(admin backgroundcolor autorefresh chronsortorder hidelastseen newsmail)}
                = @{$r->[0]}[0, 1, 3, 4, 5, 6];

            # Die Hintergrundfarbe muss nicht notwendigerweise vom User gesetzt sein
            $s->{backgroundcolor} = $c->configdata->{backgroundcolor}
                unless $s->{backgroundcolor};

            # Themenlistenlänge und Beitragslistenlänge (inkl. fest verdrahteter Defaultwert) ermitteln sowie Desktopbenachrichtigungen
            for my $o ( 
                [ limits  => topiclimit    => 15 ], 
                [ limits  => postlimit     => 10 ],
                [ options => notifications => 0  ],
            ) {
                $c->user_session_config( @$o );
            }

            # Online-Information zurück schreiben
            $c->dbh_do('UPDATE "users" SET "lastonline"=CURRENT_TIMESTAMP WHERE "id"=? AND "hidelastseen"=0',
                $s->{userid}) unless $c->match->endpoint->name() eq 'countings';
            
            return 1; # Passt!
        }

        # Dadadummm!
        $c->logout();
        $c->set_info('');
        $c->set_error('Fehler mit der Anmeldung');
        return;
    }

    # Im Zweifelsfall zurück zur Anmeldeseite
    # Hier wird der URL-Aufruf für die Weiterleitung nach der Anmeldung gespeichert:
    $c->session->{lasturl} = $c->req->url->path_query; 
    $c->render(template => 'loginform');
    return;
}

###############################################################################
# Anmelde-Formular anzeigen
sub loginform { $_[0]->render(template => 'loginform') }

###############################################################################
# Anmeldevorgang durchführen
sub login {
    my $c = $_[0];
    my $u = $c->param('username') // '';
    my $p = $c->param('password') // '';

    if ( !$u or !$p ) { # Keine Eingaben als erstes abfangen
        $c->set_error('Bitte melden Sie sich an');
        return $c->render(template => 'loginform', status => 403);
    }

    # Anmeldeinformationen prüfen und notwendige Vorbelegungen abholen
    my $r = $c->dbh_selectall_arrayref(
        'SELECT u.name, u.id
        FROM users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND active=1',
        $u, $c->hash_password($p));
    if ( $r and @$r ) {
        # Anmeldung erfolgreich
        @{$c->session}{qw(user userid)} = @{$r->[0]}[0, 1, 2, 3, 4, 5];
        # Der Benutzer wollte direkt auf eine bestimmte URL geleitet werden
        if ( my $lasturl = $c->session->{lasturl} ) {
            undef $c->session->{lasturl};
            return $c->redirect_to($lasturl);
        }
        # Der Benutzer wird per Default auf die Startseite geleitet
        return $c->redirect_to('show');
    }
    # Die Anmeldung hat nicht funktioniert
    $c->set_error('Fehler bei der Anmeldung');
    $c->render(template => 'loginform', status => 403);
}

# Abmeldevorgang 
sub logout {
    my $c = $_[0];
    my $s = $c->session;

    # Session leeren (bis auf die userspezifischen Listenlängenangaben unter "$s->{limits}"
    delete $s->{user};
    delete $s->{userid};
    delete $s->{backgroundcolor};
    delete $s->{admin};
    delete $s->{autorefresh};
    delete $s->{chronsortorder};
    delete $s->{topiclimit};
    delete $s->{postlimit};
    delete $s->{notifications};

    # Meldungsfenster setzen und zurück zur Anmeldeseite
    $c->set_info('Abmelden erfolgreich');
    $c->render(template => 'loginform');
}

1;
