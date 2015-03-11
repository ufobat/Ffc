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
            'SELECT u.admin, u.bgcolor, u.name, u.autorefresh, 
                u.chronsortorder, u.topiclimit, u.postlimit
            FROM users u WHERE u.active=1 AND u.id=?',
            undef, $s->{userid});

        if ( $r and @$r and $r->[0]->[2] eq $s->{user} ) {
            @$s{qw(admin backgroundcolor autorefresh chronsortorder topiclimit postlimit)}
                = @{$r->[0]}[0, 1, 3, 4, 5, 6];
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
        'SELECT u.admin, u.bgcolor, u.name, u.id, u.autorefresh, 
            u.chronsortorder, u.topiclimit, u.postlimit
        FROM users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND active=1',
        undef, $u, $c->hash_password($p));
    if ( $r and @$r ) {
        @{$c->session}{qw(admin backgroundcolor user userid autorefresh chronsortorder topiclimit postlimit)}
            = @{$r->[0]}[0, 1, 2, 3, 4, 5, 6, 7];
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
    delete $s->{topiclimit};
    delete $s->{postlimit};
    $c->set_info('Abmelden erfolgreich');
    $c->render(template => 'loginform');
}

1;

