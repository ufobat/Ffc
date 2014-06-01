package Ffc::Routes::Forum;
use strict; use warnings; use utf8;
use Ffc::Routes::Uploads;

sub install_routes_forum {
    my $l = $_[0];
    $l->get('/forum')->to('forum#show')->name('show_forum');
}

1;

