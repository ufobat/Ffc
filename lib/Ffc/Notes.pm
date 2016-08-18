package Ffc::Notes;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes { Ffc::Plugin::Posts::install_routes_posts($_[0], 'notes', '/notes') }

sub where_select        { return 'p."userfrom"=p."userto" AND p."userfrom"=?', $_[0]->session->{userid} }
sub where_modify        { return '"userfrom"="userto" AND "userfrom"=?', $_[0]->session->{userid} }
sub additional_params   { return () }
sub show                { $_[0]->stash( heading => 'Persönliche Notizen' )->show_posts() }
sub query               { $_[0]->query_posts }
sub add                 { $_[0]->add_post($_[0]->session->{userid}, undef) }
sub edit_form           { $_[0]->stash( heading => 'Persönliche Notiz ändern')->edit_post_form() }
sub edit_do             { $_[0]->edit_post_do() }
sub delete_check        { $_[0]->stash( heading => 'Persönliche Notiz entfernen' )->delete_post_check() }
sub delete_do           { $_[0]->delete_post_do() }
sub upload_form         { $_[0]->stash( heading => 'Eine Datei zu einer persönlichen Notiz hochladen' )->upload_post_form() }
sub set_postlimit       { $_[0]->set_post_postlimit() }
sub upload_do           { $_[0]->upload_post_do() }
sub download            { $_[0]->download_post() }
sub delete_upload_check { $_[0]->stash( heading => 'Einen Dateianhang an einer Notiz entfernen' )->delete_upload_post_check() }
sub delete_upload_do    { $_[0]->delete_upload_post_do() }
sub inc_highscore       { $_[0]->show_posts() }
sub dec_highscore       { $_[0]->show_posts() }

1;
