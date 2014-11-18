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
    $c->stash(fontsizes => \%Ffc::Plugin::Config::FontSizeMap);
    $c->counting;
    my $r = $c->dbh->selectall_arrayref(
        'SELECT email, admin, newsmail FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $c->session->{user});
    my ( $email, $admin, $newsmail ) = ( ( $r and ref($r) eq 'ARRAY' ) ? (@{$r->[0]}) : ('', 0) );
    $c->stash(
        email    => $email,
        newsmail => $newsmail,
    );
    if ( $admin ) {
        my $userlist = $c->dbh->selectall_arrayref(
                'SELECT u.id, u.name, u.active, u.admin, u.email FROM users u WHERE UPPER(u.name) != UPPER(?) ORDER BY UPPER(u.name) ASC'
                , undef, $c->session->{user});
        my $themes = $c->dbh->selectall_arrayref(
                'SELECT "id", SUBSTR("title", 0, ?) FROM "topics" ORDER BY UPPER("title")'
                 , undef, $c->configdata->{urlshorten});
        $c->stash(
            useremails    => join( '; ', map { $_->[4] || () } @$userlist ),
            userlist      => $userlist,
            configoptions => \@Ffc::Options::Settings,
            configdata    => $c->configdata,
            themes        => $themes,
        );
    }
    else {
        $c->stash(
            useremails    => '',
            userlist      => [],
            configoptions => [],
            configdata    => {},
            themes        => [],
        );
    }
    $c->render(template => 'optionsform');
}

1;

