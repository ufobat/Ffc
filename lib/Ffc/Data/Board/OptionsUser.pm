package Ffc::Data::Board::OptionsUser;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub _get_userid { &Ffc::Data::Auth::get_userid }
sub _check_password_change { &Ffc::Data::General::check_password_change }

sub update_email {
    my $userid = _get_userid( shift, 'angemeldeter Benutzer für Email-Einstellung' );
    my $email = shift;
    croak qq{Keine Emailadresse angegeben} unless $email;
    croak qq{Neue Emailadresse ist zu lang (<=1024)} unless 1024 >= length $email;
    croak qq(Neue Emailadresse schaut komisch aus) unless $email =~ m/\A[-.\w]+\@[-.\w]+\.\w+\z/xmsi;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET email=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, $email, $userid);
    return 1;
}

sub update_password {
    my $userid = _get_userid( shift, 'angemeldeter Benutzer für croak Passwortänderung' );
    my ( $oldpw, $newpw1, $newpw2 ) = @_;
    _check_password_change( $newpw1, $newpw2, $oldpw );
    croak qq{Das alte Passwort ist falsch} unless Ffc::Data::Auth::check_password($userid, $oldpw);
    Ffc::Data::Auth::set_password($userid, $newpw1);
}

sub update_show_images {
    my $s = shift;
    croak q(Session-Hash als erster Parameter benötigt) unless $s and 'HASH' eq ref $s;
    my $userid = _get_userid( $s->{user}, 'Angemeldeter Benutzer für croak Bildanzeigeeinstellung' );
    my $x = shift;
    croak q{show_images nicht angegeben} unless defined $x;
    croak q{show_images muss 0 oder 1 sein} unless $x =~ m/\A[01]\z/xms;
    $s->{show_images} = $x;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET show_images=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, $x, $userid);
    return 1;
}

sub update_theme {
    my $s = shift;
    croak q(Session-Hash als erster Parameter benötigt) unless $s and 'HASH' eq ref $s;
    my $userid = _get_userid( $s->{user}, 'Angemeldeter Benutzer für croak optischen Einstellung' );
    my $t = shift;
    croak q{Themenname nicht angegeben} unless $t;
    croak q{Themenname zu lang (64 Zeichen maximal)} if 64 < length $t;
    croak qq{Thema ungültig: $t} unless $t ~~ @Ffc::Data::Themes; 
    $s->{theme} = $t;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users SET theme=? WHERE id=?';
    Ffc::Data::dbh()->do($sql, undef, $t, $userid);
    return 1;
}

1;

