use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 247;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user1, $pass1, $user2, $pass2 ) = qw(test1 test1234 test2 test4321);
sub login  { Testinit::test_login(  $t, @_ ) }
sub logout { Testinit::test_logout( $t, @_ ) }
sub error  { Testinit::test_error(  $t, @_ ) }
sub info   { Testinit::test_info(   $t, @_ ) }

Testinit::test_add_users($t, $admin, $apass, $user1, $pass1, $user2, $pass2);
my $userid1 = Testinit::test_get_userid($dbh, $user1);
my $userid2 = Testinit::test_get_userid($dbh, $user2);

my $tempdir = tempdir( CLEANUP => 1 );
my @files;
my %failfile = do {
    open my $fh, '<', "$FindBin::Bin/../public/theme/img/avatar.png"
        or die qq~Could not open fail file: $!~;
    local $/;
    my $content = <$fh>;
    close $fh;
    (filename => 'avatar.png', content => $content, contentlength => length($content));
};

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
    my $file = catfile $path, 'avatars', "${user}_$filename";
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
    my ( $filename, $user ) = @_;
    my $r = $dbh->selectall_arrayref(
        'SELECT avatar FROM users WHERE UPPER(name)=UPPER(?)'
        , undef, $user);
    return 'nouser' unless $r and 'ARRAY' eq ref $r;
    return 'nofileindb' unless $r->[0]->[0];
    return 'wrongfileindb' if $r->[0]->[0] ne "${user}_$filename";
    return;
}

{
    note 'test without file attachement';
    $t->post_ok('/avatar/upload')
      ->status_is(200);
    error('Kein Avatarbild angegeben.');
    is file_db_ok('', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in store';
}

{
    note 'test without file as parameter';
    $t->post_ok('/avatar/upload', form => { avatarfile => 'test' })
      ->status_is(200);
    error('Keine Datei als Avatarbild angegeben.');
    is file_db_ok('test', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with empty file';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 99),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist zu klein, sollte mindestens 100B groß sein.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with file to big';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x (150 * 1000 + 1)),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist zu groß, darf maximal 150Kb groß sein.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
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
    is file_db_ok('', $user1), 'nofileindb', 'no file in database';
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
    error('Dateiname ist zu kurz, muss mindestens 6 Zeichen inklusive Dateiendung enthalten.');
    is file_db_ok('', $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename to short';
    my $fn = 'aa.png';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname ist zu kurz, muss mindestens 6 Zeichen inklusive Dateiendung enthalten.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename to long';
    my $fn = ( 'a' x 80 ) . '.png';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname ist zu lang, darf maximal 80 Zeichen lang sein.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'test with filename starting with dot';
    my $fn = '.aaaaaaa.png';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf nicht mit einem &quot;.&quot; beginnen.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'file is no image';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.ogg' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Datei ist keine Bilddatei, muss PNG, JPG, BMP oder GIF sein.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'filename shall not contain ".."';
    my $fn = 'aa..aaaa.png';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf weder &quot;..&quot; noch &quot;/&quot; enthalten.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

{
    note 'filename shall not contain "/"';
    my $fn = 'aa/aaaa.png';
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk('a' x 10000),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    error('Dateiname darf weder &quot;..&quot; noch &quot;/&quot; enthalten.');
    is file_db_ok($fn, $user1), 'nofileindb', 'no file in database';
    my @dirlist = dir_list();
    ok !@dirlist, 'no files in storage directory';
}

sub check_file_online {
    my $user2ok = shift;
    note 'check if file is online available';
    $t->get_ok("/avatar/$userid1")
      ->status_is(200)
      ->content_is($files[0]{content})
      ->header_is('content-type' => qq~image/png~)
      ->header_is('content-disposition' => qq~inline;filename="$files[0]{avatarfile}"~)
      ->header_is('content-length' => $files[0]{contentlength});
    login($user2, $pass2);
    $t->get_ok("/avatar/$userid1")
      ->status_is(200)
      ->content_is($files[0]{content})
      ->header_is('content-type' => qq~image/png~)
      ->header_is('content-disposition' => qq~inline;filename="$files[0]{avatarfile}"~)
      ->header_is('content-length' => $files[0]{contentlength});
    if ( $user2ok ) {
        $t->get_ok("/avatar/$userid2")
          ->status_is(200)
          ->content_is($files[1]{content})
          ->header_is('content-type' => qq~image/png~)
          ->header_is('content-disposition' => qq~inline;filename="$files[1]{avatarfile}"~)
          ->header_is('content-length' => $files[1]{contentlength});
        login($user1, $pass1);
        $t->get_ok("/avatar/$userid2")
          ->status_is(200)
          ->content_is($files[1]{content})
          ->header_is('content-type' => qq~image/png~)
          ->header_is('content-disposition' => qq~inline;filename="$files[1]{avatarfile}"~)
          ->header_is('content-length' => $files[1]{contentlength});
    }
    else {
        $t->get_ok("/avatar/$userid2")
          ->status_is(200)
          ->content_is($failfile{content})
          ->header_is('content-length' => $failfile{contentlength})
          ->header_is('content-type' => qq~image/png~);
        login($user1, $pass1);
        $t->get_ok("/avatar/$userid2")
          ->status_is(200)
          ->content_is($failfile{content})
          ->header_is('content-length' => $failfile{contentlength})
          ->header_is('content-type' => qq~image/png~);
    }
}

{
    note 'file upload ok';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    my $content = 'a' x 10000;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk($content),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    info('Avatarbild aktualisiert.');
    ok !file_ok($fn, $content, $user1), 'file in file system ok';
    ok !file_db_ok($fn, $user1), 'file in database';
    my @dirlist = dir_list();
    is @dirlist, 1, 'one file in storage directory';
    push @files, { filename => $fn, user => $user1, avatarfile => "${user1}_$fn", content => $content, contentlength => length($content) };
    check_file_online();
}

{
    note 'file overwrite upload ok';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    my $content = 'b' x 10000;
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk($content),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    info('Avatarbild aktualisiert.');
    ok !file_ok($fn, $content, $user1), 'file in file system ok';
    ok !file_db_ok($fn, $user1), 'file in database';
    my @dirlist = dir_list();
    is @dirlist, 1, 'one file in storage directory';
    $files[0] = { filename => $fn, user => $user1, avatarfile => "${user1}_$fn", content => $content, contentlength => length($content) };
    check_file_online();
}

{
    note 'second user file upload ok';
    my ( $fh, $fn ) = tempfile( DIR => $tempdir, SUFFIX => '.png' );
    close $fh;
    $fn = (splitdir $fn )[-1];
    my $content = 'c' x 10000;
    login($user2, $pass2);
    $t->post_ok('/avatar/upload', form => {
            avatarfile => {
                file => Mojo::Asset::Memory->new->add_chunk($content),
                filename => $fn,
                content_type => 'image/png',
            }
        }
    )->status_is(200);
    info('Avatarbild aktualisiert.');
    ok !file_ok($fn, $content, $user2), 'file in file system ok';
    ok !file_db_ok($fn, $user2), 'file in database';
    my @dirlist = dir_list();
    is @dirlist, 2, 'two file in storage directory';
    push @files, { filename => $fn, user => $user2, avatarfile => "${user2}_$fn", content => $content, contentlength => length($content) };
    check_file_online(1);
}

{
    note 'test, that no avatars without login';
    logout();
    $t->get_ok("/avatar/$userid1")
      ->status_is(200)
      ->content_like(qr/Angemeldet\s+als\s+"\&lt;noone\&gt;"/xms)
      ->content_unlike(qr~$files[0]{content}~xms)
      ->content_unlike(qr~$files[1]{content}~xms);
    $t->get_ok("/avatar/$userid2")
      ->status_is(200)
      ->content_like(qr/Angemeldet\s+als\s+"\&lt;noone\&gt;"/xms)
      ->content_unlike(qr~$files[0]{content}~xms)
      ->content_unlike(qr~$files[1]{content}~xms);
}
