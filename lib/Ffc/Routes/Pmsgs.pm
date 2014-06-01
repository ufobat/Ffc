package Ffc::Routes::Pmsgs;
use strict; use warnings; use utf8;

sub install_routes_pmsgs {
    my $l = $_[0];
    $l->get('/pmsgs')->to('pmsgs#show')->name('show_pmsgs');
}

1;

