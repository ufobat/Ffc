package Ffc::Data::Board::General;

use 5.010;
use strict;
use warnings;
use utf8;

use Ffc::Data;
use Ffc::Data::Auth;

sub check_password_change {
    my ( $newpw1, $newpw2, $oldpw ) = @_;
    for ( ( $oldpw ? ['Altes Passwort' => $oldpw] : () ), ['Neues Passwort' => $newpw1], ['Passwortwiederholung' => $newpw2] ) {
        Ffc::Data::Auth::check_password_rules($_);
    }
    die qq{Das neue Passwort und dessen Wiederholung stimmen nicht überein} unless $newpw1 eq $newpw2;
    return 1;
}

sub get_category_id {
    my $c = shift;
    die qq{Kategoriekürzel ungültig} unless $c =~ m/\A\w{1,64}\z/xms;
    my $sql = 'SELECT c.id FROM '.$Ffc::Data::Prefix.'categories c WHERE c.short=?';
    my $cats = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $c);
    die qq{Kategorie ungültig} unless @$cats;
    return $cats->[0]->[0];
}

sub check_category {
    return $_[0] if get_category_id($_[0]);
    return;
}

sub get_useremail {
    my $id = shift;
    Ffc::Data::Auth::check_user( $id );
    my $sql = 'SELECT u.email FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? AND u.active=1';
    return (Ffc::Data::dbh()->selectrow_array($sql, undef, $id))[0];
}

sub get_userlist {
    my $sql = 'SELECT u.id, u.name, u.active, u.admin FROM '.$Ffc::Data::Prefix.'users u ORDER BY u.active DESC, u.name ASC';
    return Ffc::Data::dbh()->selectall_arrayref($sql);
}

sub get_category {
    my $id = shift;
    die qq{Kategorie-ID ist ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT c.short FROM '.$Ffc::Data::Prefix.'categories c WHERE c.id=? LIMIT 1';
    ( Ffc::Data::dbh()->selectrow_array($sql, undef, $id) )[0];
}

1;

