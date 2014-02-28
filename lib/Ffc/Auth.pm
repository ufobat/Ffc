package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Digest::SHA 'sha512_base64';

sub password { sha512_base64 $_[0], Ffc::Config()->{cryptsalt} }

sub check_login {
    return shift()->session()->{user} ? 1 : 0;
}

sub login {
    my $c = shift;
    my $u = $c->param('username');
    my $p = $c->param('password');
    return $c->redirect_to('login_form') unless $u and $p;
    my $r = FFc::Dbh()->selectall_arrayref(
        'SELECT u.admin, u.show_images, u.theme, u.bgcolor, u.fontsize FROM users u WHERE u.id=? and u.password=?'
        undef, $u, $p);
    if ( @$r ) {
        return $c->redirect_to('show_forum');
    }
    else {
        $c->flash(error => 'Fehler bei der Anmeldung, bitte versuchen Sie es erneut');
        return $c->redirect_to('login_form');
    }
}

sub logout {
    my $c = shift;
    my $s = $c->session();
    delete $s->{$_} for keys %$s;
    $c->redirect_to('login_form');
}

sub login_form {
    my $c = shift;
    my $cfg = Ffc::Config();
}

1;

