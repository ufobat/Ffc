package Ffc::Auth;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes {
    my $r = $_[0];
    # Anmeldehandling und Anmeldeprüfung
    $r->post('/login')->to('auth#login')->name('login');
    $r->get('/logout')->to('auth#logout')->name('logout');
    return $r->under('/')
             ->to('auth#check_login')
             ->name('login_check');
}

sub check_login {
    my $c = shift;
    if ( $c->login_ok ) {
        my $s = $c->session();
        my $r = $c->dbh()->selectall_arrayref(
            'SELECT u.admin, u.bgcolor, u.id, u.autorefresh, u.chronsortorder
            FROM users u WHERE u.active=1 AND u.name=?',
            undef, $s->{user});

        if ( $r and @$r and $r->[0]->[2] == $s->{userid} ) {
            $s->{admin}           = $r->[0]->[0];
            $s->{backgroundcolor} = $r->[0]->[1];
            $s->{autorefresh}     = $r->[0]->[3];
            $s->{chronsortorder}   = $r->[0]->[4];
            return 1;
        }
        else {
            $c->logout();
            $c->set_info('');
            $c->set_error('Fehler mit der Anmeldung');
            return;
        }
    }
    $c->render(template => 'loginform');
    return;
}

sub login {
    my $c = shift;
    my $u = $c->param('username') // '';
    my $p = $c->param('password') // '';
    if ( !$u or !$p ) {
        $c->set_error('Bitte melden Sie sich an');
        return $c->render(template => 'loginform');
    }
    my $r = $c->dbh()->selectall_arrayref(
        'SELECT u.admin, u.bgcolor, u.name, u.id, u.autorefresh, u.chronsortorder
        FROM users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND active=1',
        undef, $u, $c->hash_password($p));
    if ( $r and @$r ) {
        my $s = $c->session();
        $s->{admin}           = $r->[0]->[0];
        $s->{backgroundcolor} = $r->[0]->[1];
        $s->{user}            = $r->[0]->[2];
        $s->{userid}          = $r->[0]->[3];
        $s->{autorefresh}     = $r->[0]->[4];
        $s->{cronsortorder}   = $r->[0]->[5];
        return $c->redirect_to('show');
    }
    $c->set_error('Fehler bei der Anmeldung');
    $c->render(template => 'loginform');
}

sub logout {
    my $c = shift;
    my $s = $c->session;
    delete $s->{user};
    delete $s->{userid};
    delete $s->{backgroundcolor};
    delete $s->{admin};
    delete $s->{autorefresh};
    delete $s->{chronsortorder};
    $c->set_info('Abmelden erfolgreich');
    $c->render(template => 'loginform');
}

1;

