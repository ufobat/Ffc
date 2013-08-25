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

sub upload {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $newfile, $description, $move_to_code ) = @_;
    croak qq(Dateiname fehlt) unless $newfile;
    $description = '' unless $description;
    croak qq(Weiß nicht, was ich mit der Datei machen soll) unless $move_to_code and 'CODE' eq ref $move_to_code;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    die qq(Dateiname ungültig) unless $newfile and $newfile =~ m/\A[-\.\w]{1,255}\z/xms;
    die qq(Beschreibung ungültig) if $description and $description !~ m/\A.{1,255}\z/xms;
    my $dbh = Ffc::Data::dbh();
    my $anum = 1 + $dbh->selectall_arrayref('SELECT COUNT(a.id) FROM '.$Ffc::Data::Prefix.'posts p LEFT OUTER JOIN '.$Ffc::Data::Prefix.'attachements a ON a.postid=p.id WHERE p.user_from=? and p.id=?', undef, $userid, $postid)->[0]->[0];
    my $newpath = _make_path($postid, $anum);
    $move_to_code->($newpath) or croak qq(could not move upload file to upload storage directory "$Ffc::Data::UploadDir": $!);
    $dbh->('INSERT INTO '.$Ffc::Data::Prefix.'attachements (postid, number, filename, description) VALUES (?,?,?,?)', undef, $postid, $anum, $newpath, $description);
    return 1;
}

sub delete_upload {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $attachementnr ) = @_;
    die qq(Ungültiger Beitrag) unless $postid        and $postid        =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $attachementnr and $attachementnr =~ m/\A\d+\z/xms;
    my $dbh = Ffc::Data::dbh();
    unless ( $dbh->selectrow_arrayref('SELECT COUNT(a.id) FROM '.$Ffc::Data::Prefix.'posts p INNER JOIN '.$Ffc::Data::Prefix.'attachements a ON p.id = a.postid WHERE p.user_from=? AND p.id=? AND a.id=?', undef, $userid, $postid, $attachementnr)->[0]->[0] ) {
        croak qq(Anhang ungültig oder Benutzer nicht berechtigt, den genannten Anhang zu löschen);
    }
    my $path = _make_path($postid, $attachementnr);
    unlink $path or croak qq(could not delete uploaded file "$path": $!);
    $dbh->do('DELETE FROM '.$Ffc::Data::Prefix.'attachements WHERE postid=? AND number=?', undef, $postid, $attachementnr);
    $dbh->do('UPDATE '.$Ffc::Data::Prefix.'attachements SET number = number - 1 WHERE postid=? AND number>', undef, $postid, $attachementnr);
    return 1;
}

sub get_attachement {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my ( $postid, $attachementnr ) = @_;
    die qq(Ungültiger Beitrag) unless $postid        and $postid        =~ m/\A\d+\z/xms;
    die qq(Ungültiger Anhang)  unless $attachementnr and $attachementnr =~ m/\A\d+\z/xms;
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT a.filename, a.description FROM '.$Ffc::Data::Prefix.'attachements a INNER JOIN '.$Ffc::Data::Prefix.'posts p ON a.postid=p.id WHERE a.postid=? AND a.number=? AND ( p.user_from=? OR ( p.user_to IS NULL OR p.user_to=? )', undef, $postid, $attachementnr, $userid, $userid );
    croak qq(Anhang Nummer "$attachementnr" ist unbekannt) unless @$ret;
    my $path = make_path($postid, $attachementnr);
    croak qq(Anhang Nummer "$attachementnr" gibt es nicht) unless -e -r $path;
    return @{ $ret->[0] }, $path;
}

sub get_attachement_list {
    my $userid = Ffc::Data::Auth::get_userid( shift );
    my $postid = shift;
    die qq(Ungültiger Beitrag) unless $postid and $postid =~ m/\A\d+\z/xms;
    my $ret = Ffc::Data::dbh()->selectall_arrayref('SELECT a.filename, a.description, a.number FROM '.$Ffc::Data::Prefix.'attachements a INNER JOIN '.$Ffc::Data::Prefix.'posts p ON a.postid=p.id WHERE a.postid=? AND ( p.user_from=? OR ( p.user_to IS NULL OR p.user_to=? )', undef, $postid, $userid, $userid );
    push @$_, make_path($postid, $_->[2]) for @$ret;
    return [ grep { -e -r $_->[3] } @$ret ];
}

1;

