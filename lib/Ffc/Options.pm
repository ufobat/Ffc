package Ffc::Options;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Options::Routes;
use Ffc::Options::User;
use Ffc::Options::AdminUser;
use Ffc::Options::AdminBoardsettings;

sub check_admin {
    my $c = shift;
    unless ( $c->session->{admin} ) {
        $c->set_error('Nur Administratoren dürfen das');
        $c->options_form();
        return;
    }
    return 1;
}

sub options_form {
    my $c = shift;
    $c->stash(act => 'options');
    $c->stash(fontsizes => \%Ffc::Plugin::Config::FontSizeMap);
    my $r = $c->dbh->selectall_arrayref(
        'SELECT email, admin FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $c->session->{user});
    my ( $email, $admin ) = ( ( $r and ref($r) eq 'ARRAY' ) ? (@{$r->[0]}) : ('', 0) );
    $c->stash(email => $email);
    if ( $admin ) {
        my $userlist = $c->dbh->selectall_arrayref(
                'SELECT u.id, u.name, u.active, u.admin, u.email FROM users u WHERE UPPER(u.name) != UPPER(?) ORDER BY UPPER(u.name) ASC'
                , undef, $c->session->{user});
        $c->stash(useremails => join ';', map { $_->[4] || () } @$userlist );
        $c->stash(userlist => $userlist);
        $c->stash(configoptions => \@Ffc::Options::Settings);
        $c->stash(configdata => $c->configdata);
    }
    else {
        $c->stash(useremails    => '');
        $c->stash(userlist      => []);
        $c->stash(configoptions => []);
        $c->stash(configdata    => {});
    }
    $c->render(template => 'optionsform');
}

1;

