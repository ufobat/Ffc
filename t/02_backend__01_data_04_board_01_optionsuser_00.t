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
use Ffc::Data::General;
srand;

use Test::More tests => 221;

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
            bad          => [ substr( $old_password, 0, 5 ) ],
            errormsg     => ['Passwort ungültig'],
            noemptycheck => 1,
        },
        {
            name => 'new password',
            good => $new_password,
            bad  => [ '', substr( $new_password, 0, 5 ) ],
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
            emptyerror => 'Kein Passwort',
        },
        {
            name => 'new password repeat',
            good => $new_password,
            bad =>
              [ $old_password, '', substr( $new_password, 0, 5 ) ],
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

my @fontsizes = keys %Ffc::Data::FontSizeMap;
update_something( 'fontsize', \@fontsizes,                      'Schriftgröße', 'Schriftgröße', 1, 'Schriftgröße keine Zahl' );
update_something( 'theme',    Ffc::Data::General::get_themes(), 'Themenname',   'Thema',        1 );
update_something( 'bgcolor',  \@Ffc::Data::Colors,              'Farbname',     'Farbe',        0 );

sub update_something {
    my $thing  = shift;
    my $data   = shift;
    my $ename  = shift;
    my $name   = shift;
    my $wempty = shift;
    my $tlem   = shift;
    note(qq'sub update_$thing( \$sessionhash, \$themename )');
    {
        my $user     = Test::General::test_get_rand_user();
        my $username = $user->{name};
        my $c        = Mock::Controller->new();
        my $dat      = $data->[ int rand scalar @$data ];
        my $illegal_data = Test::General::test_r();
        $illegal_data = Test::General::test_r()
          while grep m/$illegal_data/xmsio, @$data;
        $c->session()->{user} = $username;
        check_call(
            \&{"Ffc::Data::Board::OptionsUser::update_$thing"},
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
                name     => qq'$thing name',
                good     => $dat,
                bad      => [ ( $wempty ? '' : () ), 'a' x 66, $illegal_data ],
                errormsg => [
                    ( $wempty ? ( $tlem // qq'$ename nicht angegeben' ) : () ),
                    ( $tlem // qq'$ename zu lang' ), ( $tlem // qq'$name ungültig' )
                ],
                ( $wempty
                    ? ( emptyerror   => qq'$ename nicht angegeben' )
                    : ( noemptycheck => 1 )
                ),
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
                qq'SELECT $thing FROM ${Ffc::Data::Prefix}users WHERE name=?',
                undef, $username
            )->[0];
        };
        my $setdat = $get_value->();
        $setdat = '' unless defined $setdat;
        for my $i ( 0 .. 9 ) {
            my $new_setdat = '';
            $new_setdat =
              $data->[ int rand scalar @$data ]
              while !$new_setdat
              or $new_setdat eq $setdat;
            isnt( $setdat, $new_setdat,
                qq(changing setdat from "$setdat" to "$new_setdat") );
            { 
                no strict qw(refs);
                ok(
                    &{"Ffc::Data::Board::OptionsUser::update_$thing"}(
                        $c->session(), $new_setdat
                    ),
                    'called ok'
                );
            }
            my $new_value = $get_value->();
            isnt( $setdat, $new_value, 'old value does not work anymore' );
            is($new_value, $new_setdat, 'value has been changed' );
            $setdat = $new_setdat;
        }
    }

}
{
    note('sub update_show_category( $username, $categoryshor, $checkbox )');
    my $user = Mock::Testuser->new_active_user();
    my $userid = Ffc::Data::Auth::get_userid( $user->{name}, 'angemeldeter Benutzer für Kategorieanzeigeswitchtest' );
    my $cat = $Test::General::Categories[0][2];
    my $dbh = Ffc::Data::dbh();
    is( ( $dbh->selectrow_array('SELECT COUNT(f.userid) FROM '.$Ffc::Data::Prefix.'lastseenforum f WHERE f.userid = ?', undef, $userid))[0], 0, 'no entry for new user in category-check' );
    check_call(
        \&Ffc::Data::Board::OptionsUser::update_show_category,
        update_show_category => {
            name => 'username',
            good => $user->{name},
            bad  => [
                '',
                Mock::Testuser::get_noneexisting_username(),
            ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
        {
            name => 'category short',
            good => $cat,
            bad  => [
                '',
                Test::General::test_get_non_category_short()
            ],
            errormsg => [
                'Kategorie nicht angegeben',
                'Kategorie ungültig',
            ],
            emptyerror => 'Kategorie nicht angegeben',
        },
        {
            name       => 'boolean (0/1)checkbox value',
            good       => 0,
            bad        => [ '', 4, 'asd', '   ' ],
            errormsg   => [ 'Kategorie-Anzeigeswitch muss 0 oder 1 sein' ],
            emptyerror => 'Kategorie-Anzeigeswitch nicht angegeben',
        },
    );
    is( ( $dbh->selectrow_array('SELECT COUNT(f.userid) FROM '.$Ffc::Data::Prefix.'lastseenforum f WHERE f.userid = ?', undef, $userid))[0], 1, 'one entry for new user in category-check' );
    is( ( $dbh->selectrow_array('SELECT f.show_cat FROM '.$Ffc::Data::Prefix.'lastseenforum f WHERE f.userid = ?', undef, $userid))[0], 0, 'zero as entry for new user in category-show' );
    Ffc::Data::Board::OptionsUser::update_show_category($user->{name}, $cat, 1);
    is( ( $dbh->selectrow_array('SELECT f.show_cat FROM '.$Ffc::Data::Prefix.'lastseenforum f WHERE f.userid = ?', undef, $userid))[0], 1, 'zero as entry for new user in category-show' );
}

