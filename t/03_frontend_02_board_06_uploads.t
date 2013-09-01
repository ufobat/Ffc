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
use Ffc::Data::Board::Forms;
use File::Temp;
use File::Copy;
srand;

use Test::More tests => 18225;

my $t = Test::General::test_prepare_frontend('Ffc');
sub r { &Test::General::test_r }

my @users = map { 
    my $u = Mock::Testuser->new_active_user();
    $u->{id} = Ffc::Data::Auth::get_userid($u->{name});
    $u;
} 0 .. 2;

my @del;

for my $tc ( 
    # [ from => to ]
    [ 0 => undef ], [ 1 => undef ], [ 2 => undef ],

    [ 0 => 0 ], [ 1 => 1 ], [ 2 => 2 ],
    
    [ 0 => 1 ], [ 0 => 2 ],
    [ 1 => 0 ], [ 1 => 2 ],
    [ 2 => 0 ], [ 2 => 1 ],
) {
    my $from = $users[$tc->[0]];
    my $to   = $tc->[1] ? $users[$tc->[1]] : undef;
    my $is_msgs = ( defined($to) and ($to->{name} ne $from->{name}) ) ? 1 : 0;
    my $is_note = ( defined($to) and not $is_msgs ) ? 1 : 0;
    my $is_forum = defined($to) ? 0 : 1;
    my ( @visible, @hidden );
    unless ( $is_forum ) {
        push @visible, $from;
        push @visible, $to if $is_msgs;
        @hidden = grep { my $u = $_; not grep { $u->{name} eq $_->{name} } @visible } @users;
    }

    note qq(Autor "$from->{name}" von ) . (
        $is_forum
            ? 'allgemeinem Beitrag'
            : ( $is_note ? 'eigener Notiz' : qq(Privatnachricht an "$to->{name}") )
        );
    note 'Sichtbar fuer:   "' . join('", "', map {$_->{name}} @visible) . '"' unless $is_forum;
    note 'Unsichtbar fuer: "' . join('", "', map {$_->{name}} @hidden) . '"' if @hidden;

    if ( $is_forum ) {
        for my $cat ( '', map {$_->[2]} @Test::General::Categories ) {
            check_forum($from, $cat, \@users);
        }
    }
    if ( $is_msgs ) {
        check_msgs($from, $to, \@visible, \@hidden);
    }
    if ( $is_note ) {
        check_note($from, \@hidden);
    }

    logout();
}

sub test_upload_do {
    my ( $from, $postid, $text, $url, $i ) = @_;
    my ( $testfile, $teststr ) = get_testfile();
    logout();
    login($from);
    note qq(testing the upload of "$testfile");
    my $desc = r();
    $t->get_ok("$url/upload/add/$postid")->status_is(200)->content_like(qr/$text/);
    $t->post_ok(
        "$url/upload/add/$postid",
        form => {
            description => $desc,
            attachedfile => {
                filename => $testfile,
                file     => Mojo::Asset::Memory->new->add_chunk($teststr),
            }
        }
    )->status_is(302)->header_like( Location => qr{\Ahttps?://localhost:\d+$url\z}xms );

    my $path = Ffc::Data::Board::Upload::make_path( $postid, $i );
    ok( -e $path, qq'file does exist now: $path' );

    my $aurl = "$url/upload/show/$postid/$i";
    push @del, $path;
    my @upload = ( $from, $url, $postid, $i, $aurl, $desc, $testfile, $teststr, $path );
    check_upload_ok($from, \@upload);
    logout();
    $t->get_ok($aurl)->status_is(200)
      ->content_like(qr/Bitte melden Sie sich an/)
      ->content_unlike(qr/$teststr/);
    logout();
    login($from);
    return \@upload;
}

sub test_upload {
    my ( $from, $cat, $to, $url ) = @_;
    my $text = r();
    Ffc::Data::Board::Forms::insert_post( $from->{name}, $text, $cat, ( $to ? $to->{name} : undef ) );
    my $postid = Test::General::test_get_max_postid();
    $t->get_ok($url)->status_is(200)->content_like(qr/$text/);
    my @uploads;
    my $upload1 = test_upload_do( $from, $postid, $text, $url, 1 );
    my $upload2 = test_upload_do( $from, $postid, $text, $url, 2 );
    {
        my $delurl = "$url/upload/delete/$postid/1";
        $t->get_ok($delurl)
          ->status_is(200)
          ->content_like(qr/$text/)
          ->content_like(qr/$upload1->[4]/)
          ->content_like(qr/$upload1->[5]/)
          ->content_like(qr/Anhang wirklich löschen/);
        $t->post_ok($delurl) 
          ->status_is(302)
          ->header_like( Location => qr{\Ahttps?://localhost:\d+$url\z}xms );
        ok !-e $upload1->[7], 'file deleted';
        check_upload_hidden($from, $upload1);
        check_upload_ok($from, $upload2);
    }
    my $upload3 = test_upload_do( $from, $postid, $text, $url, 3 );
    push @uploads, $upload2, $upload3;
    return \@uploads;
}

sub check_upload_hidden {
    my $user = shift;
    my ( $author, $url, $postid, $anum, $aurl, $desc, $testfile, $teststr ) = @{ shift() };
    note qq(checking the hiddebility of upload of "$testfile");
    logout();
    login($user);
    $t->get_ok($url)->status_is(200)
      ->content_unlike(qr/$aurl/)
      ->content_unlike(qr/$desc/)
      ->content_unlike(qr/$testfile/);
    $t->get_ok($aurl)->status_is(200)->header_is('Content-disposition' => 'attachment;filename=nofile.png');
}
sub check_upload_ok {
    my $user = shift;
    my ( $author, $url, $postid, $anum, $aurl, $desc, $testfile, $teststr ) = @{ shift() };
    note qq(checking the upload of "$testfile");
    logout();
    login($user);
    $t->get_ok($url)->status_is(200)
      ->content_like(qr/$aurl/)
      ->content_like(qr/$desc/)
      ->content_like(qr/$testfile/);
    $t->get_ok($aurl)->status_is(200)
      ->content_like(qr/$teststr/)
      ->header_is('Content-Disposition' => "attachment;filename=$testfile");
}

sub get_testfile {
    my ( $testfh, $testfile ) = File::Temp::tempfile(SUFFIX => '.dat', CLEANUP => 1);
    my $teststr = r();
    print $testfh $teststr; 
    close $testfh;
    push @del, $testfile;
    return $testfile, $teststr;
}

sub logout { $t->get_ok('/logout')->status_is(200) }
sub login {
    my $user = shift;
    logout();
    $t->post_ok( '/login',
        form => { user => $user->{name}, pass => $user->{password} } )
      ->status_is(302)
      ->header_like( Location => qr{\Ahttps?://localhost:\d+/\z}xms );
}

sub check_upload_array_ok {
    my ( $uploads, $visible, $hidden ) = @_;
    for my $upload ( @$uploads ) {
        for my $user ( @$visible ) {
            check_upload_ok($user, $upload);
        }
        for my $user ( @$hidden ) {
            check_upload_hidden($user, $upload);
        }
    }
}

sub check_forum {
    my ( $from, $cat, $visible ) = @_;
    login($from);
    my $url = '/forum';
    $url .= "/category/$cat" if $cat;
    $t->get_ok($url)->status_is(200);
    my $uploads = test_upload($from, $cat, undef, $url);
    check_upload_array_ok($uploads, $visible, []);
}

sub check_msgs {
    my ( $from, $to, $visible, $hidden ) = @_;
    login($from);
    my $url = "/msgs/user/$to->{name}";
    $t->get_ok($url)->status_is(200);
    my $uploads = test_upload($from, undef, $to, $url);
    my $aurl = "/msgs/user/$to->{name}";
    $_->[1] = $aurl for @$uploads;
    check_upload_array_ok($uploads, $visible, $hidden);
}

sub check_note {
    my ( $from, $hidden ) = @_;
    login($from);
    my $url = "/notes";
    $t->get_ok($url)->status_is(200);
    my $uploads = test_upload($from, undef, $from, $url);
    check_upload_array_ok($uploads, [$from], $hidden);
}

END { unlink $_ for @del }

