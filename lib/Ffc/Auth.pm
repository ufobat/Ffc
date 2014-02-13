package Ffc::Auth;
use Mojo::Base 'Mojolicious::Controller';
use utf8;
use Ffc::Board;
use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Errors;

sub login {
    my $self = shift;
    if ( $self->_get_relevant_data() ) {
        $self->redirect_to('show');
        return 1;
    }
    login_form($self, 'Anmeldung fehlgeschlagen, Benutzername oder Passwort stimmen nicht.');
    return; 
}

sub logout {
    my $self = shift;
    my $msg = shift || 'Abmelden bestätigt, bitte melden Sie sich erneut an';
    my $s = $self->session;
    delete $s->{$_} for keys %$s;
    login_form($self, $msg);
}

sub login_form {
    my $self = shift;
    my $msg = shift || 'Bitte melden Sie sich an';
    _cancel_session( $self );
    $self->stash(error => $msg);
    $self->render( 'auth/loginform');
    return 0;
}

sub _cancel_session {
    my $self    = shift;
    my $session = $self->session;
    my $user    = $session->{user};
    delete $session->{user};
    return $user;
}

sub check_login {
    my $self = shift;
    if ( my $s = $self->session ) {
        if ( $s->{user} ) {
            $self->session( expiration => $Ffc::Data::SessionTimeout );
            return _set_settings($self);
        }
    }
    return 0;
}

sub _set_settings {
    my $self = shift;
    my $s    = $self->session();
    my $user = $s->{user};
    my @settings; # = Ffc::Data::Auth::get_usersettings( $user );
    Ffc::Errors::handle( $self, sub { @settings = Ffc::Data::Auth::get_usersettings( $user ) }, 'Benutzereinstellungen konnten nicht ermittelt werden, bitte melden Sie sich erneut an.' );
    return 0 unless @settings;
    $s->{admin}       = $settings[0],
    $s->{show_images} = $settings[1],
    $s->{theme}       = $settings[2] || $Ffc::Data::Theme,
    $s->{bgcolor}     = $settings[3] || $Ffc::Data::BgColor // '',
    $s->{fontsize}    = $settings[4],
    return 1;
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
        user        => $data[1],
        act         => 'forum',
        query       => '',
        category    => undef,
    );
    return $self->_set_settings() ? 1 : 0;
}

sub session_data_json {
    my $c = shift;
    $c->render( json => $c->session() );
}

1;

