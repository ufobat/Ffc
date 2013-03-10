package AltSimpleBoard::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;

use AltSimpleBoard::Data;
use AltSimpleBoard::Data::Board::General;

sub check_user { &AltSimpleBoard::Data::Board::General::check_user }
sub get_category_id { &AltSimpleBoard::Data::Board::General::get_category_id }

sub _update_user_forum {
    my $userid = shift;
    check_user( $userid );
    my $category = $_[1];
    if ( $category ) {
        my $category = get_category_id($category);
        my $sql = 'SELECT COUNT(l.userid) FROM '.$AltSimpleBoard::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?';
        my $dbh = AltSimpleBoard::Data::dbh();
        if ( ( $dbh->selectrow_array( $sql, undef, $userid, $category ) )[0] ) {
            $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'lastseenforum l SET l.lastseen=current_timestamp WHERE l.userid=? AND l.category=?';
        }
        else {
            $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'lastseenforum (lastseen, userid, category) VALUES (current_timestamp, ?, ?)';
        }
        $dbh->do( $sql, undef, $userid, $category );
    }
    else {
        my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.lastseenforum=current_timestamp WHERE u.id=?;';
        AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
    }
}

sub _update_user_msgs {
    my $userid = shift;
    check_user( $userid );
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'users u SET u.lastseenmsgs=current_timestamp WHERE u.id=?;';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $userid );
}
sub update_user_stats {
    given ( $_[1] ) {
        when ( 'forum' ) { _update_user_forum( @_ ) }
        when ( 'msgs'  ) { _update_user_msgs(  @_ ) }
    }
}

1;

