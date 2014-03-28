use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir);

use Test::Mojo;
use Test::More tests => 93;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = qw(test1 test1234 test2 test4321);

sub login { Testinit::test_login( $t, @_ ) }
sub error { Testinit::test_error( $t, @_ ) }
sub info  { Testinit::test_info(  $t, @_ ) }

Testinit::test_add_users($t, $admin, $apass, $user1, $pass1, $user2, $pass2);
my $tempdir = tempdir( CLEANUP => 1 );

login($user1, $pass1);

sub dir_list {
    my $dir = catdir $path, 'avatars';
    opendir my $dh, $dir or die qq~Could not open directory "$dir": $!~;
    my @dirlist;
    while ( my $dir = readdir $dh ) {
        next if $dir eq '.' or $dir eq '..';
        push @dirlist, $dir;
    }
    return @dirlist;
}
sub file_ok {
    my ( $filename, $content, $user ) = @_;
    my $file = catfile @$path, 'avatars', "${user}_$filename";
    return 'nofile', $file unless -e $file;
    return 'emptyfile', $file if -z $file;
    my $fcontent = do {
        local $/;
        open my $fh, '<', $file
            or die qq~Could not open file "$filename": $!~;
        <$fh>;
    };
    return 'wrongcontent' if $content ne $fcontent;
    return;
}
sub file_db_ok {
    my ( $filename, $content, $user ) = @_;
    my $r = $dbh->selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $user);
    return 'nouser' unless $r and 'ARRAY' eq ref $r;
    return 'nofileindb' unless $r->[0]->[0];
    return 'wrongfileindb' if $r->[0]->[0] ne $filename;
    return;
}

{
    note 'test without file attachement';
    $t->post_ok('/avatar/upload')
      ->status_is(200);
    error('Kein Avatarbild angegeben.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in store';
}

{
    note 'test without file as parameter';
    $t->post_ok('/avatar/upload', form => { avatarfile => 'test' })
      ->status_is(200);
    error('Keine Datei als Avatarbild angegeben.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with empty file';
    my ( $fn, $fh ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 999),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist zu klein, sollte mindestens 1Kb groß sein.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with file to big';
    my ( $fn, $fh ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x (150 * 1000 + 1)),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist zu groß, darf maximal 150Kb groß sein.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename not provided';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname fehlt.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with empty filename';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => '',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname fehlt.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename to short';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => 'aa.png',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname ist zu kurz, muss mindestens 6 Zeichen inklusive Dateiendung enthalten.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename to long';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => ('a' x 80).'.png',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname ist zu lang, darf maximal 80 Zeichen lang sein.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename starting with dot';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => '.aaaaaaa.png',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf nicht mit einem &quot;.&quot; beginnen.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'file is no image';
    my ( $fn, $fh ) = tempfile( DIR => $tempdir, SUFFIX => '.ogg' );
    close $fh;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist keine Bilddatei, muss PNG, JPG, BMP oder GIF sein.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'filename shall not contain ".."';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => 'aa..aaaa.png',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf weder &quot;..&quot; noch &quot;/&quot; enthalten.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'filename shall not contain "/"';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => 'aa/aaaa.png',
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf weder &quot;..&quot; noch &quot;/&quot; enthalten.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'file is no image';
    my ( $fn, $fh ) = tempfile( DIR => $tempdir, SUFFIX => '.ogg' );
    close $fh;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist keine Bilddatei, muss PNG, JPG, BMP oder GIF sein.');
    is file_db_ok('', '', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

