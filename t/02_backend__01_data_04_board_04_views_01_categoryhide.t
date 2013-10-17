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

use Test::More tests => 66;

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
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show_cat FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $catid) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 1, 'category show switch is ok (1)';
    }
    for my $cat ( @Test::General::Categories[0..4] ) {
        Ffc::Data::Board::OptionsUser::update_show_category($user->{name}, $cat->[2], 0);
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show_cat FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $cat->[0]) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 0, 'category show switch is ok (0)';
    }
    for my $catid ( map { $_->[0] } @Test::General::Categories[5..8] ) {
        my $ret = ( Ffc::Data::dbh()->selectall_arrayref('SELECT l.show_cat FROM '.$Ffc::Data::Prefix.'lastseenforum l WHERE l.userid=? AND l.category=?', undef, $userid, $catid) )->[0]->[0];
#        diag "catid=$catid, userid=$userid, return=$ret";
        is $ret, 1, 'category show switch is ok (1)';
    }

    $_->[3] = 0 for @Test::General::Categories[0 .. 4];
    $_->[3] = 1 for @Test::General::Categories[5 .. 8];
    my $ccat = $Ffc::Data::CommonCatTitle;
    #do { use Encode; encode('UTF-8', $Ffc::Data::CommonCatTitle) };

    {
        # id name short
        my $check = [ [ $ccat, '', 1 ], 
            map { [ $_->[1], $_->[2], $_->[3] ] } 
            sort { $a->[2] cmp $b->[2] } 
            @Test::General::Categories ];
        # name short count sort show
        my $cats = [ map { [ $_->[0], $_->[1], $_->[4] ] }
            sort { $a->[1] cmp $b->[1] }
            @{ Ffc::Data::Board::Views::get_all_categories($user->{name}) } ];
        is $#$cats, 9, 'category count for "get_all_categories" ok';
        is_deeply $cats, $check, 'categories array ok';
        # use Data::Dumper; diag Dumper $cats, $check;
    }
    {
        # id name short
        my $check = [ [ $ccat, '', 1 ], 
            map { [ $_->[1], $_->[2], $_->[3] ] } 
            sort { $a->[2] cmp $b->[2] } 
            @Test::General::Categories[5 .. 8] ];
        # name short count sort show
        my $cats = [ map { [ $_->[0], $_->[1], $_->[4] ] }
            sort { $a->[1] cmp $b->[1] }
            @{ Ffc::Data::Board::Views::get_categories($user->{name}) } ];
        is $#$cats, 4, 'category count for "get_categories" ok';
        is_deeply $cats, $check, 'categories array ok';
        # use Data::Dumper; diag Dumper $cats, $check;
    }

    my $user2 = Mock::Testuser->new_active_user();
    my %catcounts = ();
    for my $cat ( '', map { $_->[2] } @Test::General::Categories ) {
        $catcounts{$cat} = 3 + int rand 10;
        Ffc::Data::Board::Forms::insert_post($user2->{name}, Test::General::test_r(), $cat) for 1 .. $catcounts{$cat};
    }
    my $tocount = 3 + int rand 10;
    my $fromcount = 3 + int rand 10; # obligatorisch
    my $notecount = 3 + int rand 10;
    my $notecount2 = 3 + int rand 10; # obligatorisch
    Ffc::Data::Board::Forms::insert_post($user2->{name}, Test::General::test_r(), undef, $user->{name}) for 1 .. $tocount;
    Ffc::Data::Board::Forms::insert_post($user->{name}, Test::General::test_r(), undef, $user2->{name}) for 1 .. $fromcount;
    Ffc::Data::Board::Forms::insert_post($user->{name}, Test::General::test_r(), undef, $user->{name}) for 1 .. $notecount;
    Ffc::Data::Board::Forms::insert_post($user2->{name}, Test::General::test_r(), undef, $user2->{name}) for 1 .. $notecount2;
    
    # counts testen
    my $forumcount = do {
        my $sum = 0;
        $sum += $catcounts{$_}
            for '', map { $_->[2] }
                @Test::General::Categories[5..8];
        $sum;
    };
    {
        is Ffc::Data::Board::Views::check_for_updates($user->{name}, 'msgs'),  $tocount, 
            'sum of counts in msgs overall is ok';
        is Ffc::Data::Board::Views::check_for_updates($user->{name}, 'notes'), 0,
            'sum of counts in notes overall is ok';
        for my $cat ( ['', '', '', 1], @Test::General::Categories ) {
            is Ffc::Data::Board::Views::check_for_updates($user->{name}, 'forum', $cat->[2]),
                ( $cat->[3] ? $catcounts{$cat->[2]} : 0 ),
                qq'sum of counts in forum in cat "$cat->[2]" is ok';
        }
        is Ffc::Data::Board::Views::count_newmsgs( $user->{name} ), $tocount, 'count_newsmsgs ok';
        is Ffc::Data::Board::Views::count_notes( $user->{name} ), $notecount, 'count of notes ok';
        is Ffc::Data::Board::Views::count_newposts( $user->{name} ), $forumcount, 'count of overall forum posts ok';
    }
}
