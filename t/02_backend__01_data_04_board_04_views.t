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
srand;

use Test::More tests => 297;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Views');

{
    my $user  = Mock::Testuser->new_active_user();
    my $user2 = Mock::Testuser->new_active_user();
    my @tests = (
        {
            name    => 'count_newmsgs',
            act     => 'msgs',
            note    => q{sub count_newmsgs( $username )},
            code    => \&Ffc::Data::Board::Views::count_newmsgs,
            insert1 => $user2->{name},
            insert2 => $user->{name},
        },
        {
            name    => 'count_newposts',
            act     => 'forum',
            note    => q{sub count_newpost( $username )},
            code    => \&Ffc::Data::Board::Views::count_newposts,
            insert1 => $user2->{name},
            insert2 => undef,
        },
        {
            name    => 'count_notes',
            act     => 'notes',
            note    => q{sub count_notes( $username )},
            code    => \&Ffc::Data::Board::Views::count_notes,
            insert1 => $user->{name},
            insert2 => $user->{name},
            count   => sub { $_[0]->{count_before} + $_[0]->{count_after} },
        }
    );
    note('preparing count tests');
    for my $t (@tests) {
        {
            my $ret;
            eval { $ret = $t->{code}->( $user->{name} ) };
            ok( !$@, qq'counting code "$t->{name}" ran good' );
            is( $ret, 0,
qq'counting code "$t->{name}" returned zero because the database is still empty'
            );
        }
    }
    for my $t (@tests) {
        my $cnt = 10 + int rand 30;
        $t->{count_before} = $cnt;
        for ( 1 .. $cnt ) {
            my $text = Test::General::test_r();
            eval {
                Ffc::Data::Board::Forms::insert_post( $t->{insert1}, $text,
                    undef, $t->{insert2} );
            };
            diag("insert test data before userstats update failed: $@") if $@;
        }
    }

    Test::General::test_update_userstats($user);

    for my $t (@tests) {
        my $cnt = 10 + int rand 30;
        $t->{count_after} = $cnt;
        for ( 1 .. $cnt ) {
            my $text = Test::General::test_r();
            eval {
                Ffc::Data::Board::Forms::insert_post( $t->{insert1}, $text,
                    undef, $t->{insert2} );
            };
            diag("insert test data after userstats update failed: $@") if $@;
        }
    }

    for my $t (@tests) {
        note( $t->{note} );
        $t->{count} =
          exists $t->{count} ? $t->{count}->($t) : $t->{count_after};
        check_call(
            $t->{code},
            $t->{name} => {
                name => 'user name',
                good => $user->{name},
                bad =>
                  [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
                errormsg => [
                    'Kein Benutzername angegeben',
                    'Benutzername ungültig',
                    'Benutzer unbekannt',
                ],
                emptyerror => 'Kein Benutzername angegeben',
            },
        );
        {
            my $ret;
            eval { $ret = $t->{code}->( $user->{name} ) };
            ok( !$@, qq'counting code "$t->{name}" ran good' );
            ok( $ret,
                qq'counting code "$t->{name}" returned something as expected' );
            is( $ret, $t->{count}, qq'counting of "$t->{name}" works' );
        }
    }
}
{
    note(q{sub get_categories( $username )});
    my $user = Mock::Testuser->new_active_user();
    Test::General::test_update_userstats($user);
    my @ret = check_call(
        \&Ffc::Data::Board::Views::get_categories,
        get_categories => {
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

    for my $i ( 0 .. 2 )
    {    # run multiple tests to test creation of category-logging
        note("category count run number '$i'");
        Test::General::test_update_userstats($user);
        my $user2 = Mock::Testuser->new_active_user();
        my %catcounter;
        for my $cat ( '', @cats ) {
            my $cnt = 10 + int rand 30;
            $catcounter{$cat} = $cnt;
            for ( 1 .. $cnt ) {
                my $text = Test::General::test_r();
                eval {
                    Ffc::Data::Board::Forms::insert_post( $user2->{name},
                        $text, $cat );
                };
                diag("insert test data before userstats update failed: $@")
                  if $@;
            }

# diag( qq(inserted "$cnt" posts from "$user2->{name}" into "$cat" to read for "$user->{name}"));
        }
        my $ret;
        {
            eval {
                $ret = Ffc::Data::Board::Views::get_categories( $user->{name} );
            };
            ok( !$@, 'categories retrieved' );
            diag($@) if $@;
        }
        ok( @$ret, 'data for categories retrieved' );
        is(
            scalar(@$ret),
            ( scalar(@cats) + 1 ),
            'data for every single category including "Allgemein" returned'
        );
        my %ret = map { $_->[1] => $_->[2] } @$ret;
        for my $cat ( '', @cats ) {

            # diag("$cat => $ret{$cat} / $catcounter{$cat}");
            is( $ret{$cat}, $catcounter{$cat},
                qq(counter for category "$cat" returned the correct value) );
        }

        if ( $i < 2 ) {
            Test::General::test_update_userstats( $user, 1 );
        }
    }
}

{
    note('testing date retrieving');
    sleep 1.1;    # works only on seconds scale
    my $user  = Mock::Testuser->new_active_user();
    my $user2 = Mock::Testuser->new_active_user();
    {
        for my $cat ( undef, map { $_->[2] } @Test::General::Categories ) {
            for ( 1 .. ( 10 + int rand 20 ) ) {
                Ffc::Data::Board::Forms::insert_post( $user->{name},
                    Test::General::test_r(), $cat, undef );
            }
        }
        Ffc::Data::Board::Forms::insert_post( $user->{name},
            Test::General::test_r(), undef, $user->{name} )
          for 1 .. ( 10 + int rand 20 );
        Ffc::Data::Board::Forms::insert_post( $user->{name},
            Test::General::test_r(), undef, $user2->{name} )
          for 1 .. ( 5 + int rand 10 );
        Ffc::Data::Board::Forms::insert_post( $user2->{name},
            Test::General::test_r(), undef, $user->{name} )
          for 1 .. ( 5 + int rand 10 );
    }

    Test::General::test_update_userstats($user);
    my $usertest = {
        name     => 'user name',
        good     => $user->{name},
        bad      => [ '', '   ', Mock::Testuser::get_noneexisting_username() ],
        errormsg => [
            'Kein Benutzername angegeben',
            'Benutzername ungültig',
            'Benutzer unbekannt',
        ],
        emptyerror => 'Kein Benutzername angegeben',
    };
    my @paramstest = (
        { name => 'page',  good => 1,  noemptycheck => 1 },
        { name => 'query', good => '', noemptycheck => 1 },
    );
    my $cattest = {
        name => 'category',
        good => Test::General::test_get_rand_category()->[2],
        bad  => [ ' ', 'a', Test::General::test_get_non_category_short() ],
        errormsg     => [ 'Kategoriekürzel ungültig', 'Kategorie ungültig' ],
        noemptycheck => 1
    };
    my $controller     = Mock::Controller->new();
    my $controllertest = {
        name         => 'controller',
        good         => $controller,
        noemptycheck => 1
    };
    {
        note(
q{sub get_post( $action, $username, $postid, $page, $search, $category, $controller )}
        );
        my $code    = \&Ffc::Data::Board::Views::get_post;
        my $name    = 'get_post';
        my $acttest = {
            name       => 'action',
            good       => 'forum',
            bad        => [ '', '   ', 'aaaaaaaaaaaaa' ],
            emptyerror => 'Aktion nicht angegeben',
            errormsg => [ 'Aktion nicht angegeben', 'Aktion unbekannt' ],
        };
        my $posttest = {
            name => 'postid',
            good => do {
                my $sql =
                    'SELECT p.id FROM '
                  . $Ffc::Data::Prefix
                  . 'posts p'
                  . (
                    $cattest->{good}
                    ? ' INNER JOIN '
                      . $Ffc::Data::Prefix
                      . 'categories c ON c.id=p.category AND c.short=?'
                    : ''
                  )
                  . ' INNER JOIN '
                  . $Ffc::Data::Prefix
                  . 'users u ON p.user_from=u.id AND u.name=?'
                  . ' WHERE p.user_to IS NULL'
                  . ( $cattest->{good} ? '' : ' AND p.category IS NULL' );
                my @ids = map { $_->[0] } @{
                    Ffc::Data::dbh()->selectall_arrayref(
                        $sql, undef,
                        $cattest->{good} // (), $usertest->{good}
                    )
                };
                die qq(nothing found for testing: $sql\n\n)
                  . Dumper(
                    {
                        cattest  => $cattest->{good},
                        acttext  => $acttest->{good},
                        usertest => $user->{name}
                    }
                  ) unless @ids;
                $ids[ int rand $#ids ];
            },
            bad      => [ '', '  ', 'aaaa' ],
            errormsg => [
                q{Keine ID für den Beitrag angegeben},
                q{Ungültige ID für den Beitrag}
            ],
            emptyerror => q{Keine ID für den Beitrag angegeben},
        };
        {
            my ($post) =
              check_call( $code, $name, $acttest, $posttest, $usertest,
                @paramstest, $cattest, $controllertest );
            is(
                $post->{raw},
                (
                    Ffc::Data::dbh()->selectrow_array(
                        'SELECT textdata FROM '
                          . $Ffc::Data::Prefix
                          . 'posts WHERE id=?',
                        undef,
                        $posttest->{good}
                    )
                  )[0],
                'returned a single post with category ok'
            );
        }
        {
            my @testmatrix = ( [ 0, 0 ], [ 1, 0 ], [ 0, 1 ], [ 1, 1 ], );
            @testmatrix = map {
                my $act = $_;
                map { [ $act => @$_ ] } @testmatrix
            } qw(forum notes msgs );
            my $userid = Ffc::Data::Auth::get_userid( $user->{name} );
            for my $t (@testmatrix) {

                #diag(Dumper $t );
                my ( $act, $has_where, $has_cat ) = @$t;
                my $category = [ '', '', '' ];
                my $query = '';
                my @where;
                my @params;

                if ( $act eq 'notes' or $act eq 'msgs' ) {
                    push @where,  'user_from=?';
                    push @params, $userid;
                }

                if ( $act eq 'msgs' ) {
                    $where[-1] .= ' OR user_to=?';
                    $where[-1] = "( $where[-1] )";
                    push @params, $userid;
                }

                if ( $act eq 'notes' ) {
                    push @where,  'user_to=?';
                    push @params, $userid;
                }

                $has_cat = 0 unless $act eq 'forum';
                if ($has_cat) {
                    push @where, 'category=?';
                    $category = Test::General::test_get_rand_category();
                    push @params, $category->[0];
                }
                else {
                    push @where, 'category IS NULL';
                }

                push @where,  'user_from=?';
                push @params, $userid;

                #diag(Dumper { where => \@where, params => \@params } );
                my $sql =
'SELECT id, textdata, user_from, user_to, category, posted FROM '
                  . $Ffc::Data::Prefix . 'posts';
                if (@where) {
                    $sql .= ' WHERE ' . join ' AND ', @where;
                }
                my $posts = [];
                {
                    eval {
                        $posts = Ffc::Data::dbh()
                          ->selectall_arrayref( $sql, undef, @params );
                    };
                    die qq~no post for test available~
                      . Dumper {
                        t        => $t,
                        category => $category,
                        query    => $query,
                        user     => $user,
                        where    => \@where,
                        params   => \@params,
                        sql      => $sql,
                        dollarat => $@
                      }
                      unless @$posts;
                }
                my $post = $posts->[ int rand @$posts ];
                if ($has_where) {
                    $query = substr( $post->[1], 0, length $post->[1] );
                }

#q{sub get_post( $action, $username, $postid, $page, $search, $category, $controller )}
                my $post_test;
                eval {
                    $post_test = $code->(
                        $act, $post->[0], $user->{name}, 1, $query,
                        $category->[2] || undef, $controller
                    );
                };
                if ( $act eq 'msgs' ) {
                    ok( $@,                  'errors thrown' );
                    ok( !defined($post_test), 'no test post fetched' );
                    like( $@, qr/Privatnachricht/, 'error ok');
                }
                else {
                    ok( !$@,                 'post fetched' );
                    ok( defined($post_test), 'test post ok' );
                    diag(
                        qq~ERROR IN: checking "get_post()" in act "$act" with~
                          . ( $has_cat ? '' : 'out' )
                          . q~ category and with~
                          . ( $has_where ? '' : 'out' )
                          . ' where, data is: '
                          . Dumper {
                            t        => $t,
                            category => $category,
                            query    => $query,
                            user     => $user->{name},
                            userid   => $userid,
                            where    => \@where,
                            params   => \@params,
                            sql      => $sql,
                            dollarat => $@,
                            post     => $post,
                          }
                    ) if $@;
                    is( $post_test->{raw}, $post->[1], 'correct post fetched' );
                }
            }
        }
    }

    sub get_testcases {
        my ( $code, $name, $secondparam, $wherestr, @params ) = @_;

        #Ffc::Data::dbh()->do('DELETE FROM '.$Ffc::Data::Prefix.'posts');
        note(
qq{sub $name( \$username, \$page, \$search, \$category, \$controller )}
        );
        my $controller  = Mock::Controller->new();
        my $has_cats    = 0;
        my $privmsgs    = 0;
        my $asnotes     = 0;
        my $cattest     = { good => '', noemptycheck => 1, name => 'category' };
        my $insert_code = sub {
            my $notyou   = shift;
            my $userfrom = $user->{name};
            if ($notyou) {
                note('generating messages from a different user');
                $userfrom = Mock::Testuser->new_active_user()->{name};
            }
            if ($secondparam) {
                if ( $secondparam eq $userfrom ) {
                    Ffc::Data::Board::Forms::insert_post( $user->{name},
                        Test::General::test_r(), undef, $secondparam )
                      for 0 .. ( ( 3 * $Ffc::Data::Limit ) + int rand 20 );
                    $asnotes = 1;
                }
                else {
                    $privmsgs = 1;
                    for ( 0 .. ( ( 3 * $Ffc::Data::Limit ) + int rand 20 ) ) {
                        if ( $notyou or int rand 2 ) {
                            Ffc::Data::Board::Forms::insert_post( $secondparam,
                                Test::General::test_r(), undef, $user->{name} );
                        }
                        else {
                            Ffc::Data::Board::Forms::insert_post( $user->{name},
                                Test::General::test_r(), undef, $secondparam );
                        }
                    }

                }
            }
            else {
                $has_cats = 1;
                for my $cat ( map( { $_->[2] } @Test::General::Categories ),
                    undef )
                {
                    Ffc::Data::Board::Forms::insert_post( $userfrom,
                        Test::General::test_r(), $cat, undef )

            #, note('adding forum post with category "'.($cat // '<undef>').'"')
                      for 0 .. ( ( 3 * $Ffc::Data::Limit ) + int rand 20 );
                }
            }
        };
        $insert_code->();

        my @ret = check_call( $code, $name, $usertest, @paramstest, $cattest,
            $controllertest );
        ok( @ret, 'something was returned' );
        my $allposts = [];
        {
            note('fetching test data');
            my $sql =
                'SELECT id, textdata, user_from, user_to, category FROM '
              . $Ffc::Data::Prefix
              . "posts WHERE $wherestr ORDER BY id DESC";
            eval {
                $allposts =
                  Ffc::Data::dbh()->selectall_arrayref( $sql, undef, @params );
            };
            ok( !$@, 'database query for getting postings for controlling' );
            diag("$sql: $@") if $@;
            ok( @$allposts, 'got something for controlling' );
        }
        my @privmsgs;
        if ($privmsgs) {
            my $secondparam = Ffc::Data::Auth::get_userid($secondparam);
            @privmsgs =
              grep { $secondparam == $_->[2] or $secondparam == $_->[3] }
              @$allposts;
        }
        my $testpost = $allposts->[ int rand scalar @$allposts ];
        my $pages    = int @$allposts / $Ffc::Data::Limit;
        $pages++ if $pages < @$allposts / $Ffc::Data::Limit;
        for my $i ( 1 .. 3 ) {
            my $starti = ( $i - 1 ) * $Ffc::Data::Limit;
            my $stoppi = $starti + $Ffc::Data::Limit - 1;
            my @tposts = @$allposts[ $starti .. $stoppi ];
            my $ret    = [];
            {
                eval {
                    $ret = $code->( $user->{name}, $i, '', '', $controller );
                };
                ok( !$@, qq'code for "$name" on page "$i" ran ok' );
                diag($@) if $@;
            }
            ok( @$ret, qq'code returned somethin' );
            is( $#$ret, $#tposts, 'return count ok' );
            my @errors;
            my @fields =
              qw(text start raw active newpost timestamp ownpost category from to editable id iconspresent);
            for my $i ( 0 .. $#ret ) {
                for (@fields) {
                    unless ( exists $ret->[$i]->{$_} ) {
                        push @errors, qq'field "$_" not available';
                        diag("field '$_' not found in return hash");
                    }
                }
                push @errors, 'raw data not available'
                  unless exists( $ret->[$i]->{raw} )
                  and $ret->[$i]->{raw};
                push @errors, 'checkpost unavailabe'
                  unless exists( $tposts[$i] )
                  and $tposts[$i];
                push @errors, 'raw data does not match checkpost textdata'
                  unless $ret->[$i]->{raw} eq $tposts[$i]->[1];

            }
            ok( !@errors, 'testdata retrieved ok' );
            if (@errors) {
                diag( Dumper \@errors );
                diag(
                    Dumper {
                        cats     => $has_cats,
                        privmsgs => $privmsgs,
                        asnotes  => $asnotes,
                        testpost => [ map { $_->[1] } @tposts ],
                        ret      => [ map { $_->{raw} } @$ret ],
                        all      => [ map { $_->[1] } @$allposts ],
                    }
                );
                die;
            }
        }
        {
            my $ret   = [];
            my $catid = undef;
            $catid = Ffc::Data::General::get_category_short( $testpost->[4] )
              if $testpost->[4];
            {
                eval {
                    $ret = $code->(
                        $user->{name}, 0, $testpost->[1],
                        $catid,        $controller
                    );
                };
                ok( !$@, qq'code for "$name" for query ran ok' );
                diag($@) if $@;
            }
            ok( @$ret, qq'code returned somethin' );
            unless (@$ret) {
                diag(
                    Dumper {
                        fromall =>
                          [ grep { $_->[1] eq $testpost->[1] } @$allposts ],
                        user     => $user->{name},
                        page     => 1,
                        query    => $testpost->[1],
                        category => undef,
                        ret      => $ret,
                        sub      => $name,
                        cats     => $has_cats,
                        privmsgs => $privmsgs,
                        asnotes  => $asnotes,
                    }
                );
            }
            is( @$ret, 1, 'return count ok' );
            is( $ret->[0]->{raw},
                $testpost->[1], 'return value is looking good' );
        }
        if ($privmsgs) {
            my $ret = [];
            {
                eval {
                    $ret = $code->(
                        $user->{name}, 1, $testpost->[1], '', $controller,
                        $secondparam
                    );
                };
                ok( !$@,
                    qq'code for "$name" for specific conversation ran ok' );
                diag($@) if $@;
            }
            ok( @$ret, qq'code returned somethin' );
            is( @$ret, 1, 'return count ok' );
            my $errors = 0;
            for my $r (@$ret) {
                $errors++ unless grep { $r->{raw} eq $_->[1] } @privmsgs;
            }
            is( $errors, 0,
                'all messages are private messages to the single contact' );
        }

        {
            note('"newpost"-flag messages testen');
            Test::General::test_update_userstats( $user, $has_cats );
            for my $cat (
                '',
                (
                    $has_cats
                    ? map( { $_->[2] } @Test::General::Categories )
                    : ()
                )
              )
            {
                my $ret = [];
                {
                    eval {
                        $ret = $code->(
                            $user->{name}, 1, '', $cat, $controller,
                            $secondparam
                        );
                    };
                    ok( !$@, qq'code for "$name" for new messages ran ok' );
                    diag($@) if $@;
                }
                ok( @$ret, qq'code returned somethin' );
                ok( !$ret->[0]->{newpost},
                    qq(no new messages are available for "$name") );
                diag( Dumper $ret ) if $ret->[0]->{newpost};
            }
            Test::General::test_update_userstats( $user, $has_cats );
            $insert_code->(1);
            for my $cat (
                '',
                (
                    $has_cats
                    ? map( { $_->[2] } @Test::General::Categories )
                    : ()
                )
              )
            {
                my $ret = [];
                {
                    eval {
                        $ret = $code->(
                            $user->{name}, 1, '', $cat, $controller,
                            $secondparam
                        );
                    };
                    ok( !$@, qq'code for "$name" for new messages ran ok' );
                    diag($@) if $@;
                }
                ok( @$ret, qq'code returned somethin' );
                if ($asnotes) {
                    ok( !$ret->[0]->{newpost},
                        q(new notes are not marked specially) );
                }
                else {
                    ok( $ret->[0]->{newpost},
                        q(new messages are marked as such) );
                }
            }
        }
    }

    note('let us test the "get_" functions very deeply');

    {
        my $code        = \&Ffc::Data::Board::Views::get_notes;
        my $name        = 'get_notes';
        my $secondparam = $user->{name};
        my $where       = 'user_from=? and user_from=user_to';
        my @params      = Ffc::Data::Auth::get_userid( $user->{name} );
        get_testcases( $code, $name, $secondparam, $where, @params );
    }
    {
        my $code        = \&Ffc::Data::Board::Views::get_msgs;
        my $name        = 'get_msgs';
        my $secondparam = $user2->{name};
        my $where       = '( user_from=? OR user_to=? ) AND user_from<>user_to';
        my @params      = ( Ffc::Data::Auth::get_userid( $user->{name} ) ) x 2;
        get_testcases( $code, $name, $secondparam, $where, @params );
    }
    {
        my $code        = \&Ffc::Data::Board::Views::get_forum;
        my $name        = 'get_forum';
        my $secondparam = undef;
        my $where       = 'user_to IS NULL';
        my @params      = ();
        get_testcases( $code, $name, $secondparam, $where, @params );
    }
}

