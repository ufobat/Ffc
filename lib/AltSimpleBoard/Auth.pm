package AltSimpleBoard::Auth;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use AltSimpleBoard::Data::Auth;
use AltSimpleBoard::Board;
# FIXME in bestimmte ecken von den subs kommt der nie nicht hin, muss mal geprüft werden

sub form_prepare {
    my $self = shift;
    $self->stash( $_ => '' ) for qw(notecount newmsgscount);
    $self->stash( $_ => [] ) for qw(newmsgs categories);
}

sub login {
    my $self = shift;
    $self->app->switch_act( $self,  'auth' );
    form_prepare( $self );
    return unless $self->get_relevant_data();
    $self->redirect_to('show');
}

sub logout {
    my $self = shift;
    my $user = $self->cancel_session();
    $self->app->switch_act( $self,  'auth' );
    form_prepare( $self );
    $self->render( 'auth/loginform',
        error => 'Abmelden bestätigt, bitte melden Sie sich erneut an' );
}

sub loginform {
    my $self = shift;
    $self->app->switch_act( $self,  'auth' );
    form_prepare( $self );
    $self->render( 'auth/loginform', error => 'Bitte melden Sie sich an' );
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
    return AltSimpleBoard::Board::init($self) if $self->check_login_status();
    $self->cancel_session();
    form_prepare( $self );
    $self->app->switch_act( $self,  'auth' );
    $self->render( 'auth/loginform',
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
        $self->app->switch_act( $self,  'auth' );
        form_prepare( $self );
        $self->render( 'auth/loginform', error => 'Anmeldung fehlgeschlagen' );
        return;
    }
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

