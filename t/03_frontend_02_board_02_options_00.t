#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Mojo;
use Test::General;
use Mock::Testuser;
use Ffc::Data::General;
use Ffc::Data::Board::Views;

use Test::More tests => 941;

my $t = Test::General::test_prepare_frontend('Ffc');

{
    note('Normalen Benutzer testen');
    $t->get_ok('/logout');
    my $user = Test::General::test_get_rand_user();
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    {
        my $c = $t->get_ok('/options')->status_is(200);
        $c->content_like(qr(Einstellungen));
        $c->content_unlike(qr(Benutzerverwaltung));
    }
    $t->post_ok( '/options/admin_save',
        form => { overwriteok => 1, username => $user->{name}, active => 0 } )
      ->status_is(500)->content_like(qr{Nur Administratoren dürfen das});
    {
        note('testing show_images flag');
        for my $c ( undef, 0, undef, 1, undef, 0, 1, 0, 1 ) {
            my $cv = $c ? 1 : 0;
            $t->post_ok( '/options/showimages_save', form => { show_images => $c } )
              ->status_is(200)->content_like(qr{Einstellungen});
            my $reta = Ffc::Data::dbh()->selectall_arrayref(
                'SELECT show_images FROM '
                  . $Ffc::Data::Prefix
                  . 'users WHERE name=?',
                undef, $user->{name}
            );
            ok( @$reta, 'got something from checking' );
            is( $reta->[0]->[0], $cv, 'got the right thing from checking' );
        }
    }
    my @fontsizes = ( keys %Ffc::Data::FontSizeMap )[1..5];
    test_update_something('fontsize', 'Schriftgröße', 'font-size: %sem;', \@fontsizes, 0, 'Schriftgröße', 1,\%Ffc::Data::FontSizeMap );
    test_update_something('theme', 'Thema', '%s/css/style.css', Ffc::Data::General::get_themes(), 'default', 'Thema', 0 );
    my $start = int rand $#Ffc::Data::Colors - 10;
    test_update_something('bgcolor', 'Hintergrundfarbe', 'background-color: %s', [@Ffc::Data::Colors[$start..$start + 10]], '', 'Farbe', 0 );
    sub test_update_something {
        my $thing   = shift;
        my $name    = shift;
        my $teststr = shift;
        my $things  = shift;
        my $default = shift;
        my $illname = shift;
        my $get     = shift;
        my $map     = shift;
        note(qq'testing $thing choice');
        my $check_thing = sub {
            my $dat = shift;
            my $reta  = Ffc::Data::dbh()->selectall_arrayref(
                qq'SELECT $thing FROM '
                .$Ffc::Data::Prefix
                .'users WHERE name=?',
                undef, $user->{name}
            );
            ok( @$reta, 'got something from checking' );
            is( $reta->[0]->[0],
                $dat,
                $name.' "' . ( $dat // '<undef>' ) . '"ok in database' );
        };
        $check_thing->($default ? undef : $default);
        for my $dat (@{$things}[0 .. $#$things]) {
            if ( $get ) {
                $t->get_ok( qq'/options/${thing}_save/$dat' );
            }
            else {
                $t->post_ok( qq'/options/${thing}_save', form => { $thing => $dat } );
            }
            $t->status_is(200);
            $t->content_like(qr{Einstellungen});
            $t->content_like(qr{$name geändert});
            my $test = sprintf $teststr, $map ? $map->{$dat} : $dat;
            if ( $default or $dat ) {
                $t->content_like(qr($test));
                $t->get_ok('/')->content_like(qr($test));
            }
            else {
                $t->content_unlike(qr($test));
                $t->get_ok('/')->content_unlike(qr($test));
            }
            $check_thing->($dat);
        }
        {
            my $dat = $things->[0];
            if ( $get ) {
                $t->get_ok( qq'/options/${thing}_save/$dat' );
            }
            else {
                $t->post_ok( qq'/options/${thing}_save', form => { $thing => $dat } );
            }
            $t->status_is(200)->content_like(qr{Einstellungen});
            $check_thing->($dat);
            {
                my $newthing = '';
                $newthing = 9999 + int rand 9999
                  while !$newthing
                  or grep { lc($newthing) eq lc($_) } @$things;
                if ( $get ) {
                    $t->get_ok( qq'/options/${thing}_save/$newthing' );
                }
                else {
                    $t->post_ok( qq'/options/${thing}_save', form => { $thing => $newthing } );
                }
                $t->status_is(500)->content_like(qr{$illname ungültig});
                my $test = sprintf $teststr, $map ? $map->{$dat} : $dat;
                $t->get_ok('/')->status_is(200)->content_like(qr($test));
                $check_thing->($dat);
            }
        }
    }
    {
        note('testing email change');
        my $check_email = sub {
            my $email = shift;
            my $reta  = Ffc::Data::dbh()->selectall_arrayref(
                'SELECT email FROM '
                  . $Ffc::Data::Prefix
                  . 'users WHERE name=?',
                undef, $user->{name}
            );
            ok( @$reta, 'got something from checking' );
            is( $reta->[0]->[0],
                $email,
                'email "' . ( $email // '<undef>' ) . '" ok in database' );
        };
        my $oldemail = $user->{email};
        $check_email->($oldemail);
        my $test_email = sub {
            my $newemail = shift // '';
            my $error    = shift;
            my $checkvalue = $oldemail;
            $t->post_ok( '/options/email_save', form => { email => $newemail } );
            if ($error) {
                $t->status_is(500)->content_like(qr{$error});
            }
            else {
                $t->status_is(200)->content_like(qr{Einstellungen});
                $checkvalue = $newemail;
                $t->content_like(qr(Email-Adresse geändert));
            }
            $check_email->($checkvalue);
        };
        $test_email->(undef,      'Keine Emailadresse angegeben');
        $test_email->('',         'Keine Emailadresse angegeben');
        $test_email->('a' x 1032, 'Neue Emailadresse ist zu lang');
        $test_email->('aaaa',     'Neue Emailadresse schaut komisch aus');
        {
            my $newemail = '';
            $newemail = Test::General::test_r() . '@' . Test::General::test_r() . '.org'
              while not $newemail
              or $newemail eq $oldemail;
            $test_email->($newemail);
        }
    }
    {
        note('testing password change');
        my $oldpw = $user->{password};
        $user->alter_password;
        my $newpw = $user->{password};
        my $alter_pw = sub {
            my $oldpw = shift;
            my $newpw1 = shift;
            my $newpw2 = shift;
            my $error  = shift;
            $t->post_ok( '/options/password_save', form => { oldpw => $oldpw, newpw1 => $newpw1, newpw2 => $newpw2 } );
            if (not defined $error or $error) {
                $t->status_is(500);
                if ( $error ) {
                    $t->content_like(qr{$error});
                }
            }
            else {
                $t->status_is(200)->content_like(qr{Einstellungen});
                $t->content_like(qr'Passwort geändert');
            }
        };
        my $test_oldpw = sub {
            Ffc::Data::Auth::check_password( Ffc::Data::Auth::get_userid( $user->{name} ), $oldpw );
        };
        my $test_newpw = sub {
            Ffc::Data::Auth::check_password( Ffc::Data::Auth::get_userid( $user->{name} ), $newpw );
        };
        my @testmatrix;
        {
            my @v = ( '', 'a', 'a' x 72, undef );
            for my $x ( @v ) { for my $y ( @v ) { for my $z ( @v ) { push @testmatrix, [$x, $y, $z, undef] } } }
            map { $_->[3] = 'Passwort ungültig'} grep { $_->[0] and $_->[1] and $_->[2] }  @testmatrix;
        }
        for my $pwset ( 
            @testmatrix,
            [$newpw, $newpw, $newpw, 'Das alte Passwort ist falsch'],
            [$oldpw, $oldpw, $newpw, 'Das neue Passwort und dessen Wiederholung stimmen nicht überein'],
            ) {
            $alter_pw->( @$pwset );
            ok( $test_oldpw->(), 'old password still working' );
            ok(!$test_newpw->(), 'new password not working yet' );
        }
        {
            $alter_pw->($oldpw, $newpw, $newpw, 0);
            ok(!$test_oldpw->(), 'old password not working anymore' );
            ok( $test_newpw->(), 'new password now working' );
        }
    }
    $t->get_ok('/logout')->status_is(200);
}

{
    note('Administrator testen');
    $t->get_ok('/logout');
    my $user  = Test::General::test_get_rand_user();
    my $admin = Mock::Testuser->new_active_admin();
    $t->post_ok( '/login',
        form => { user => $admin->{name}, pass => $admin->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
    {
        my $c = $t->get_ok('/options')->status_is(200);
        $c->content_like(qr(Einstellungen));
        $c->content_like(qr(Benutzerverwaltung));
    }
    my $call = sub {
        $t->post_ok( '/options/admin_save', form => shift );
        for my $p (@_) {
            if    ('SCALAR' eq ref $p) { $t->content_like(qr{$p}) }
            elsif ('Regexp' eq ref $p) { $t->content_like($p) }
            elsif ('CODE'   eq ref $p) { $p->($t) }
            else {
                die q{parameter type '}
                  . ref($p)
                  . q{' illegal: }
                  . Dumper( \@_ )
            }
        }
        return $t;
    };
    {
        note('passwort setzen');
        my $check = sub {
            return Ffc::Data::Auth::check_password(
                Ffc::Data::Auth::get_userid( $user->{name} ),
                shift // $user->{password} );
        };
        my $oldpw = $user->{password};
        ok( $check->(), 'old password works' );
        $user->alter_password;
        my $newpw = $user->{password};
        ok( !$check->(), 'new password does not work yet before anything' );
        $call->(
            {
                username    => $user->{name},
                overwriteok => 1,
                active      => 1,
                newpw1      => '',
                newpw2      => $newpw
            }
        );
        $t->status_is(200)
          ;    # Passwortändern wegen mangelnder Eingaben nicht vorgenommen
        ok( !$check->(), 'new password does not work yet (#1)' );
        $call->(
            {
                username    => $user->{name},
                overwriteok => 1,
                active      => 1,
                newpw1      => $newpw,
                newpw2      => ''
            }
        );
        $t->status_is(200)
          ;    # Passwortändern wegen mangelnder Eingaben nicht vorgenommen
        ok( !$check->(), 'new password does not work yet (#2)' );
        $call->(
            {
                username => $user->{name},
                active   => 1,
                newpw1   => $newpw,
                newpw2   => $newpw
            }
        );
        $t->status_is(500);    # Overwrite fehlt
        ok( !$check->(), 'new password does not work yet (#3)' );
        $call->(
            {
                username => $user->{name},
                active   => 1,
                newpw1   => $newpw,
                newpw2   => $oldpw
            }
        );
        $t->status_is(500);    # Passworte unterscheiden sich
        ok( !$check->(), 'new password does not work yet (#4)' );
        $call->(
            {
                username    => $user->{name},
                overwriteok => 1,
                active      => 1,
                newpw1      => $newpw,
                newpw2      => $newpw
            }
        );
        $t->status_is(200)->content_like(qr'Einstellungen')->content_like(qr(Passwort von &quot;$user->{name}&quot; geändert));
        ok( $check->(), 'new password works now' );
    }
    {
        note('aktiv setzen');
        my $check = sub {
            (
                Ffc::Data::dbh()->selectrow_array(
                    'SELECT COUNT(id) FROM '
                      . $Ffc::Data::Prefix
                      . 'users WHERE name=? AND active=1',
                    undef,
                    $user->{name}
                )
            )[0] ? 1 : 0;
        };
        ok( $check->(), 'user is active' );
        for my $c ( 0, 1 ) {
            isnt( $check->(), $c, $c ? 'user is inactive' : 'user is active' );
            $call->( { username => $user->{name}, active => $c } );
            isnt( $check->(), $c,
                $c ? 'user is still inactive' : 'user is still active' );
            $call->(
                { username => $user->{name}, active => $c, overwriteok => 1 } );
            is( $check->(), $c,
                $c ? 'user is now active' : 'user is now inactive' );
            my $tstring = qq(Benutzer &quot;$user->{name}&quot; ).($c ? 'aktiviert' : 'deaktiviert');
            $t->status_is(200)->content_like(qr'Einstellungen')->content_like(qr($tstring));
        }
        ok( $check->(), 'user is active' );
    }
    {
        note('admin setzen');
        my $check = sub {
            (
                Ffc::Data::dbh()->selectrow_array(
                    'SELECT COUNT(id) FROM '
                      . $Ffc::Data::Prefix
                      . 'users WHERE name=? AND admin=1',
                    undef,
                    $user->{name}
                )
            )[0] ? 1 : 0;
        };
        ok( !$check->(), 'user is no admin' );
        for my $c ( 1, 0 ) {
            isnt( $check->(), $c, $c ? 'user is no admin' : 'user is admin' );
            $call->( { username => $user->{name}, admin => $c } );
            isnt( $check->(), $c,
                $c ? 'user is still no admin' : 'user is still admin' );
            $call->(
                { username => $user->{name}, admin => $c, overwriteok => 1 } );
            is( $check->(), $c,
                $c ? 'user is now admin' : 'user is now no admin' );
            my $tstring = qq(Adminstatus von &quot;$user->{name}&quot; ).($c ? 'aktiviert' : 'deaktiviert');
            $t->status_is(200)->content_like(qr'Einstellungen')->content_like(qr($tstring));
        }
        ok( !$check->(), 'user is no admin' );
    }
    {
        note('benutzer erzeugen');
        my $check_user = sub {
            my $username = shift;
            my $ret      = Ffc::Data::dbh()->selectall_arrayref(
                'SELECT id, active, admin FROM '
                  . $Ffc::Data::Prefix
                  . 'users WHERE name=?',
                undef, $username
            );
            return unless @$ret;
            return $ret->[0];
        };
        for my $c (
            [ 0,     0 ],
            [ 0,     1 ],
            [ 1,     0 ],
            [ 1,     1 ],
            [ undef, undef ],
            [ undef, 1 ],
            [ 1,     undef ],
            [ 1,     1 ],
            [ undef, 0 ],
            [ 0,     undef ]
          )
        {
            my $username = Test::General::test_get_non_username();
            my $password = my $wrongpw2 = '';
            ( $password, $wrongpw2 ) = map { Test::General::test_r() } 0, 1
              while $password eq $wrongpw2;
            my $active = $c->[0] ? 1 : 0;
            my $admin  = $c->[1] ? 1 : 0;
            my @flags  = (
                ( defined( $c->[0] ) ? ( active => $active ) : () ),
                ( defined( $c->[1] ) ? ( admin  => $admin )  : () )
            );
            {
                $call->(
                    {
                        username => '',
                        newpw1   => $password,
                        newpw2   => $password,
                        @flags
                    },
                    qr'Kein Benutzername angegeben'
                );
                $t->status_is(500);
                ok( !$check_user->($username),
                    'user does not exist yet, as expected' );
            }
            {
                $call->(
                    {
                        username => $username,
                        newpw1   => '',
                        newpw2   => '',
                        @flags
                    },
                    qr(Kein Passwort angegeben)
                );
                $t->status_is(500);
                ok( !$check_user->($username),
                    'user does not exist yet, as expected' );
            }
            {
                $call->(
                    {
                        username => $username,
                        newpw1   => '',
                        newpw2   => $wrongpw2,
                        @flags
                    },
                    qr(Kein Passwort angegeben)
                );
                $t->status_is(500);
                ok( !$check_user->($username),
                    'user does not exist yet, as expected' );
            }
            {
                $call->(
                    {
                        username => $username,
                        newpw1   => $password,
                        newpw2   => '',
                        @flags
                    },
                    qr(Kein Passwort angegeben)
                );
                $t->status_is(500);
                ok( !$check_user->($username),
                    'user does not exist yet, as expected' );
            }
            {
                $call->(
                    {
                        username => $username,
                        newpw1   => $password,
                        newpw2   => $wrongpw2,
                        @flags
                    },
qr(Das neue Passwort und dessen Wiederholung stimmen nicht überein)
                );
                $t->status_is(500);
                ok( !$check_user->($username),
                    'user does not exist yet, as expected' );
            }
            {
                $call->(
                    {
                        username => $username,
                        newpw1   => $password,
                        newpw2   => $password,
                        @flags
                    },
                );
                $t->status_is(200);
                my $ret = $check_user->($username);
                ok( @$ret,     'user does exist now' );
                ok( $ret->[0], 'new id is available' );
                is( $ret->[1], $active, 'new user active status as expected' );
                is( $ret->[2], $admin,  'new user admin status as expected' );
            }

        }
    }
    $t->get_ok('/logout');
}
{
    my $user  = Test::General::test_get_rand_user();
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms )
      ->get_ok('/options')->status_is(200)
      ->content_like(qr(Einstellungen));
    my @cats = grep { $_->[2] } @Test::General::Categories;
    my %cats = map { $_->[2] => 1 } @cats;
    my %catnames = map { my $n = $_->[1]; $n =~ s/"/\\\&quot;/gsm; $_->[2] => $n } @cats;
    my $check_catarray = sub {
        $t->get_ok('/options')->status_is(200)
          ->content_like(qr(Einstellungen));
        $t->content_like( $cats{$_}
          ? qr(<input\s+type="checkbox"\s+name="show_cat_$_"\s+value="1"\s+checked="checked"\s+/>)
          : qr(<input\s+type="checkbox"\s+name="show_cat_$_"\s+value="1"\s+/>)
        ) for keys %cats;
    };
    $check_catarray->();
    $cats{$_->[2]} = 0 for @cats[4..8];
    {
        my %showcats = map {; "show_cat_$_" => $cats{$_} } keys %cats;
        $t->post_ok("/options/showcat_save", form => \%showcats )
          ->status_is(200)
          ->content_like(qr(Einstellungen));
        $t->content_like(
            $cats{$_}
            ? qr(Kategorie\s+\&quot;$catnames{$_}\&quot;\s+ist\s+jetzt\s+sichtbar)
            : qr(Kategorie\s+\&quot;$catnames{$_}\&quot;\s+wird\s+jetzt\s+versteckt)
          ) for keys %cats;
        $check_catarray->();
    }
    {
        my $cats = 
        my %getcats = map  { $_->[1] => $_->[4] }
                      grep { $_->[1] } 
                          @{ Ffc::Data::Board::Views::get_all_categories( $user->{name} ) };
        is_deeply \%getcats, \%cats, 'category hide correct set';
    }
}
