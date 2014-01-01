package Ffc::Data::Board::Forms;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;
use Ffc::Data::Board::Upload;

sub _get_userid { &Ffc::Data::Auth::get_userid }
sub _get_category_id { &Ffc::Data::General::get_category_id }

sub delete_post {
    my ( $username, $id ) = @_;
    my $from = _get_userid( $username, 'Autor des zu löschenden Beitrages' );
    croak qq(Keine Postid angegeben) unless $id;
    croak qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $where = 'WHERE id=? AND user_from=? AND (user_to IS NULL OR user_from=user_to)';
    my $sql = 'SELECT COUNT(id) FROM '.$Ffc::Data::Prefix."posts $where";
    my $dbh = Ffc::Data::dbh();
    croak qq(Kein entsprechender Beitrag vom angegebenen Benutzer bekannt) unless 1 == $dbh->selectall_arrayref($sql, undef, $id, $from)->[0]->[0];
    Ffc::Data::Board::Upload::delete_attachements($username, $id);
    $dbh->do('DELETE FROM '.$Ffc::Data::Prefix.'posts '.$where, undef, $id, $from );
    return 1;
}

sub insert_post {
    my ( $f, $d, $c, $t ) = @_;
    $f = _get_userid( $f, 'Autor des neuen Beitrages' );
    croak q(Kein Beitrag angegeben) unless $d;
    croak qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    my $cid = undef;
    $cid = _get_category_id($c) if $c;
    $t = _get_userid( $t, 'Empfänger des neuen Beitrages' ) if $t;
    $cid = undef if $t; # bei Privatnachrichten und Notizen gibts keine Kategorien
    my $dbh = Ffc::Data::dbh();
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'posts (user_from, user_to, textdata, posted, altered, category) VALUES (?, ?, ?, current_timestamp, current_timestamp, ?)';
    $dbh->do( $sql, undef, $f, $t, $d, $cid );
}

sub update_post {
    my ( $f, $d, $i ) = @_;
    $f = _get_userid( $f, 'Autor des bestehenden Beitrages' );
    croak q(Kein Beitrag angegeben) unless $d;
    croak qq{Beitrag ungültig, zu wenig Zeichen (min. 2)} if 2 >= length $d;
    croak qq(Keine Postid angegeben) unless $i;
    croak qq{Postid ungültig} unless $i =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    my $where = 'WHERE id=? AND user_from=? AND (user_to IS NULL OR user_from=user_to)';
    my $sql = 'SELECT COUNT(id) FROM '.$Ffc::Data::Prefix."posts $where";
    croak qq(Kein entsprechender Beitrag vom angegebenen Benutzer bekannt) unless 1 == $dbh->selectall_arrayref($sql, undef, $i, $f)->[0]->[0];
    $sql = 'UPDATE '.$Ffc::Data::Prefix."posts SET textdata=?, altered=current_timestamp $where;";
    $dbh->do( $sql, undef, $d, $i, $f );
}

1;

