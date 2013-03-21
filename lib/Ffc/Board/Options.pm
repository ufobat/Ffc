package Ffc::Board::Options;

use 5.010;
use strict;
use warnings;
use utf8;

use Mojo::Base 'Ffc::Board::Errors';

use Ffc::Data::Auth;
use Ffc::Data::General;
use Ffc::Data::Board::OptionsUser;
use Ffc::Data::Board::OptionsAdmin;

sub options_form {
    my $c = shift;
    my $s = $c->session;
    $c->error_prepare;
    my $email;
    $c->error_handling( sub { $email = Ffc::Data::General::get_useremail($s->{userid}) } );
    my $userlist;
    $c->error_handling( sub { $userlist = Ffc::Data::General::get_userlist() });
    $c->stash(email    => $email // '');
    $c->stash(userlist => $userlist // '' );
    $c->stash(themes => \@Ffc::Data::Themes);
    delete $s->{msgs_userid}; delete $s->{msgs_username};
    $c->get_counts();
    $c->app->switch_act( $c, 'options' );
    $c->render('board/optionsform');
}

sub options_save {
    my $c = shift;
    my $s = $c->session;
    my $email       = $c->param('email');
    my $oldpw       = $c->param('oldpw');
    my $newpw1      = $c->param('newpw1');
    my $newpw2      = $c->param('newpw2');
    my $show_images = $c->param('show_images') || 0;
    my $theme       = $c->param('theme');
    $c->error_handling( sub { Ffc::Data::Board::OptionsUser::update_email($s->{userid}, $email) } ) 
        if $email;
    $c->error_handling( sub { Ffc::Data::Board::OptionsUser::update_password($s->{userid}, $oldpw, $newpw1, $newpw2) } ) 
        if $oldpw and $newpw1 and $newpw2;
    $c->error_handling( sub { Ffc::Data::Board::OptionsUser::update_theme($s, $theme) } ) 
        if $theme;
    $c->error_handling( sub { Ffc::Data::Board::OptionsUser::update_show_images($s, $show_images) } );
    $c->options_form();
}

sub useradmin_save {
    my $c = shift;
    my $adminuid = $c->session()->{userid};
    my $username = $c->param('username');
    if ( $c->error_handling( {
            code => sub { die 'Angemeldeter Benutzer ist kein Administrator' unless Ffc::Data::Auth::is_user_admin($adminuid) },
            msg => q{Angemeldeter Benutzer ist kein Admin und darf das hier garnicht},
        } ) ) {
        my $userid  = $c->or_undef( sub { Ffc::Data::General::get_userid($username) } );
        my $newpw1  = $c->param('newpw1');
        my $newpw2  = $c->param('newpw2');
        my $admin   = $c->param('admin');
        my $active  = $c->param('active');
        if ( defined $userid ) {
            if ( $c->param('overwriteok') ) {
                $c->error_handling( sub { 
                    Ffc::Data::Board::OptionsAdmin::admin_update_password( $adminuid, $userid, $newpw1, $newpw2 )
                } ) if $newpw1 and $newpw2;
                $c->error_handling( sub { 
                    Ffc::Data::Board::OptionsAdmin::admin_update_active( $adminuid, $userid, $active )
                } );
                $c->error_handling( sub { 
                    Ffc::Data::Board::OptionsAdmin::admin_update_admin( $adminuid, $userid, $admin )
                } );
            }
            else {
                $c->error_handling( { plain => '"Überschreiben"-Option muss angekreuzt werden, wesche de Sischeheit!' } );
            }
        }
        else {
            $c->error_handling( sub {
                Ffc::Data::Board::OptionsAdmin::admin_create_user( $adminuid, $username, $newpw1, $newpw2, $active, $admin )
            } );
        }
    }
    $c->options_form();
}

1;

