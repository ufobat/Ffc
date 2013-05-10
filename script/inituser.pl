#!/usr/bin/perl 
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojolicious;
use Ffc::Data;
{
    my $App = Mojolicious->new();
    $App->log->level('error');
    Ffc::Data::set_config($App);
}

print 'Wählen Sie einen Benutzernamen für den Administratoren: ';
my $username = <>;
chomp $username;
print 'Und jetzt noch ein initiales Passwort (lesbar an der Konsole!!!): ';
my $password = <>;
chomp $password;
my $sql = 'INSERT INTO '.$Ffc::Data::Prefix.'users (name, password, active, admin) VALUES (?,?,?,?)';
Ffc::Data::dbh()->do($sql, undef, $username, crypt($password, Ffc::Data::cryptsalt()), 1, 1);
say 'Bitte nicht vergessen, das Passwort umgehend über die entsprechende Einstellungsmaske zu ändern!!!';
  
