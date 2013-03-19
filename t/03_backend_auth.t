#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Mojolicious;
use Mock::Database;
use Mock::Config;
use Mock::Testuser;
use Test::Callcheck;
use Ffc::Data;

use Test::More tests => 1;

BEGIN { use_ok('Ffc::Data::Auth') }

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();

my $admin = Mock::Testuser->new_admin();
my $user  = Mock::Testuser->new_user();

{
    note('TESTING check_username_rules( $username )');
    check_call(
        \&Ffc::Data::Auth::check_username_rules,
        check_username_rules =>
        {
            name => 'username',
            good => Mock::Testuser::randstr(),
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$_ddd', ],
            emptyerror => 'Kein Benutzername',
            errormsg   => [ 'Kein Benutzername', 'Benutzername ungültig' ],
        },
    );
}

{
    note('TESTING check_password_rules( $password )');
    check_call(
        \&Ffc::Data::Auth::check_password_rules,
        check_password_rules =>
        {
            name => 'password',
            good => Mock::Testuser::randstr(),
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$ _ddd', ],
            emptyerror => 'Kein Passwort',
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
        },
    );
}

{
    note('TESTING check_userid_rules( $userid )');
    check_call(
        \&Ffc::Data::Auth::check_userid_rules,
        check_userid_rules =>
        {
            name => 'userid',
            good => int(rand 100000),
            bad  => [ '', 'aa', ' ' x 7, "abc".int(rand 10000)."def", ],
            emptyerror => 'Keine Benutzerid',
            errormsg   => [ 'Keine Benutzerid', 'Benutzer ungültig' ],
        },
    );
}

{
    note('TESTING get_userdata_for_login( $user, $pass )');
    check_call(
        \&Ffc::Data::Auth::get_userdata_for_login,
        get_userdata_for_login =>
        {
            name => 'username',
            good => $user->{name},
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$_ddd', ],
            emptyerror => 'Kein Benutzername',
            errormsg   => [ 'Kein Benutzername', 'Benutzername ungültig' ],
        },
        {
            name => 'password',
            good => $user->{password},
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$ _ddd', ],
            emptyerror => 'Kein Passwort',
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
        },
    );
}

{
    note('TESTING is_user_admin( $userid )');
}

{
    note('TESTING check_password( $userid, $pass )');
}

{
    note('TESTING set_password( $userid, $pass )');
}

{
    note('TESTING check_user( $userid )');
}

{
    note('TESTING get_userid( $username )');
}

{
    note('TESTING get_username( $userid )');
}
