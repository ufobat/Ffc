package AltSimpleBoard::Auth;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Board;

sub _form_prepare {
    my $self = shift;
    $self->stash( $_ => '' ) for qw(notecount newmsgscount);
    $self->stash( categories => [] );
}

sub login {
    my $self = shift;
    $self->app->switch_act( $self, 'forum' );
    _form_prepare( $self );
    return unless $self->_get_relevant_data();
    $self->redirect_to('show');
}

sub logout {
    my $self = shift;
    $self->login_form('Abmelden bestätigt, bitte melden Sie sich erneut an');
}

sub login_form {
    my $self = shift;
    my $msg  = shift // 'Bitte melden Sie sich an';
    $self->app->switch_act( $self,  'auth' );
    _cancel_session( $self );
    _form_prepare( $self );
    $self->stash( error => $msg );
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
        return 1 if $s->{userid};
    }
    return 0;
}

sub _get_relevant_data {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $self->param('user');
    my $pass    = $self->param('pass');
    my @data    = AltSimpleBoard::Data::Auth::get_userdata_for_login( $user, $pass );
    return $self->login_form('Anmeldung fehlgeschlagen') unless @data;
    %$session = (
        %$session,
        user     => $user,
        userid   => $data[0],
        lastseen => $data[1],
        admin    => $data[2],
        act      => 'forum',
        query    => '',
        category => undef,
    );

    return 1;
}

1;

