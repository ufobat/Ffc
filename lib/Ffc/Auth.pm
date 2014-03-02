package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';

sub check_login {
    my $c = shift;
    return 1 if $c->session()->{user};
    $c->render(template => 'auth/loginform');
    return;
}

sub login {
    my $c = shift;
    my $u = $c->param('username');
    my $p = $c->param('password');
    return $c->render(template => 'auth/loginform') unless $u and $p;
    my $r = $c->dbh()->selectall_arrayref(
        'SELECT u.admin, u.show_images, u.bgcolor
        FROM users u WHERE u.id=? and u.password=?',
        undef, $u, $c->password($p));
    if ( @$r ) {
        my $s = $c->session();
        $s->{admin}           = $r->[0]->[0];
        $s->{show_images}     = $r->[0]->[1];
        $s->{backgroundcolor} = $r->[0]->[2];
        $s->{user}            = $u;
        return $c->redirect_to('show');
    }
    $c->stash(error => 'Fehler bei der Anmeldung');
    $c->render(template => 'auth/loginform');
}

sub logout {
    my $c = shift;
    my $s = $c->session();
    delete $s->{$_} for keys %$s;
    $c->render(template => 'auth/loginform');
}

sub add_user {
    my ( $c, $n, $p, $a ) = @_;
    Ffc::Config::Dbh()->do(
        'INSERT INTO users (name, password, admin) VALUES (?,?,?)',
        undef, $n, $c->password($p), ( $a ? 1 : 0 ) );
}

1;

