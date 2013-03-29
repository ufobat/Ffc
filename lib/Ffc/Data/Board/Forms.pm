package Ffc::Data::Board::Forms;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub _get_userid { &Ffc::Data::Auth::get_userid }
sub _get_category_id { &Ffc::Data::General::get_category_id }

sub delete_post {
    my ( $from, $id ) = @_;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    $from = _get_userid( $from, 'Auto des zu löschenden Beitrages' );
    my $dbh = Ffc::Data::dbh();
    my $sql = sprintf 'DELETE FROM '.$Ffc::Data::Prefix.'posts WHERE %s=? and %s=? AND (%s IS NULL OR %s=%s);', map {$dbh->quote_identifier($_)} qw(id from to to from);
    $dbh->do( $sql, undef, $id, $from );
}
sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    $f = _get_userid( $f, 'Autor des neuen Beitrages' );
    $t = _get_userid( $t, 'Empfänger des neuen Beitrages' ) if $t and $t != $f;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $cid = $c ? _get_category_id($c) : undef;
    my $dbh = Ffc::Data::dbh();
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'posts ('.join(', ',map {$dbh->quote_identifier($_)} qw(from to text posted category)).') VALUES (?, ?, ?, current_timestamp, ?)';
    $dbh->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i ) = @_;
    $f = _get_userid( $f, 'Autor des bestehenden Beitrages' );
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'posts p SET p.text=?, p.posted=current_timestamp WHERE p.id=? AND p.from=? AND (p.to IS NULL OR p.to=p.from);';
    Ffc::Data::dbh()->do( $sql, undef, $d, $i, $f );
}

1;

