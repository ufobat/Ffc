package AltSimpleBoard::Data::Auth;

use 5.010;
use strict;
use warnings;
use utf8;
use AltSimpleBoard::Data;

sub get_userdata {
    my ( $user, $pass ) = @_;
    my $sql = << 'EOSQL';
SELECT ben_admin, ben_status, ben_news, ben_id i, case when ben_css is null or ben_css = '' then ? else ben_css end as css, ben_showimages
FROM ben_benutzer 
WHERE lower(ben_user)=lower(?) AND ben_pw=?
EOSQL
    AltSimpleBoard::Data::dbh()
      ->selectrow_array( $sql, undef, $AltSimpleBoard::Data::DefaultStyle, $user, $pass );
}

sub get_lastsessiondata {
    my $user = shift;

    my $dbh = AltSimpleBoard::Data::dbh();
    my $sql = << "EOSQL";
SELECT tex_id, tex_dat 
FROM tex_text 
ORDER BY tex_id DESC 
LIMIT 1 OFFSET 10
EOSQL
    my $tex_id = $dbh->selectrow_arrayref($sql)->[0] // 0;

    $sql = << 'EOSQL';
SELECT log_timestamp 
FROM log_login 
WHERE lower(ben_fk)=lower(?)
EOSQL
    my $last_login = ( $dbh->selectrow_array( $sql, undef, $user ) )[0]
      // $tex_id;

    return $tex_id, $last_login;
}

sub update_usersession {
    my ( $session, $user ) = @_;
    my $sql = << 'EOSQL';
UPDATE ben_benutzer 
SET 
    ben_lastdate = ben_dat,
    ben_session  = ?,
    ben_dat      = now(),
    ben_kick     = 0
WHERE lower(ben_user)=lower(?)
EOSQL
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $session, $user );
}

sub logout {
    my $user = shift;
    AltSimpleBoard::Data::dbh()->do(
q{UPDATE ben_benutzer SET ben_session='' WHERE lower(ben_user)=lower(? );
        }
        , undef, $user
    );
}

sub check_login_status {
    my $sql = << 'EOSQL';
SELECT ben_session 
FROM ben_benutzer 
WHERE lower(ben_user)=lower(?) 
  AND ben_session IS NOT NULL AND ben_session <> ''
EOSQL
    @{ AltSimpleBoard::Data::dbh()->selectall_arrayref( $sql, undef, $_[0] ) } > 0 ? 1 : 0;
}

1;

