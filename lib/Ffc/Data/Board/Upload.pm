package Ffc::Data::Board::Upload;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub make_path {
    my ( $postid, $anum ) = @_;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $anum   and $anum   =~ m/\A\d+\z/xms;
    return sprintf '%s/%d-%d', $Ffc::Data::UploadDir, $postid, $anum;
}

sub make_url {
    my ( $postid, $anum ) = @_;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $anum   and $anum   =~ m/\A\d+\z/xms;
    return sprintf '%s/%d-%d', $Ffc::Data::UploadUrl, $postid, $anum;
}


sub upload {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $newfile, $description, $move_to_code ) = @_;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    die qq(Ungültiger Beitrag für den Benutzer um Anhänge dran zu hängen) unless $dbh->selectall_arrayref('SELECT COUNT(p.id) FROM '.$Ffc::Data::Prefix.'posts p WHERE p.user_from=? AND p.id=?', undef, $userid, $postid)->[0]->[0];
    die q(Dateiname ").($newfile // '').q(" ungültig) unless $newfile and $newfile =~ m/\A.{1,1024}\z/xms;
    $description = $newfile unless $description and $description =~ m/\A.{1,255}\z/xms;
    croak qq(Weiß nicht, was ich mit der Datei machen soll) unless $move_to_code and 'CODE' eq ref $move_to_code;
    my $anum = $dbh->selectall_arrayref('SELECT MAX(COALESCE(a.number,0)) + 1 FROM '.$Ffc::Data::Prefix.'posts p LEFT OUTER JOIN '.$Ffc::Data::Prefix.'attachements a ON a.postid=p.id WHERE p.user_from=? and p.id=?', undef, $userid, $postid)->[0]->[0];
    my $newpath = make_path($postid, $anum);
    $dbh->do('INSERT INTO '.$Ffc::Data::Prefix.'attachements (postid, number, filename, description) VALUES (?,?,?,?)', undef, $postid, $anum, $newfile, $description);
    $move_to_code->($newpath) or croak qq(Kann die Anhangsdatei nicht im Speicher "$Ffc::Data::UploadDir" ablegen: $!);
    return 1;
}

sub delete_upload {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $attachementnr ) = @_;
    die qq(Ungültiger Beitrag) unless $postid        and $postid        =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $attachementnr and $attachementnr =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    unless ( $dbh->selectrow_arrayref('SELECT COUNT(a.number) FROM '.$Ffc::Data::Prefix.'posts p INNER JOIN '.$Ffc::Data::Prefix.'attachements a ON p.id = a.postid WHERE p.user_from=? AND p.id=? AND a.number=?', undef, $userid, $postid, $attachementnr)->[0] ) {
        croak qq(Anhang ungültig oder Benutzer nicht berechtigt, den genannten Anhang zu löschen);
    }
    my $path = make_path($postid, $attachementnr);
    unlink $path or croak qq(could not delete uploaded file "$path": $!);
    $dbh->do('DELETE FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=? AND number=?', undef, $postid, $attachementnr);
    return 1;
}

sub delete_attachements {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my $postid = shift;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    unless ( $dbh->selectall_arrayref('SELECT COUNT(p.id) FROM '.$Ffc::Data::Prefix.'posts p WHERE p.user_from=? AND p.id=?', undef, $userid, $postid)->[0]->[0] == 1 ) {
        croak 'Benutzer darf den Beitrag nicht löschen';
    }
    for my $r ( @{ $dbh->selectall_arrayref('SELECT number FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=?', undef, $postid) } ) {
        my $path = make_path($postid, $r->[0]);
        if ( -e $path ) {
            unlink $path or croak qq(could not delete attachement number "$r->[0]" for post: $!);
        }
    }
    $dbh->do( 'DELETE FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=?', undef, $postid );
}

sub get_attachement {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $attachementnr ) = @_;
    die qq(Ungültiger Beitrag) unless $postid        and $postid        =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $attachementnr and $attachementnr =~ m/\A\d+\z/xms;
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT a.filename, a.description FROM '.$Ffc::Data::Prefix.'attachements a INNER JOIN '.$Ffc::Data::Prefix.'posts p ON a.postid=p.id WHERE a.postid=? AND a.number=? AND ( p.user_from=? OR ( p.user_to IS NULL OR p.user_to=? ) )', undef, $postid, $attachementnr, $userid, $userid );
    croak qq(Anhang Nummer "$attachementnr" ist unbekannt) unless @$ret;
    my $path = make_path($postid, $attachementnr);
    croak qq(Anhang Nummer "$attachementnr" gibt es nicht) unless -e -r $path;
    my $url = make_url($postid, $attachementnr);
    return [ @{ $ret->[0] }, $url, $path ];
}

sub get_attachement_list {
    my $userid = shift;
    Ffc::Data::Auth::check_userid_rules($userid);
    my $postid = shift;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT a.filename, a.description, a.number, a.postid FROM '.$Ffc::Data::Prefix.'attachements a INNER JOIN '.$Ffc::Data::Prefix.'posts p ON a.postid=p.id WHERE a.postid=? AND ( p.user_from=? OR ( p.user_to IS NULL OR p.user_to=? ) )', undef, $postid, $userid, $userid );
    return [] unless @$ret;
    push @$_, make_url($postid, $_->[2]), make_path($postid, $_->[2]) for @$ret;
    return [ grep { -e -r $_->[5] } @$ret ];
}

1;

