use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);

use Test::Mojo;
use Test::More tests => 329;

my ( $t, $path, $admin, $apass, $dbh ) = Testinit::start_test();
my ( $user, $pass ) = qw(test1 test1234);
Testinit::test_add_users($t, $admin, $apass, $user, $pass);

sub r { scalar Testinit::test_randstring() x 12 };
sub logina { Testinit::test_login(  $t, $admin, $apass ) }
sub loginu { Testinit::test_login(  $t, $user,  $pass  ) }
sub logout { Testinit::test_logout( $t, @_ ) }
sub error  { Testinit::test_error(  $t, @_ ) }
sub info   { Testinit::test_info(   $t, @_ ) }

my $faviconfile = catfile splitdir($path), 'favicon';
my $deffaviconcontent = get_favicon_content();

sub get_favicon_content {
    local $/;
    open my $fh, '<', $faviconfile
        or die "Could not open '$faviconfile': $!";
    return <$fh>;
}

sub favicon_ok {
    my ( $content, $ftype, $ctype ) = @_;
    $content = $deffaviconcontent unless defined $content;
    $ftype = 'png' unless defined $ftype;
    my $contenttype = $ctype || "image/$ftype";
    ok get_favicon_content() eq $content, 'content on filesystem as expected';

    $t->get_ok('/favicon/show')->status_is(200)
      ->header_is('Content-Type' => $contenttype)
      ->header_is('Content-Disposition' => "inline;filename=favicon.$ftype")
      ->content_is($content);

    ok $ftype eq $dbh->selectall_arrayref(
        'SELECT "value" FROM "config" WHERE "key"=?', undef, 'favicontype'
        )->[0]->[0], 'filetype ok in database';
}

sub favicon_upload {
    my ( $content, $filename, $ftype, $ctype ) = @_;
    $filename = 'favicon.png' unless defined $filename;
    $ftype = ($filename =~ m/\.(\w+)\z/xmso ? '' : '') unless defined $ftype;
    $ctype = "image/$ftype" unless $ctype;
    $t->post_ok('/options/admin/favicon', form => {
            faviconfile => {
                file => Mojo::Asset::Memory->new->add_chunk($content),
                filename => $filename,
                content_type => $ctype,
            }
        }
    )->status_is(302)->content_is('')->header_is(Location => '/options/form');
    $t->get_ok('/options/form')->status_is(200);
}

note 'kein admin, kein favicon-upload';
favicon_ok();
loginu();
favicon_upload('','');
error('Nur Administratoren dürfen das');
favicon_ok();

note 'favicon-datei zu klein';
logina();
favicon_ok();
favicon_upload('','');
error('Datei ist zu klein, sollte mindestens 100B groß sein.');
favicon_ok();
loginu();
favicon_ok();

note 'favicondatei zu groß';
logina();
favicon_upload(('a' x (150 * 1000 + 1)),'');
error('Datei ist zu groß, darf maximal 50000B groß sein.');
favicon_ok();
loginu();
favicon_ok();

note 'dateiname vergessen';
logina();
favicon_upload(('a' x (20 * 1000 + 1)),'');
error('Dateiname fehlt.');
favicon_ok();
loginu();
favicon_ok();

note 'einige funktionierende dateien testweise hochladen';
for my $f ( 
    [r(), 'test1.png','png', 'image/png'], 
    [r(), 'test2.png','png', 'image/png'], 
    [r(), 'test3.ico','ico', 'image/x-icon'], 
    [r(), 'test4.png','png', 'image/png'], 
) {
    logina();
    favicon_upload(@$f[0,1,2,3]);
    info('Favoriten-Icon aktualisiert.');
    favicon_ok(@$f[0,2,3]);
    loginu();
    favicon_ok(@$f[0,2,3]);
}
