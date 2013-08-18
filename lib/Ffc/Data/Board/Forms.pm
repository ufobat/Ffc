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
    my ( $from, $id ) = @_;
    $from = _get_userid( $from, 'Auto des zu löschenden Beitrages' );
    croak qq(Keine Postid angegeben) unless $id;
    croak qq{Postid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    for my $r ( @{ $dbh->selectall_arrayref('SELECT number FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=?', undef, $id) } ) {
        my $path = Ffc::Data::Board::Uploads::make_path($id, $r->[0]);
        if ( -e $path ) {
            unlink $path or croak qq(could not delete attachement number "$r->[0]" for post: $!);
        }
        $dbh->do( 'DELETE FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=? AND number=?', undef, $id, $r->[0] );
    }
    $dbh->do('DELETE FROM '.$Ffc::Data::Prefix.'posts WHERE id=? and user_from=? AND (user_to IS NULL OR user_from=user_to)', undef, $id, $from );
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
    my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'posts (user_from, user_to, textdata, posted, category) VALUES (?, ?, ?, current_timestamp, ?)';
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
    #FIXME: does not work yet
    #my $sql = 'SELECT COUNT(id) FROM '.$Ffc::Data::Prefix."posts $where";
    #croak qq(Kein entsprechender Beitrag vom angegebenen Benutzer bekannt) unless ($dbh->selectrow_array($sql, undef, $i, $f))[0];
    my $sql = 'UPDATE '.$Ffc::Data::Prefix."posts SET textdata=? $where;";
    $dbh->do( $sql, undef, $d, $i, $f );
}

1;

