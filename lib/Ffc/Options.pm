package Ffc::Options;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

use Ffc::Options::User;
use Ffc::Options::AdminUser;
use Ffc::Options::AdminCategories;

sub options_form {
    my $c = shift;
    $c->stash(act => 'options');
    $c->stash(fontsizes => \%Ffc::Plugin::Config::FontSizeMap);
    $c->stash(colors    => \@Ffc::Plugin::Config::Colors);
    my $r = $c->dbh->selectall_arrayref(
        'SELECT email, admin FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $c->session->{user});
    my ( $email, $admin ) = ( ( $r and ref($r) eq 'ARRAY' ) ? (@{$r->[0]}) : ('', 0) );
    $c->stash(email => $email);
    if ( $admin ) {
        $c->stash(userlist => 
            $c->dbh->selectall_arrayref(
                'SELECT u.id, u.name, u.active, u.admin FROM users u ORDER BY u.active DESC, u.name ASC'));
        $c->stash(categories => []);
    }
    else {
        $c->stash(userlist   => []);
        $c->stash(categories => []);
    }
    $c->render(template => 'board/optionsform');
}

1;

