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
    return $c->redirect_to('login_form') unless $u and $p;
    my $r = $c->dbh()->selectall_arrayref(
        'SELECT u.admin, u.show_images, u.theme, u.bgcolor, u.fontsize FROM users u WHERE u.id=? and u.password=?',
        undef, $u, $c->password($p));
    if ( @$r ) {
        return $c->redirect_to('show');
    }
    $c->flash(error => 'Fehler bei der Anmeldung, bitte versuchen Sie es erneut');
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

