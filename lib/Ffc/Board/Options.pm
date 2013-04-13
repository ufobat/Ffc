package Ffc::Board::Options;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Ffc::Data::Auth;
use Ffc::Data::General;
use Ffc::Data::Board::OptionsUser;
use Ffc::Data::Board::OptionsAdmin;

sub _check_username { &Ffc::Data::Auth::check_username }
sub _is_user_admin { Ffc::Data::Auth::is_user_admin( Ffc::Data::Auth::get_userid( @_ ) ) }

sub options_form {
    my $c = shift;
    my $s = $c->session;
    $c->error_prepare;
    my $email;
    $c->error_handling(
        sub { $email = Ffc::Data::General::get_useremail( $s->{user} ) } );
    my $userlist;
    $c->error_handling( sub { $userlist = Ffc::Data::General::get_userlist() }
    );
    $c->stash( email    => $email    // '' );
    $c->stash( userlist => $userlist // '' );
    $c->stash( themes   => \@Ffc::Data::Themes );
    delete $s->{msgs_username};
    $c->get_counts();
    $c->app->switch_act( $c, 'options' );
    $c->render('board/optionsform');
}

sub options_save {
    my $c           = shift;
    my $s           = $c->session;
    my $email       = $c->param('email');
    my $oldpw       = $c->param('oldpw');
    my $newpw1      = $c->param('newpw1');
    my $newpw2      = $c->param('newpw2');
    my $show_images = $c->param('show_images') || 0;
    my $theme       = $c->param('theme');
    $c->error_handling(
        sub {
            Ffc::Data::Board::OptionsUser::update_email( $s->{user}, $email );
        }
    ) if $email;
    $c->error_handling(
        sub {
            Ffc::Data::Board::OptionsUser::update_password( $s->{user},
                $oldpw, $newpw1, $newpw2 );
        }
      )
      if $oldpw
      and $newpw1
      and $newpw2;
    $c->error_handling(
        sub { Ffc::Data::Board::OptionsUser::update_theme( $s, $theme ) } )
      if $theme;
    $c->error_handling(
        sub {
            Ffc::Data::Board::OptionsUser::update_show_images( $s,
                $show_images );
        }
    );
    $c->options_form();
}

sub useradmin_save {
    my $c        = shift;
    my $admin    = $c->session()->{user};
    my $username = $c->param('username');
    my $newpw1   = $c->param('newpw1');
    my $newpw2   = $c->param('newpw2');
    my $isadmin  = $c->param('admin')  ? 1 : 0;
    my $active   = $c->param('active') ? 1 : 0;
    if ( not _is_user_admin( $admin ) ) {
        $c->error_handling({plain => 'Nur Administratoren dürfen dass'});
    }
    elsif ( _check_username( $username ) ) {

        if ( $c->param('overwriteok') ) {
            $c->error_handling(
                sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_password(
                        $admin, $username, $newpw1, $newpw2 );
                }
              ) if $newpw1
              and $newpw2;
            $c->error_handling(
                sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_active( $admin,
                        $username, $active );
                }
            );
            $c->error_handling(
                sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_admin( $admin,
                        $username, $isadmin );
                }
            );
        }
        else {
            $c->error_handling(
                {
                    plain =>
'"Überschreiben"-Option muss angekreuzt werden, wesche de Sischeheit!'
                }
            );
        }
    }
    else {
        $c->error_handling(
            sub {
                Ffc::Data::Board::OptionsAdmin::admin_create_user( $admin,
                    $username, $newpw1, $newpw2, $active, $isadmin );
            }
        );
    }
    $c->options_form();
}

1;

