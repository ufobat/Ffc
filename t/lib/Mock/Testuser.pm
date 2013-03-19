package Mock::Testuser;

use strict;
use warnings;
use utf8;
use Ffc::Data;
use Data::Dumper;
srand;

sub new_admin { shift->new(1) }
sub new_user  { shift->new(0) }
sub new { bless _generate_testuser( $_[1] ), $_[0] }

sub randstr {
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
sub _generate_testuser {
    my $isadmin   = shift // 0;
    my $username  = randstr();
    my $password  = randstr();
    my $useremail = "$username\@" . randstr() . '.org';

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

1;

