package Ffc::Data::Board::Avatars;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;
use File::Path qw(make_path);

sub _get_avatarfile {
    my $username = shift;
    my $userid = Ffc::Data::Auth::get_userid( $username );
    my $row = Ffc::Data::dbh()->selectall_arrayref('SELECT u.avatar FROM '.$Ffc::Data::Prefix.'users u WHERE u.id = ?', undef, $userid);
    croak qq(Keine Avatare gefunden für den Benutzer) unless @$row;
    return $userid, $row->[0]->[0];

}

sub upload_avatar {
    my ( $c, $username, $parameter ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    my $path = "$Ffc::Data::AvatarDir/$username";
    make_path $path;
    `chmod '770' '$path'`;
    if ( $avatarfile ) {
        my $oldpath = "$path/$avatarfile";
        unlink $oldpath if -e $oldpath;
        croak qq(could not delete old avatar for user "$username": $!) if -e $oldpath;
    }
    {
        my $newfile = $c->param( $paramter );
        return unless $newfile;
        $newpath = "$path/" . $newfile->name;
        croak qq(new avatar for user "$username" allready exists somehow) if -e $newpath;
        $newfile->move_to( $newpath ) or croak qq(could not overwrite avatar for user "$username": $!);
        `chmod '660' '$newpath'`;
    }
}

sub download_avatar_path {
    my ( $username ) = @_;
    my ( $userid, $avatarfile ) = _get_avatarfile( $username );
    return unless $avatarfile;
    my $path = "$Ffc::Data::AvatarDir/$username/$avatarfile";
    return unless -e $path;
    return $path;
}

