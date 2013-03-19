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
use Ffc::Data;

use Test::More tests => 1;

srand;

sub r {
    my $pick = sub { $_[0][ int rand scalar @{ $_[0] } ] };
    my $alphachars = [ 'a' .. 'z', 'A' .. 'Z' ];
    my $allchars = [ 0 .. 9, '-', '_', @$alphachars ];
    return join '', map( {
            ;
              $pick->($alphachars)
        } 1 .. 2 ),
      map( {
            ;
              $pick->($allchars)
        } 1 .. 4 ),
      map( {
            ;
              $pick->($alphachars)
      } 1 .. 2 );
}

BEGIN { use_ok('Ffc::Data::Auth') }

note('doing some preparations');
my $config = Mock::Config->new->{config};
my $app    = Mojolicious->new();
$app->log->level('error');
Ffc::Data::set_config($app);
Mock::Database::prepare_testdatabase();

sub _generate_testuser {
    my $isadmin   = shift // 0;
    my $username  = r();
    my $password  = r();
    my $useremail = "$username\@" . r() . '.org';

#note(qq(user => "$username", password => "$password", useremail => "$useremail"));
    Ffc::Data::dbh()->do(
        << "EOSQL",
INSERT 
    INTO     ${Ffc::Data::Prefix}users 
           ( "name", "password", "email", "admin" )
    VALUES ( ?,      ?,          ?,       1       )
EOSQL
        undef, $username, crypt( $password, Ffc::Data::cryptsalt() ), $useremail
    );
    return {
        name     => $username,
        password => $password,
        email    => $useremail,
        admin    => $isadmin,
        data     => []
    };
}

sub _good_run {
    my $code = shift;
    eval { $code->(@_) };
    ok( !$@, 'code did not die, like we wanted it for now ' );
    return $@ ? 0 : 1;
}

sub _failed_run {
    my $code = shift;
    eval { $code->(@_) };
    ok( $@, 'code died correctly' );
    return $@ || 0;
}

sub _check_call {    # alle aufrufoptionen durchprobieren
    my $code   = shift;
    my @params = @_
      ; # ( { name => '', good => '', bad => [ '' ], emptyerror => '', errormsg => [ '' ] } )
    my @okparams;
    while ( my $par = shift @params ) {
        die qq(no emtpy error message given for "$par->{name}")
          unless $par->{emptyerror};
        _good_run( $code, @okparams, $par->{good} );
        {
            my $ret = _failed_run( $code, @okparams );
            like( $ret, qr/$par->{emptyerror}/,
                qq~wrong call without "$par->{name}" yelled correctly~ );
        }
        for my $bad ( 0 .. $#{ $par->{bad} } ) {
            my $param = $par->{bad}->[$bad];
            my $error =
                 $par->{errormsg}->[$bad]
              || $par->{errormsg}->[-1]
              || $par->{emptyerror};
            my $ret = _failed_run( $code, @okparams, $param );
            like( $ret, qr/$error/,
                qq~wrong call with "$par->{name}"="$param" yelled correctly~ );
        }
        push @okparams, $par->{good};
    }
}

my $admin = _generate_testuser(1);
my $user  = _generate_testuser();

{
    note('TESTING check_username_rules( $username )');
    _check_call(
        \&Ffc::Data::Auth::check_username_rules,
        {
            name => 'username',
            good => r(),
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$_ddd', ],
            emptyerror => 'Kein Benutzername',
            errormsg   => [ 'Kein Benutzername', 'Benutzername ungültig' ],
        },
    );
}

{
    note('TESTING check_password_rules( $password )');
    _check_call(
        \&Ffc::Data::Auth::check_password_rules,
        {
            name => 'password',
            good => r(),
            bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$ _ddd', ],
            emptyerror => 'Kein Passwort',
            errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
        },
    );
}

{
    note('TESTING check_userid_rules( $userid )');
}

{
    note('TESTING get_userdata_for_login( $user, $pass )');
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
