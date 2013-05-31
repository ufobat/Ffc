#!/usr/bin/perl 
use 5.010;
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojolicious;
use Ffc::Data;
use Ffc::Data::Formats;
{
    my $App = Mojolicious->new();
    $App->log->level('error');
    Ffc::Data::set_config($App);
}

my $dbh = $Ffc::Data::dbh();
my $sth = $dbh->prepare('SELECT p.textdata FROM '.$Ffc::Data::Prefix.'posts p');
$sth->execute();
while ( my $rv = $sth->fetchrow_arrayref ) {
    $dbh->do('UPDATE '.$Ffc::Data::Prefix.'posts SET formattedtext=?', undef, Ffc::Formats::format_text($rv->[0]);
}

