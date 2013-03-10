package AltSimpleBoard::Data::Board::Forms;

use 5.010;
use strict;
use warnings;
use utf8;

use AltSimpleBoard::Data;
use AltSimpleBoard::Data::Board::General;

sub check_user { &AltSimpleBoard::Data::Board::General::check_user }
sub get_category_id { &AltSimpleBoard::Data::Board::General::get_category_id }

sub delete_post {
    my ( $from, $id ) = @_;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    check_user( $from );
    my $dbh = AltSimpleBoard::Data::dbh();
    my $sql = sprintf 'DELETE FROM '.$AltSimpleBoard::Data::Prefix.'posts WHERE %s=? and %s=? AND (%s IS NULL OR %s=%s);', map {$dbh->quote_identifier($_)} qw(id from to to from);
    $dbh->do( $sql, undef, $id, $from );
}
sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    check_user( $f, 'Sender des Beitrages unbekannt' );
    check_user( $t, 'Empfänger des Beitrages unbekannt' ) if $t;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $cid = $c ? get_category_id($c) : undef;
    my $dbh = AltSimpleBoard::Data::dbh();
    my $sql = 'INSERT INTO '.$AltSimpleBoard::Data::Prefix.'posts ('.join(', ',map {$dbh->quote_identifier($_)} qw(from to text posted category)).') VALUES (?, ?, ?, current_timestamp, ?)';
    $dbh->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i, $t ) = @_;
    check_user( $f, 'Sender des Beitrages unbekannt' );
    check_user( $t, 'Empfänger des Beitrages unbekannt' ) if $t;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $sql = 'UPDATE '.$AltSimpleBoard::Data::Prefix.'posts p SET p.text=?, p.posted=current_timestamp, p.to=? WHERE p.id=? AND p.from=? AND (p.to IS NULL OR p.to=p.from);';
    AltSimpleBoard::Data::dbh()->do( $sql, undef, $d, $t, $i, $f );
}
1;

