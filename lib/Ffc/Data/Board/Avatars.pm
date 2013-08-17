package Ffc::Data::Board::Avatars;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;

sub _get_avatarfile {
    my $username = shift;
    my $userid = Ffc::Data::Auth::get_userid( $username );
    my $row = Ffc::Data::dbh()->selectall_arrayref('SELECT u.avatar FROM '.$Ffc::Data::Prefix.'users u WHERE u.id = ?', undef, $userid);
    croak qq(Keine Avatare gefunden für den Benutzer) unless @$row;
    return $userid, $row->[0]->[0];

}

sub _set_avatarfile {
    my ( $userid, $file ) = @_;
    Ffc::Data::dbh()->do('UPDATE '.$Ffc::Data::Prefix.'users SET avatar=? WHERE id=?', undef, $file, $userid);
    return $file;
}

sub upload_avatar {
    my ( $username, $newfile, $move_to_code ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    croak qq(Avatardateiname fehlt) unless $newfile;
    croak qq(Avatar muss eine Bilddatei sein: jpeg, bmp, gif, png) unless $newfile =~ m/\.(gif|bmp|jpe?g|png)\z/xmsi;
    my $ext = lc $1;
    croak qq(Weiß nicht, was ich mit der Avatardatei machen muss) unless $move_to_code;
    croak qq(Benötige eine Code-Referenz, um mit der Avatardatei umgehen zu können) unless 'CODE' eq ref $move_to_code;
    my $file = "$username.$ext";
    my $newpath = "$Ffc::Data::AvatarDir/$file";
    if ( $avatarfile ) {
        my $oldpath = "$Ffc::Data::AvatarDir/$avatarfile";
        unlink $oldpath or croak qq(could not delete old avatar file for user "$username": $!) if -e $oldpath;
    }
    croak qq(new avatar for user "$username" allready exists somehow) if -e $newpath;
    $move_to_code->( $newpath ) or croak qq(could not move avatar file for user "$username": $!);
    return _set_avatarfile( $userid, $file );
}

sub get_avatar_path {
    my ( $username ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    return unless $avatarfile;
    my $path = "$Ffc::Data::AvatarDir/$avatarfile";
    return unless -e $path;
    return "$Ffc::Data::AvatarUrl/$avatarfile";
}

1;

