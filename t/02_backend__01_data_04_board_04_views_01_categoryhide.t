use strict;
use warnings;
use 5.010;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Test::Callcheck;
use Test::General;
use Mock::Controller;
use Mock::Testuser;
use Ffc::Data::Auth;
use Ffc::Data::Board;
use Ffc::Data::Board::Forms;
use Ffc::Data::Board::OptionsUser;
srand;

use Test::More tests => 47;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Views');

{
    my $user  = Mock::Testuser->new_active_user();
    note(q{sub get_all_categories( $username )});
    my @ret = check_call(
        \&Ffc::Data::Board::Views::get_all_categories,
        get_all_categories => {
            name => 'user name',
            good => $user->{name},
            bad  => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
            errormsg => [
                'Kein Benutzername angegeben',
                'Benutzername ungültig',
                'Benutzer unbekannt',
            ],
            emptyerror => 'Kein Benutzername angegeben',
        },
    );
    ok( @ret, 'something was returned' );
    my @cats = map { $_->[2] } @Test::General::Categories;
    cmp_ok(scalar( @{ $ret[0] } ), '>', 0, 'category count ok');
    is(
        scalar( @{ $ret[0] } ),
        ( scalar(@cats) + 1 ),
        'data for every single category including "Allgemein" returned'
    );
    for my $r ( @{ $ret[0] } ) {
        ok( grep( $r->[1], @cats ), qq'return value "$r->[1]" is a category' )
          if $r->[1];
        is( $r->[2], 0,
            qq'return value of "$r->[1]" is zero before the actual inserts' );
    }
    is(join('', @cats), join('', map {$_->[1]} @{ $ret[0] }), 'category order is ok');
}
{
    my $user  = Mock::Testuser->new_active_user();
    my $userid = Ffc::Data::Auth::get_userid( $user->{name}, 'angemeldeter Benutzer für Kategorieanzeige' );
    Test::General::test_update_userstats($user, 1);
    for my $catid ( map { $_->[0] } @Test::General::Categories ) {
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $catid) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 1, 'category show switch is ok (1)';
    }
    for my $cat ( @Test::General::Categories[0..4] ) {
        Ffc::Data::Board::OptionsUser::update_show_category($user->{name}, $cat->[2], 0);
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $cat->[0]) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 0, 'category show switch is ok (0)';
    }
    for my $catid ( map { $_->[0] } @Test::General::Categories[5..8] ) {
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $catid) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 1, 'category show switch is ok (1)';
    }
    my $user2 = Mock::Testuser->new_active_user();
}
