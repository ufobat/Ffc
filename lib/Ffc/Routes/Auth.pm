package Ffc::Routes::Auth;
use strict; use warnings; use utf8;

sub install_routes_auth {
    my $r = $_[0];
    # Anmeldehandling und Anmeldeprüfung
    $r->post('/login')->to('auth#login')->name('login');
    $r->get('/logout')->to('auth#logout')->name('logout');
    return $r->bridge('/')
             ->to('auth#check_login')
             ->name('login_check');
}

1;

