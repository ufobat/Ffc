package Ffc::Options; # User
use strict; use warnings; use utf8;

sub switch_theme {
    my $c = shift;
    my $s = $c->session();
    $s->{style} = $s->{style} ? 0 : 1;
    $c->set_info('Ansicht gewechselt');
    $c->options_form();
}

sub font_size {
    my $c = shift;
    my $fs = $c->param('fontsize');
    $c->session()->{fontsize} = $fs
        if defined $c->fontsize($fs);
    $c->set_info('Schriftgröße geändert');
    $c->options_form();
}

sub no_bg_color {
    my $c = shift;
    my $s = $c->session();
    delete $s->{backgroundcolor};
    $c->dbh()->do(
        'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
        undef, '', $s->{user});
    $c->set_info('Hintergrundfarbe zurückgesetzt');
    $c->options_form();
}

sub bg_color {
    my $c = shift;
    unless ( $c->configdata()->{fixbackgroundcolor} ) {
        my $bgcolor = $c->param('bgcolor');
        my $s = $c->session();
        $c->dbh()->do(
            'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
            undef, $bgcolor, $s->{user});
        $s->{backgroundcolor} = $bgcolor;
        $c->set_info('Hintergrundfarbe angepasst');
    }
    else {
        $c->set_error('Ändern der Hintergrundfarbe vom Forenadministrator deaktiviert');
    }
    $c->options_form();
}

sub set_email {
    my $c = shift;
    my $email = $c->param('email');
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
        'UPDATE users SET email=? WHERE UPPER(name)=UPPER(?)'
        , undef, $email, $c->session->{user});
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

