package Ffc::Data::Board;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub get_userid { &Ffc::Data::Auth::get_userid }
sub get_category_id { &Ffc::Data::General::get_category_id }

sub _update_user_forum {
    my $userid = $_[0];
    my $category = $_[2];
    if ( $category ) {
        my $category = get_category_id($category);
        my $sql = 'SELECT COUNT(l.userid) FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?';
        my $dbh = Ffc::Data::dbh();
        if ( ( $dbh->selectrow_array( $sql, undef, $userid, $category ) )[0] ) {
            $sql = 'UPDATE '.$Ffc::Data::Prefix.'lastseenforum SET lastseen=current_timestamp WHERE userid=? AND category=?';
        }
        else {
            $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'lastseenforum (lastseen, userid, category) VALUES (current_timestamp, ?, ?)';
        }
        $dbh->do( $sql, undef, $userid, $category );
    }
    else {
        my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET lastseenforum=current_timestamp WHERE id=?;';
        Ffc::Data::dbh()->do( $sql, undef, $userid );
    }
}

sub _update_user_msgs {
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET lastseenmsgs=current_timestamp WHERE id=?;';
    Ffc::Data::dbh()->do( $sql, undef, $_[0] );
}
# ( $userid, $act, $category )
sub update_user_stats {
    my $userid = get_userid( shift );
    given ( $_[0] ) {
        when ( 'forum' ) { _update_user_forum( $userid, @_ ) }
        when ( 'msgs'  ) { _update_user_msgs(  $userid, @_ ) }
        when ( 'notes' ) {}
        default { die 'Abschnitt ungültig' }
    }
    return 1;
}

1;

