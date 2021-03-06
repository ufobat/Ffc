package Ffc::Plugin::Posts;
use 5.18.0;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use File::Spec::Functions qw(catfile);

use Ffc::Plugin::Posts::Routes;
use Ffc::Plugin::Posts::View;
use Ffc::Plugin::Posts::Utils;
use Ffc::Plugin::Posts::Create;
use Ffc::Plugin::Posts::Delete;
use Ffc::Plugin::Posts::Uploads;
use Ffc::Plugin::Posts::Uploaddeletes;

###############################################################################
# Helper registrieren für die Verwendung in den einzelnen Teilen des Forums
sub register {
    my $app = $_[1];
    $app->helper( show_posts               => \&_show_posts               );
    $app->helper( fetch_new_posts          => \&_fetch_new_posts          );
    $app->helper( query_posts              => \&_query_posts              );
    $app->helper( search_posts             => \&_search_posts             );
    $app->helper( add_post                 => \&_add_post                 );
    $app->helper( edit_post_form           => \&_edit_post_form           );
    $app->helper( edit_post_do             => \&_edit_post_do             );
    $app->helper( delete_post_check        => \&_delete_post_check        );
    $app->helper( delete_post_do           => \&_delete_post_do           );
    $app->helper( upload_post_form         => \&_upload_post_form         );
    $app->helper( upload_post_do           => \&_upload_post_do           );
    $app->helper( download_post            => \&_download_post            );
    $app->helper( delete_upload_post_check => \&_delete_upload_post_check );
    $app->helper( delete_upload_post_do    => \&_delete_upload_post_do    );
    $app->helper( get_single_value         => \&_get_single_value         );
    $app->helper( get_show_sql             => \&_get_show_sql             );
    $app->helper( get_attachements         => \&_get_attachements         );
    $app->helper( set_post_postlimit       => \&_set_post_postlimit       );
    $app->helper( inc_post_highscore       => \&_inc_highscore            );
    $app->helper( dec_post_highscore       => \&_dec_highscore            );
    $app->helper( inc_post_highscore_ajax  => \&_inc_highscore_ajax       );
    $app->helper( dec_post_highscore_ajax  => \&_dec_highscore_ajax       );
    $app->helper( get_single_post          => \&_get_single_post          );
    $app->helper( pagination               => \&_pagination               );
    return $_[0];
}

1;

