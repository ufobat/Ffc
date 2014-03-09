package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';

sub check_login {
    my $c = shift;
    if ( $c->login_ok ) {
        my $s = $c->session();
        my $r = $c->dbh()->selectall_arrayref(
            'SELECT u.admin, u.show_images, u.bgcolor
            FROM users u WHERE UPPER(u.name)=UPPER(?) AND active=1',
            undef, $s->{user});

        if ( $r and @$r ) {
            $s->{admin}           = $r->[0]->[0];
            $s->{show_images}     = $r->[0]->[1];
            $s->{backgroundcolor} = $r->[0]->[2];
            return 1;
        }
        else {
            $c->logout();
            $c->set_info('');
            $c->set_error('Fehler mit der Anmeldung');
            return;
        }
    }
    $c->render(template => 'auth/loginform');
    return;
}

sub login {
    my $c = shift;
    my $u = $c->param('username') // '';
    my $p = $c->param('password') // '';
    if ( !$u or !$p ) {
        $c->set_error('Bitte melden Sie sich an');
        return $c->render(template => 'auth/loginform');
    }
    my $r = $c->dbh()->selectall_arrayref(
        'SELECT u.admin, u.show_images, u.bgcolor
        FROM users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND active=1',
        undef, $u, $c->hash_password($p));
    if ( $r and @$r ) {
        my $s = $c->session();
        $s->{admin}           = $r->[0]->[0];
        $s->{show_images}     = $r->[0]->[1];
        $s->{backgroundcolor} = $r->[0]->[2];
        $s->{user}            = $u;
        return $c->redirect_to('show');
    }
    $c->set_error('Fehler bei der Anmeldung');
    $c->render(template => 'auth/loginform');
}

sub logout {
    my $c = shift;
    my $s = $c->session;
    delete $s->{$_} for keys %$s;
    $c->set_info('Abmelden erfolgreich');
    $c->render(template => 'auth/loginform');
}

sub add_user {
    my ( $c, $n, $p, $a ) = @_;
    $c->dbh()->do(
        'INSERT INTO users (name, password, admin) VALUES (?,?,?)',
        undef, $n, $c->password($p), ( $a ? 1 : 0 ) );
}

1;

