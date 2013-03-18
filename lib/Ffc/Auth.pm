package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Board;
use Ffc::Errors;

sub _form_prepare {
    my $self = shift;
    $self->stash( $_ => '' ) for qw(notecount newpostcount newmsgscount);
    $self->stash( categories => [] );
}

sub login {
    my $self = shift;
    $self->app->switch_act( $self, 'forum' );
    _form_prepare( $self );
    if ( $self->_get_relevant_data() ) {
        $self->redirect_to('show');
        return 1;
    }
    $self->login_form('Anmeldung fehlgeschlagen, Benutzername oder Passwort stimmen nicht.');
    return; 
}

sub logout {
    my $self = shift;
    $self->login_form('Abmelden bestätigt, bitte melden Sie sich erneut an');
}

sub login_form {
    my $self = shift;
    Ffc::Errors::prepare($self, 'Bitte melden Sie sich an');
    $self->app->switch_act( $self,  'auth' );
    _cancel_session( $self );
    _form_prepare( $self );
    $self->render( 'auth/loginform');
    return 0;
}

sub _cancel_session {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $session->{user};
    delete $session->{user};
    delete $session->{userid};
    return $user;
}

sub check_login {
    my $self = shift;
    if ( my $s = $self->session ) {
        if ( $s->{userid } ) {
            $self->session( expiration => $Ffc::Data::SessionTimeout );
            return 1 if $s->{userid};
        }
    }
    return 0;
}

sub _get_relevant_data {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $self->param('user');
    my $pass    = $self->param('pass');
    my @data;
    Ffc::Errors::handle( $self, sub { @data = Ffc::Data::Auth::get_userdata_for_login( $user, $pass ) }, 'Benutzername oder Passwort ungültig, bitte melden Sie sich erneut an.' );
    return unless @data;
    $self->stash( error => '' );
    %$session = (
        %$session,
        user        => $user,
        userid      => $data[0],
        lastseen    => $data[1],
        admin       => $data[2],
        show_images => $data[3],
        theme       => $data[4] // $Ffc::Data::Theme,
        act         => 'forum',
        query       => '',
        category    => undef,
    );

    return 1;
}

1;

