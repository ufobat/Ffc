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
    $from = _get_userid( $from, 'Auto des zu löschenden Beitrages' );
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    my $sql = sprintf 'DELETE FROM '.$Ffc::Data::Prefix.'posts WHERE %s=? and %s=? AND (%s IS NULL OR %s=%s);', map {$dbh->quote_identifier($_)} qw(id from to to from);
    $dbh->do( $sql, undef, $id, $from );
}

sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    $f = _get_userid( $f, 'Autor des neuen Beitrages' );
    die q(Kein Beitrag angegeben) unless $d;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $cid = undef;
    $cid = _get_category_id($c) if $c;
    $t = _get_userid( $t, 'Empfänger des neuen Beitrages' ) if $t;
    my $dbh = Ffc::Data::dbh();
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'posts ('.join(', ',map {$dbh->quote_identifier($_)} qw(from to text posted category)).') VALUES (?, ?, ?, current_timestamp, ?)';
    $dbh->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i ) = @_;
    $f = _get_userid( $f, 'Autor des bestehenden Beitrages' );
    die q(Kein Beitrag angegeben) unless $d;
    die qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    die qq(Keine Postid angegeben) unless $i;
    die qq{Postid ungültig} unless $i =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    my $fromstr = $dbh->quote_identifier('from');
    my $tostr = $dbh->quote_identifier('to');
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'posts SET text=?, posted=current_timestamp WHERE id=? AND '.$fromstr.'=? AND ('.$tostr.' IS NULL OR '.$tostr.'='.$fromstr.');';
    Ffc::Data::dbh()->do( $sql, undef, $d, $i, $f );
}

1;

