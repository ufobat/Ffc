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
}

sub upload_avatar {
    my ( $c, $username, $parameter ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    if ( $avatarfile ) {
        my $oldpath = "$Ffc::Data::AvatarDir/$avatarfile";
        unlink $oldpath or croak qq(could not delete old avatar file for user "$username": $!) if -e $oldpath;
    }
    my $newfile = $c->param( $paramter );
    return unless $newfile;
    croak qq(need an image file: jpeg, bmp, gif, png) unless $newfile =~ m/\.(gif|bmp|jpe?g|png)\z/xmsi;
    my $ext = lc $1;
    my $file = "$username.$ext";
    $newpath = "$Ffc::Data::AvatarDir/$file";
    croak qq(new avatar for user "$username" allready exists somehow) if -e $newpath;
    $newfile->move_to( $newpath ) or croak qq(could not overwrite avatar for user "$username": $!);
    `chmod '660' '$newpath'`;
    `chgrp 'www' '$newpath'`;
    _set_avatarfile( $userid, $file );
}

sub get_avatar_path {
    my ( $username ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    return unless $avatarfile;
    my $path = "$Ffc::Data::AvatarDir/$avatarfile";
    return unless -e $path;
    return $path;
}

