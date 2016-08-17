package Ffc::Options; # AdminUser
use 5.18.0;
use strict; use warnings; use utf8;

sub useradmin {
    my $c        = shift;
    my $admin    = $c->session()->{user};

    my $username = $c->param('username');
    my $newpw1   = $c->param('newpw1');
    my $newpw2   = $c->param('newpw2');
    my $isadmin  = $c->param('admin')  ? 1 : 0;
    my $isactive = $c->param('active') ? 1 : 0;
    my $overok   = $c->param('overwriteok');

    unless ( $username ) {
        $c->set_error_f('Benutzername nicht angegeben');
        return $c->redirect_to('admin_options_form');
    }
    if ( $username !~ m/\A$Ffc::Usrqr\z/xmso) {
        $c->set_error_f('Benutzername passt nicht (muss zwischen 2 und 32 Buchstaben haben)');
        return $c->redirect_to('admin_options_form');
    }
    if ( $newpw1 and $newpw2 and $newpw1 ne $newpw2 ) {
        $c->set_error_f('Passworte stimmen nicht überein');
        return $c->redirect_to('admin_options_form');
    }

    my $exists = $c->dbh_selectall_arrayref(
        'SELECT COUNT(id) FROM users WHERE UPPER(name) = UPPER(?)'
        , $username)->[0]->[0];

    if ( $exists and not $overok ) {
        $c->set_error_f('Benutzer existiert bereits, das Überschreiben-Häkchen ist allerdings nicht gesetzt');
        return $c->redirect_to('admin_options_form');
    }
    unless ( $exists or ( $newpw1 and $newpw2 ) ) {
        $c->set_error_f('Neuen Benutzern muss ein Passwort gesetzt werden');
        return $c->redirect_to('admin_options_form');
    }

    my @pw = ( $newpw1 ? $c->hash_password($newpw1) : () );
    if ( $exists ) {
        my $sql = 'UPDATE users SET active=?, admin=?';
        $sql .= ', password=?' if @pw;
        $sql .= ' WHERE UPPER(name)=UPPER(?)';
        $c->dbh_do($sql, $isactive, $isadmin, @pw, $username);
        $c->set_info_f(qq~Benutzer "$username" geändert~);
    }
    else {
        $c->dbh_do(
            'INSERT INTO users (name, password, active, admin) VALUES (?,?,?,?)'
            , $username, @pw, $isactive, $isadmin);
        $c->set_info_f(qq~Benutzer "$username" angelegt~);
    }

    $c->redirect_to('admin_options_form');
}

1;

