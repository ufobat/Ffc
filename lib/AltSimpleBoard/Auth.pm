package AltSimpleBoard::Auth;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Auth;

sub login {
    my $self    = shift;
    return unless $self->get_relevant_data();
    $self->redirect_to('frontpage', act => 'forum', page => 1);
}

sub logout {
    my $self = shift;
    my $user = $self->cancel_session();
    $self->stash( act => 'auth' );
    $self->render( 'auth/login_form',
        error => 'Abmelden bestätigt, bitte melden Sie sich erneut an' );
}

sub login_form {
    my $self = shift;
    $self->stash( act => 'auth' );
    $self->render( 'auth/login_form', error => 'Bitte melden Sie sich an' );
}

sub cancel_session {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $session->{user};
    delete $session->{user};
    delete $session->{userid};
    return $user;
}

sub check_login {
    my $self = shift;
    return 1 if $self->check_login_status();
    $self->cancel_session();
    $self->render( 'auth/login_form',
        error => 'Session ungültig, melden Sie sich erneut an' );
    return;
}

sub check_login_status {
    my $session = $_[0]->session();
    return 0 unless $session;
    $session->{userid} ? 1 : 0;
}
sub get_relevant_data {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $self->param('user');
    my $pass    = $self->param('pass');
    my @data    = AltSimpleBoard::Data::Auth::get_userdata( $user, $pass );
    unless (@data) {
        $self->render( 'auth/login_form', error => 'Anmeldung fehlgeschlagen' );
        return;
    }
    %$session = (
        %$session,
        user     => $user,
        userid   => $data[0],
        lastseen => $data[1],
        query    => '',
    );

    return 1;
}

1;

