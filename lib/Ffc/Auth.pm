package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';

sub check_login {
    my $c = shift;
    return 1 if $c->login_ok;
    $c->render(template => 'auth/loginform');
    return;
}

sub login {
    my $c = shift;
    my $u = $c->param('username') // '';
    my $p = $c->param('password') // '';
    if ( !$u or !$p ) {
        $c->stash(error => 'Bitte melden Sie sich an');
        return $c->render(template => 'auth/loginform');
    }
    my $r = $c->dbh()->selectall_arrayref(
        'SELECT u.admin, u.show_images, u.bgcolor
        FROM users u WHERE UPPER(u.name)=UPPER(?) and u.password=?',
        undef, $u, $c->password($p));
    if ( $r and @$r ) {
        my $s = $c->session();
        $s->{admin}           = $r->[0]->[0];
        $s->{show_images}     = $r->[0]->[1];
        $s->{backgroundcolor} = $r->[0]->[2];
        $s->{user}            = $u;
        return $c->redirect_to('show');
    }
    $c->stash(error => 'Fehler bei der Anmeldung: '.$c->password($p));
    $c->render(template => 'auth/loginform');
}

sub logout {
    my $c = shift;
    my $s = $c->session();
    delete $s->{$_} for keys %$s;
    $c->stash(error => '');
    $c->stash(info => 'Abmelden erfolgreich');
    $c->render(template => 'auth/loginform');
}

sub add_user {
    my ( $c, $n, $p, $a ) = @_;
    $c->dbh()->do(
        'INSERT INTO users (name, password, admin) VALUES (?,?,?)',
        undef, $n, $c->password($p), ( $a ? 1 : 0 ) );
}

1;

