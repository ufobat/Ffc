use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Callcheck;
use Test::General;
use Mock::Controller;
use Mock::Testuser;
use Ffc::Data::Auth;
srand;

use Test::More tests => 98;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::OptionsUser');

{
    note('sub update_email( $userid, $email )');
    {
        my $user = Test::General::test_get_rand_user();
        $user->{email} = Test::General::test_r() . $user->{email};
        check_call(
            \&Ffc::Data::Board::OptionsUser::update_email,
            update_user_stats => {
                name => 'user name',
                good => $user->{name},
                bad  => [
                    '', '        ',
                    Mock::Testuser::get_noneexisting_username()
                ],
                errormsg => [
                    'Kein Benutzername angegeben',
                    'Benutzername ungültig',
                    'Benutzer unbekannt'
                ],
                emptyerror => 'Kein Benutzername angegeben',
            },
            {
                name     => 'email',
                good     => $user->{email},
                bad      => [ '', '   ', 'a' x 1026 ],
                errormsg => [
                    'Keine Emailadresse angegeben',
                    'Neue Emailadresse schaut komisch aus',
                    'Neue Emailadresse ist zu lang'
                ],
                emptyerror => 'Keine Emailadresse angegeben',
            },
        );
    }
    {
        my $user      = Test::General::test_get_rand_user();
        my $username  = $user->{name};
        my $get_email = sub {
            Ffc::Data::dbh()->selectrow_arrayref(
                'SELECT u.email FROM '
                  . $Ffc::Data::Prefix
                  . 'users u WHERE u.name=?',
                undef, $username
            )->[0];
        };
        my $oldemail = $user->{email};
        my $newemail = Test::General::test_r() . $user->{email};
        isnt( $oldemail, $newemail, 'email adresses are different' );
        my $get_oldemail = $get_email->();
        is( $oldemail, $get_oldemail, 'old email in database correct' );
        ok(
            Ffc::Data::Board::OptionsUser::update_email( $username, $newemail ),
            'call ok'
        );
        my $get_newemail = $get_email->();
        ok( $get_newemail, 'email adress in database ok after change' );
        isnt( $get_oldemail, $get_newemail,
            'email adress was changed in database' );
        is( $newemail, $get_newemail, 'new email in database correct' );
    }
}

{
    note('sub update_password( $userid, $oldpw, $newpw1, $newpw2 )');
    my $user         = Test::General::test_get_rand_user();
    my $username     = $user->{name};
    my $old_password = $user->{password};
    $user->alter_password();
    my $new_password = $user->{password};
    check_call(
        \&Ffc::Data::Board::OptionsUser::update_password,
        update_password => {
            name => 'user name',
            good => $username,
            bad =>
              [ '', '        ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt'
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name         => 'old password',
            good         => $old_password,
            bad          => [ '        ', substr( $old_password, 0, 5 ) ],
            errormsg     => ['Passwort ungültig'],
            noemptycheck => 1,
        },
        {
            name => 'new password',
            good => $new_password,
            bad  => [ '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'new password repeat',
            good => $new_password,
            bad =>
              [ $old_password, '', '        ', substr( $new_password, 0, 5 ) ],
            errormsg => [
                'Das neue Passwort und dessen Wiederholung stimmen nicht',
                'Kein Passwort',
                'Passwort ungültig'
            ],
            emptyerror => 'Kein Passwort',
        },
    );
    {
        my $user_ok = Test::General::test_get_rand_user();
        $user_ok = Test::General::test_get_rand_user()
          while $user_ok->{name} eq $user->{name}
          or $user_ok->{faulty};
        my $username     = $user_ok->{name};
        my $userid       = Ffc::Data::Auth::get_userid($username);
        my $old_password = $user_ok->{password};
        $user_ok->alter_password();
        my $new_password = $user_ok->{password};
        ok( Ffc::Data::Auth::check_password( $userid, $old_password ),
            'old password works' );
        ok( !Ffc::Data::Auth::check_password( $userid, $new_password ),
            'new password does not work yet' );
        ok(
            Ffc::Data::Board::OptionsUser::update_password(
                $username, $old_password, $new_password, $new_password
            ),
            'call returned true'
        );
        ok( !Ffc::Data::Auth::check_password( $userid, $old_password ),
            'old password does not work anymore' );
        ok( Ffc::Data::Auth::check_password( $userid, $new_password ),
            'new password works now' );
    }
}
{
    note('sub update_show_images( $sessionhash, $checkbox )');
    {
        my $user     = Test::General::test_get_rand_user();
        my $username = $user->{name};
        my $c        = Mock::Controller->new();
        $c->{session}->{user} = $username;
        check_call(
            \&Ffc::Data::Board::OptionsUser::update_show_images,
            update_show_images => {
                name => 'session hash',
                good => $c->session,
                bad  => [
                    '', {},
                    { user => '' },
                    { user => '    ' },
                    { user => Mock::Testuser::get_noneexisting_username() },
                ],
                errormsg => [
                    'Session-Hash als erster Parameter benötigt',
                    ('Kein Benutzername angegeben') x 2,
                    'Benutzername ungültig',
                    'Benutzer unbekannt',
                ],
                emptyerror => 'Session-Hash als erster Parameter benötigt',
            },
            {
                name       => 'boolean (0/1)checkbox value',
                good       => int( rand 2 ),
                bad        => [ '', 4, 'asd', '   ' ],
                errormsg   => ['show_images muss 0 oder 1 sein'],
                emptyerror => 'show_images nicht angegeben',
            },
        );
    }
    {
        my $user     = Test::General::test_get_rand_user();
        my $username = $user->{name};
        my $c        = Mock::Controller->new();
        $c->session()->{user} = $username;
        my $get_value = sub {
            Ffc::Data::dbh()->selectrow_arrayref(
                'SELECT show_images FROM '
                  . $Ffc::Data::Prefix
                  . 'users WHERE name=?',
                undef, $username
            )->[0];
        };
        my $order = $get_value->() ? [ 0, 1, 0, 1 ] : [ 1, 0, 1, 0 ];
        for my $value (@$order) {
            ok(
                Ffc::Data::Board::OptionsUser::update_show_images(
                    $c->session, $value
                ),
                qq(call with "$value" ok)
            );
            is( $value, $get_value->(), 'database update ok' );
        }
    }
}
{
    note('sub update_theme( $sessionhash, $themename )');
    {
        my $user     = Test::General::test_get_rand_user();
        my $username = $user->{name};
        my $c        = Mock::Controller->new();
        my $theme    = $Ffc::Data::Themes[ int rand scalar @Ffc::Data::Themes ];
        my $illegal_theme = Test::General::test_r();
        $illegal_theme = Test::General::test_r()
          while $illegal_theme ~~ @Ffc::Data::Themes;
        $c->session()->{user} = $username;
        check_call(
            \&Ffc::Data::Board::OptionsUser::update_theme,
            update_theme => {
                name => 'session hash',
                good => $c->session,
                bad  => [
                    '', {},
                    { user => '' },
                    { user => '    ' },
                    { user => Mock::Testuser::get_noneexisting_username() },
                ],
                errormsg => [
                    'Session-Hash als erster Parameter benötigt',
                    ('Kein Benutzername angegeben') x 2,
                    'Benutzername ungültig',
                    'Benutzer unbekannt',
                ],
                emptyerror => 'Session-Hash als erster Parameter benötigt',
            },
            {
                name     => 'theme name',
                good     => $theme,
                bad      => [ '', 'a' x 66, $illegal_theme ],
                errormsg => [
                    'Themenname nicht angegeben',
                    'Themenname zu lang',
                    'Thema ungültig'
                ],
                emptyerror => 'Themenname nicht angegeben',
            },
        );
    }
    {
        my $user   = Test::General::test_get_rand_user();
        my $username = $user->{name};
        my $c      = Mock::Controller->new();
        $c->session()->{user} = $username;
        my $get_value = sub {
            Ffc::Data::dbh()->selectrow_arrayref(
                'SELECT theme FROM ' . $Ffc::Data::Prefix . 'users WHERE name=?',
                undef, $username
            )->[0];
        };
        my $theme = $get_value->();
        $theme = '' unless defined $theme;
        for my $i ( 0 .. 9 ) {
            my $new_theme = '';
            $new_theme =
              $Ffc::Data::Themes[ int rand scalar @Ffc::Data::Themes ]
              while !$new_theme
              or $new_theme eq $theme;
            isnt( $theme, $new_theme,
                qq(changing theme from "$theme" to "$new_theme") );
            ok(
                Ffc::Data::Board::OptionsUser::update_theme(
                    $c->session(), $new_theme
                ),
                'called ok'
            );
            my $new_value = $get_value->();
            isnt( $theme, $new_value, 'value changed' );
            $theme = $new_theme;
        }
    }

}

