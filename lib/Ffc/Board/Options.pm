package Ffc::Board::Options;

use 5.010;
use strict;
use warnings;
use utf8;

use base 'Ffc::Board::Errors';

use Ffc::Data::Auth;
use Ffc::Data::General;
use Ffc::Data::Board::Views;
use Ffc::Data::Board::Avatars;
use Ffc::Data::Board::OptionsUser;
use Ffc::Data::Board::OptionsAdmin;

use Ffc::Board::Views;

sub _check_user_exists { &Ffc::Data::Auth::check_user_exists }
sub _is_user_admin { Ffc::Data::Auth::is_user_admin( Ffc::Data::Auth::get_userid( @_ ) ) }

sub options_form {
    my $c = shift;
    my $s = $c->session;

    my $email;
    $c->error_handling(
        sub { $email = Ffc::Data::General::get_useremail( $s->{user} ) } );
    my $userlist;
    $c->error_handling( sub { $userlist = Ffc::Data::General::get_userlist() }
    );
    $c->stash( email      => $email    // '' );
    $c->stash( userlist   => $userlist // '' );
    $c->stash( themes     => \@Ffc::Data::Themes );
    $c->stash( act        => 'options' );
    $c->stash( categories => Ffc::Data::Board::Views::get_all_categories($s->{user}) );
    $c->get_counts();
    $c->render('board/optionsform');
}

sub options_email_save {
    my $c     = shift;
    my $email = $c->param('email');
    $c->error_handling({
        code => sub {
            Ffc::Data::Board::OptionsUser::update_email( $c->session->{user}, $email );
        },
        after_ok => sub { $c->info_stash('Email-Adresse geändert') },
        msg => 'Die Emailadresse konnte nicht geändert werden, eventuell ist sie ungültig',
    });
    $c->options_form();
}

sub options_password_save {
    my $c      = shift;
    my $oldpw  = $c->param('oldpw');
    my $newpw1 = $c->param('newpw1');
    my $newpw2 = $c->param('newpw2');
    $c->error_handling({
        code => sub {
            Ffc::Data::Board::OptionsUser::update_password( $c->session->{user},
                $oldpw, $newpw1, $newpw2 );
        },
        after_ok => sub { $c->info_stash('Passwort geändert') },
        msg => 'Das Passwort konnte nicht geändert werden. Entweder stimmt das alte Passwort nicht, was zur Bestätigung angegeben werden muss oder ist das neue Passwort ungültig (muss zwischen 8 und 64 Zeichen lang sein und darf keine Leerzeichen enthalten). Eventuell stimmt das neue Passwort auch mit dessen Wiederholung nicht überein',
      });
    $c->options_form();
}

sub options_theme_save {
    my $c     = shift;
    my $theme = $c->param('theme');

    $c->error_handling({
        code => sub { Ffc::Data::Board::OptionsUser::update_theme( $c->session, $theme ) },
        after_ok => sub { $c->info_stash('Thema geändert') },
        msg => 'Das Thema konnte nicht geändert werden, vielleicht ist es ein ungültiges oder nicht verfügbares Thema',
    });
    $c->options_form();
}

sub options_showimages_save {
    my $c           = shift;
    my $show_images = $c->param('show_images');
    $c->error_handling({
        code => sub {
            Ffc::Data::Board::OptionsUser::update_show_images( $c->session, $show_images ? 1 : 0 );
        },
        after_ok => sub { $c->info_stash('Bilderanzeige geändert') },
        msg => 'Das Ändern der Bildanzeige ist fehlgeschlagen',
    });
    $c->options_form();
}

sub options_avatar_save {
    my $c          = shift;
    my $avatarfile = $c->param('avatarfile');
    $c->error_handling(
        {
            code => sub {
                Ffc::Data::Board::Avatars::upload_avatar($c->session->{user}, $avatarfile->filename, sub{ $avatarfile->move_to(@_) });
            },
            msg => 'Datei konnte nicht hochgeladen werden',
            after_ok =>
              sub { $c->info_stash('Datei wurde hochgeladen'); $c->frontpage() },
        }
    );
    $c->options_form();
}

sub options_showcat_save {
    my $c = shift;
    my $user = $c->session()->{user};
    my $cats = Ffc::Data::Board::Views::get_all_categories( $user );
    for my $cat ( @$cats ) {
        next unless $cat->[1];
        my $x = $c->param("show_cat_$cat->[1]") ? 1 : 0;
        Ffc::Data::Board::OptionsUser::update_show_category( $user, $cat->[1], $x );
    }
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
    elsif ( $username and _check_user_exists( $username ) ) {

        if ( $c->param('overwriteok') ) {
            $c->error_handling({
                code => sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_password(
                        $admin, $username, $newpw1, $newpw2 );
                },
                after_ok => sub { $c->info_stash(qq'Passwort von "$username" geändert') },
              }) if $newpw1
              and $newpw2;
            $c->error_handling({
                code => sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_active( $admin,
                        $username, $active );
                },
                after_ok => sub { $c->info_stash(qq'Benutzer "$username" '.($active ? 'aktiviert' : 'deaktiviert')) },
            });
            $c->error_handling({
                code => sub {
                    Ffc::Data::Board::OptionsAdmin::admin_update_admin( $admin,
                        $username, $isadmin );
                },
                after_ok => sub { $c->info_stash(qq'Adminstatus von "$username" '.($isadmin ? 'aktiviert' : 'deaktiviert')) },
            });
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
        $c->error_handling({
            code => sub {
                Ffc::Data::Board::OptionsAdmin::admin_create_user( $admin,
                    $username, $newpw1, $newpw2, $active, $isadmin );
            },
            after_ok => sub { $c->info_stash(qq'Neuer Benutzer "$username" angelegt') },
        });
    }
    $c->options_form();
}

1;

