package Ffc::Options;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Options::Routes;
use Ffc::Options::User;
use Ffc::Options::AdminUser;
use Ffc::Options::AdminBoardsettings;

sub check_admin {
    my $c = shift;
    unless ( $c->session->{admin} ) {
        $c->set_error_f('Nur Administratoren dürfen das');
        $c->redirect_to('options_form');
        return;
    }
    return 1;
}

sub options_form {
    my $c = shift;
    $c->stash(fontsizes => \%Ffc::Plugin::Config::FontSizeMap);
    $c->counting;
    my $r = $c->dbh_selectall_arrayref(
        'SELECT email, newsmail, hideemail, birthdate, infos, hidelastseen FROM users WHERE id=?'
        , $c->session->{userid});
    $r = 'ARRAY' eq ref $r ? $r->[0] : [];
    $c->stash(
        email        => $r->[0],
        newsmail     => $r->[1],
        hideemail    => $r->[2],
        birthdate    => $c->stash('birthdate') // $r->[3],
        infos        => $c->stash('infos') // $r->[4],
        hidelastseen => $r->[5],
    );
    $c->render(template => 'optionsform');
}

sub admin_options_form {
    my $c = shift;
    $c->counting;
    my $userlist = $c->dbh_selectall_arrayref(
            'SELECT u.id, u.name, u.active, u.admin, u.email FROM users u WHERE UPPER(u.name) != UPPER(?) ORDER BY UPPER(u.name) ASC'
            , $c->session->{user});
    my $themes = $c->dbh_selectall_arrayref(
            'SELECT "id", SUBSTR("title", 0, ?) FROM "topics" ORDER BY UPPER("title")'
             , $c->configdata->{urlshorten});
    $c->stash(
        useremails    => join( '; ', map { $_->[4] || () } @$userlist ),
        userlist      => $userlist,
        configoptions => \@Ffc::Options::Settings,
        themes        => $themes,
    );
    $c->render(template => 'adminform');
}

1;

