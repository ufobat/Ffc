package Mock::Testuser;

use strict;
use warnings;
use utf8;
use Ffc::Data;
use Data::Dumper;
srand;

sub new_active_admin   { shift->_new( 1, 1 ) }
sub new_active_user    { shift->_new( 1, 0 ) }
sub new_inactive_admin { shift->_new( 0, 1 ) }
sub new_inactive_user  { shift->_new( 0, 0 ) }
sub _new { bless _generate_testuser( @_[ 1, 2 ] ), $_[0] }

sub randstr {
    my $pick = sub { $_[0][ int rand scalar @{ $_[0] } ] };
    my $alphachars = [ 'a' .. 'z', 'A' .. 'Z' ];
    my $allchars = [ 0 .. 9, '_', @$alphachars ];
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

sub _generate_testuser {
    my $isactive = shift() ? 1 : 0;
    my $isadmin  = shift() ? 1 : 0;
    my %zuord    = (
        "u00" => 'inactive user',
        "u01" => 'inactive admin',
        "u10" => 'active user',
        "u11" => 'active admin',
    );
    my $username  = randstr();
    my $password  = randstr();
    my $useremail = "$username\@" . randstr() . '.org';

#note(qq(user => "$username", password => "$password", useremail => "$useremail"));
    Ffc::Data::dbh()->do(
        << "EOSQL",
INSERT 
    INTO     ${Ffc::Data::Prefix}users 
           ( "name", "password", "email", "admin", "active" )
    VALUES (  ?,      ?,          ?,       ?,       ?       )
EOSQL
        undef, $username, crypt( $password, Ffc::Data::cryptsalt() ),
        $useremail, $isadmin, $isactive
    );
    return {
        name       => $username,
        password   => $password,
        email      => $useremail,
        admin      => $isadmin,
        active     => $isactive,
        data       => [],
        pseudoname => $zuord{"u$isactive$isadmin"},
        faulty     => 0,
    };
}

sub get_password_check_hash {
    my $password = shift // randstr();
    return {
        name => 'password',
        good => $password,
        bad  => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$ _ddd', ],
        emptyerror => 'Kein Passwort',
        errormsg   => [ 'Kein Passwort', 'Passwort ungültig' ],
    };
}

sub get_username_check_hash {
    my $username = shift // randstr();
    return {
        name       => 'username',
        good       => $username,
        bad        => [ '', 'aa', 'a' x 72, ' ' x 16, 'aaaa aaa', 'aa_$_ddd', ],
        emptyerror => 'Kein Benutzername',
        errormsg => [ 'Kein Benutzername', 'Benutzername ungültig' ],
    };
}

sub get_userid_check_hash {
    my $userid = shift // int rand 100000;
    return {
        name       => 'userid',
        good       => $userid,
        bad        => [ '', 'aa', ' ' x 7, "abc" . int( rand 10000 ) . "def", ],
        emptyerror => 'Keine Benutzerid',
        errormsg => [ 'Keine Benutzerid', 'Benutzer ungültig' ],
    };
}

sub alter_password {
    my $user  = shift;
    my $newpw = randstr();
    while ( $user->{password} eq $newpw ) {
        $newpw = randstr();
    }
    $user->{password}    = $newpw;
    $user->{faulty}      = 1;
    $user->{pseudoname} .= ' (faulty password)';
    return $user;
}

sub get_noneexisting_username {
    my $newname = randstr();
    while ( ( Ffc::Data::dbh()->selectrow_array('SELECT COUNT(u.id) FROM '.$Ffc::Data::Prefix.'users u WHERE u.name=?', undef, $newname ) )[0] ) {
        $newname = randstr();
    }
    return $newname;
}
sub get_noneexisting_userid {
    return (Ffc::Data::dbh->selectrow_array('SELECT MAX(u.id) + 1 FROM '.$Ffc::Data::Prefix.'users u'))[0];
}

1;

