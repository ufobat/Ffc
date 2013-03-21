package Ffc::Data::Board::OptionsUser;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;
use Ffc::Data::General;

sub check_user { &Ffc::Data::Auth::check_user }
sub _check_password_change { &Ffc::Data::General::check_password_change }

sub update_email {
    my ( $userid, $email ) = @_;
    check_user( $userid );
    die qq{Neue Emailadresse ist zu lang (<=1024)} unless 1024 >= length $email;
    die qq(Neue Emailadresse schaut komisch aus) unless $email =~ m/\A[-.\w]+\@[-.\w]+\.\w+\z/xmsi;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users u SET u.email=? WHERE u.id=?';
    Ffc::Data::dbh()->do($sql, undef, $email, $userid);
}

sub update_password {
    my ( $userid, $oldpw, $newpw1, $newpw2 ) = @_;
    check_user( $userid );
    _check_password_change( $newpw1, $newpw2, $oldpw );
    die qq{Das alte Passwort ist falsch} unless Ffc::Data::Auth::check_password($userid, $oldpw);
    Ffc::Data::Auth::set_password($userid, $newpw1);
}

sub update_show_images {
    my $s = shift;
    my $x = shift;
    die qq{show_images muss 0 oder 1 sein} unless $x =~ m/\A[01]\z/xms;
    $s->{show_images} = $x;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users u SET u.show_images=? WHERE u.id=?';
    Ffc::Data::dbh()->do($sql, undef, $x, $s->{userid});
}

sub update_theme {
    my $s = shift;
    my $t = shift;
    die qq{Themenname zu lang (64 Zeichen maximal)} if 64 < length $t;
    die qq{Thema ungültig: $t} unless $t ~~ @Ffc::Data::Themes; 
    $s->{theme} = $t;
    my $sql = 'UPDATE '.$Ffc::Data::Prefix.'users u SET u.theme=? WHERE u.id=?';
    Ffc::Data::dbh()->do($sql, undef, $t, $s->{userid});
}

1;

