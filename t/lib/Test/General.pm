package Test::General;
use strict;
use warnings;
use utf8;
use Mojolicious;
use Mock::Config;
use Mock::Database;
use Mock::Testuser;
use Mock::Controller::App;
use Test::Mojo;
use Test::More;

our ( @Users, @Categories, $Maxcatid, $Maxuserid, $Config, $App );

sub test_get_max_postid {
    (
        Ffc::Data::dbh()->selectrow_array(
            'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'posts'
        )
    )[0];
}

sub test_get_max_categoryid {
    (
        Ffc::Data::dbh()->selectrow_array(
            'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'categories'
        )
    )[0];
}

sub test_get_max_userid {
    (
        Ffc::Data::dbh()->selectrow_array(
            'SELECT MAX("id") FROM ' . $Ffc::Data::Prefix . 'users'
        )
    )[0];
}

sub test_prepare_frontend {
    my $appname = shift;
    $ENV{FFC_CONFIG} = test_r()
        while !$ENV{FFC_CONFIG} or -e -r $ENV{FFC_CONFIG};
    note(qq(using "$ENV{FFC_CONFIG}" - that should generate an in-memory database));
    use_ok($appname);
    my $t = Test::Mojo->new($appname);
    $Ffc::Data::Testing = 1;
    Mock::Database::prepare_testdatabase();
    _generate_some_users();
    _get_component_values();
    return $t;
}

sub _generate_some_users {
    @Users =
      ( map { Mock::Testuser->new_active_user() } 8 .. 16 + int rand 16 );
}

sub _get_component_values {
    @Categories = @{
        Ffc::Data::dbh()->selectall_arrayref(
                'SELECT "id", "name", "short" FROM '
              . $Ffc::Data::Prefix
              . 'categories '
              . 'order by "sort", "name"'
        )
    };
    $Maxcatid  = test_get_max_categoryid();
    $Maxuserid = test_get_max_userid();
}

sub test_prepare {

    note('doing some preparations');
    $Config = Mock::Config->new->{config};
    $App    = Mojolicious->new();
    $App->log->level('error');
    Ffc::Data::set_config($App);
    Mock::Database::prepare_testdatabase();
    _generate_some_users();
    _get_component_values();
    return 1;
}

sub test_get_rand_category { $Categories[ int rand scalar @Categories ] }
sub test_get_rand_user     { $Users[ int rand scalar @Users ] }

{
    my @teststr = ('');
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
    my $g = sub { join '', map { $chars[ int rand scalar @chars ] } 0 .. 7 + int rand 5 };
    sub test_r {
        my $s = '';
        $s = $g->() while grep /$s/i, @teststr;
        return $s;
    }
}

sub test_get_non_category_short {
    my $cat = test_r();
    $cat = test_r() while grep { $_->[2] eq $cat } @Categories;
    return $cat;
}

sub test_get_non_username {
    my $username = test_r();
    $username = test_r() while grep { $_->{name} eq $username } @Users;
    return $username;
}

sub test_get_max_post {
    return Ffc::Data::dbh()
      ->selectrow_arrayref(
'SELECT p."id", p."textdata", p."user_from", p."user_to", p."category" FROM '
          . $Ffc::Data::Prefix
          . 'posts p ORDER BY p."id" DESC' );
}

sub test_update_userstats {
    my $user = shift;
    my $has_cats = shift;
    sleep 1.1;
    for my $act (qw(forum msgs notes)) {
        for my $cat ( '',
            ( $has_cats ? map( { $_->[2] } @Categories) : () ) )
        {
            eval {
                Ffc::Data::Board::update_user_stats( $user->{name}, $act,
                    $cat );
            };
            diag(
qq(update users status for act "$act" before next insert failed: $@)
            ) if $@;
        }
    }
    sleep 1.1;
}

1;

