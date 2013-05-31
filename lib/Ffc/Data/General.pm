package Ffc::Data::General;

use 5.010;
use strict;
use warnings;
use utf8;

use Carp;

use Ffc::Data;
use Ffc::Data::Auth;

sub check_category_short_rules {
    my $c = shift;
    croak qq{Kein Kategoriekürzel angegeben} unless $c;
    croak qq{Kategoriekürzel ungültig} unless $c =~ m/\A$Ffc::Data::CategoryRegex\z/xms;
    return 1;
}

sub check_password_change {
    my ( $newpw1, $newpw2, $oldpw ) = @_;
    for ( ( $oldpw ? ['Altes Passwort' => $oldpw] : () ), ['Neues Passwort' => $newpw1], ['Passwortwiederholung' => $newpw2] ) {
        Ffc::Data::Auth::check_password_rules($_->[1]);
    }
    croak qq{Das neue Passwort und dessen Wiederholung stimmen nicht überein} unless $newpw1 eq $newpw2;
    return 1;
}

sub get_category_id {
    my $c = shift;
    check_category_short_rules( $c );
    my $sql = 'SELECT c.id FROM '.$Ffc::Data::Prefix.'categories c WHERE c.short=?';
    my $cats = Ffc::Data::dbh()->selectall_arrayref($sql, undef, $c);
    croak qq{Kategorie ungültig} unless @$cats;
    return $cats->[0]->[0];
}

sub check_category { get_category_id($_[0]) ? 1 : 0 }

sub get_useremail {
    my $id = Ffc::Data::Auth::get_userid(shift);
    croak q{Keine Benutzerid angegeben} unless $id;
    croak q{Benutzerid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT u.email FROM '.$Ffc::Data::Prefix.'users u WHERE u.id=? AND u.active=1';
    my @res = Ffc::Data::dbh()->selectrow_array($sql, undef, $id);
    if ( @res ) {
        return $res[0];
    }
    else {
        croak qq{Benutzer unbekannt};
    }
}

sub get_userlist {
    my $sql = 'SELECT u.id, u.name, u.active, u.admin FROM '.$Ffc::Data::Prefix.'users u ORDER BY u.active DESC, u.name ASC';
    return Ffc::Data::dbh()->selectall_arrayref($sql);
}

sub get_category_short {
    my $id = shift;
    croak qq{Keine Kategorieid angegeben} unless $id;
    croak qq{Kategorieid ungültig} unless $id =~ m/\A\d+\z/xms;
    my $sql = 'SELECT c.short FROM '.$Ffc::Data::Prefix.'categories c WHERE c.id=? LIMIT 1';
    my @ret = Ffc::Data::dbh()->selectrow_array($sql, undef, $id);
    croak qq{Kategorieid ungültig} unless @ret;
    return $ret[0];
}

1;

