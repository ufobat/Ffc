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
    die qq(Keine Postid angegeben) unless $id;
    die qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    my $sql = sprintf 'DELETE FROM '.$Ffc::Data::Prefix.'posts WHERE id=? and user_from=? AND (user_to IS NULL OR user_from=user_to);';
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
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'posts (user_from, user_to, textdata, posted, category) VALUES (?, ?, ?, current_timestamp, ?)';
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
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'posts SET textdata=?, posted=current_timestamp WHERE id=? AND user_from=? AND (user_to IS NULL OR user_from=user_to);';
    Ffc::Data::dbh()->do( $sql, undef, $d, $i, $f );
}

1;

