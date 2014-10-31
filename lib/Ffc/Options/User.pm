package Ffc::Options; # User
use strict; use warnings; use utf8;

sub set_autorefresh {
    my $c = $_[0];
    my $ar = $c->param('refresh') // '';
    if ( $ar =~ m/(\d+)/xms ) {
        $ar = $1;
    }
    else {
        $c->set_error('Automatisches Neuladen der Seite konnte nicht geändert werden');
        return $c->options_form();
    }
    $c->session->{autorefresh} = $ar;
    $c->dbh->do('UPDATE "users" SET "autorefresh"=? WHERE "id"=?',
        undef, $ar, $c->session->{userid});
    $c->set_info( 'Automatisches Neuladen der Seite '. (
        $ar ? 'auf '.$ar.' Minuten eingestellt' : 'deaktiviert' ) );
    $c->options_form();
}

sub no_bg_color {
    my $c = shift;
    my $s = $c->session();
    delete $s->{backgroundcolor};
    $c->dbh()->do(
        'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
        undef, '', $s->{user});
    $c->set_info('Hintergrundfarbe zurück gesetzt');
    $c->options_form();
}

sub bg_color {
    my $c = shift;
    my $bgcolor = $c->param('bgcolor') // '';
    if ( $bgcolor !~ qr(\A(?:|\#[0-9a-f]{6}|\w{2,128})\z)xmsio ) {
        $c->set_error('Die Hintergrundfarbe für die Webseite muss in hexadezimaler Schreibweise mit führender Raute oder als Webfarbenname angegeben werden');
        $c->set_warning($bgcolor);
    }
    elsif ( $c->configdata()->{fixbackgroundcolor} ) {
        $c->set_error('Ändern der Hintergrundfarbe vom Forenadministrator deaktiviert');
    }
    else {
        my $s = $c->session();
        $c->dbh()->do(
            'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
            undef, $bgcolor, $s->{user});
        $s->{backgroundcolor} = $bgcolor;
        if ( $bgcolor ) {
            $c->set_info('Hintergrundfarbe angepasst');
        }
        else {
            $c->set_info('Hintergrundfarbe zurück gesetzt');
        }
    }
    $c->options_form();
}

sub set_email {
    my $c = shift;
    my $email = $c->param('email');
    my $newsmail = $c->param('newsmail') ? 1 : 0;
    unless ( $email ) {
        $c->set_error('Email-Adresse nicht gesetzt');
        return $c->options_form();
    }
    if ( 1024 < length $email ) {
        $c->set_error('Email-Adresse darf maximal 1024 Zeichen lang sein');
        return $c->options_form();
    }
    unless ( $email =~ m/.+\@.+\.\w+/xmso ) {
        $c->set_error('Email-Adresse sieht komisch aus');
        return $c->options_form();
    }
    $c->dbh->do(
        'UPDATE users SET email=?, newsmail=? WHERE UPPER(name)=UPPER(?)'
        , undef, $email, $newsmail, $c->session->{user});
    $c->set_info('Email-Adresse geändert');
    $c->options_form();
}

sub set_password {
    my $c = shift;
    my $opw  = $c->param('oldpw');
    my $npw1 = $c->param('newpw1');
    my $npw2 = $c->param('newpw2');

    unless ( $opw ) {
        $c->set_error('Altes Passwort nicht angegeben');
        return $c->options_form();
    }
    unless ( $npw1 and $npw2 ) {
        $c->set_error('Neues Passwort nicht angegeben');
        return $c->options_form();
    }
    if ( $npw1 ne $npw2 ) {
        $c->set_error('Neue Passworte stimmen nicht überein');
        return $c->options_form();
    }

    my $u = $c->session->{user};
    my $p = $c->hash_password($npw1);

    $c->dbh->do(
        'UPDATE users SET password=? WHERE UPPER(name)=UPPER(?) AND password=?'
        , undef, $p, $u, $c->hash_password($opw));

    my $i = $c->dbh->selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name)=UPPER(?) AND password=?'
        , undef, $u, $p)->[0]->[0];

    if ( $i ) {
        $c->set_info('Passwortwechsel erfolgreich');
    }
    else {
        $c->set_error('Passwortwechsel fehlgeschlagen')
    }

    $c->options_form();
}

1;

