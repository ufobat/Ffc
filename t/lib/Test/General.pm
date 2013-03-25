package Test::General;
use strict;
use warnings;
use utf8;
use Mojolicious;
use Mock::Config;
use Mock::Database;
use Mock::Testuser;
use Mock::Controller::App;
use Test::More;

our ( @Users, @Categories, $Maxcatid, $Maxuserid, $Config, $App );

sub test_get_max_categoryid {
    (
        Ffc::Data::dbh()->selectall_arrayref(
            'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'categories'
        )
    )[0];
}

sub test_get_max_userid {
    (
        Ffc::Data::dbh()->selectall_arrayref(
            'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'users'
        )
    )[0];
}

sub test_prepare {

    note('doing some preparations');
    $Config = Mock::Config->new->{config};
    $App    = Mojolicious->new();
    $App->log->level('error');
    Ffc::Data::set_config($App);
    Mock::Database::prepare_testdatabase();
    @Users = ( map { Mock::Testuser->new_active_user() } 3 .. 5 + int rand 20 );
    @Categories = @{
        Ffc::Data::dbh()->selectall_arrayref(
                'SELECT "id", "name", "short" FROM '
              . $Ffc::Data::Prefix
              . 'categories'
        )
    };
    $Maxcatid  = test_get_max_categoryid();
    $Maxuserid = test_get_max_userid();
    return 1;
}

sub test_get_rand_category { $Categories[ int rand scalar @Categories ] }
sub test_get_rand_user     { $Users[ int rand scalar @Users ] }

sub test_r {
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
    return join '',
      map { $chars[ int rand scalar @chars ] } 0 .. 7 + int rand 5;
}

sub test_get_non_category_short {
    my $cat = test_r();
    $cat = test_r() while grep { $_->[2] eq $cat } @Categories;
    return $cat;
}

1;

