package AltSimpleBoard::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'md5_sum';
use utf8;
use AltSimpleBoard::Data::Auth;

sub login {
    my $self    = shift;
    my $session = $self->session;

    if ( $self->check_login_status() ) {
        return unless $self->get_relevant_data();
    }
    else {
        return unless $self->get_relevant_data();
        AltSimpleBoard::Data::Auth::update_usersession( "$session", $session->{user} );
    }

    $self->render('frontpage');
}

sub logout {
    my $self = shift;
    my $user = $self->cancel_session();
    AltSimpleBoard::Data::Auth::logout($user) if $user;
    $self->render( 'login_form',
        error => 'Abmelden bestätigt, bitte melden Sie sich erneut an' );
}

sub login_form {
    my $self = shift;
    $self->render( 'login_form', error => 'Bitte melden Sie sich an' );
}

sub cancel_session {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $session->{user};
    delete $session->{user};
    delete $session->{pass};
    delete $session->{userid};
    return $user;
}

sub check_login {
    my $self = shift;
    return 1 if $self->check_login_status();
    $self->cancel_session();
    $self->render( 'login_form',
        error => 'Session ungültig, melden Sie sich erneut an' );
    return;
}

sub check_login_status {
    my $user = $_[0]->session()->{user};
    $user and AltSimpleBoard::Data::Auth::check_login_status($user) ? 1 : 0;
}

1;

