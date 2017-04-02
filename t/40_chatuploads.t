use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use Testinit;
use Ffc::Plugin::Config;
use File::Temp qw~tempfile tempdir~;
use File::Spec::Functions qw(catfile catdir splitdir);
use Mojo::Util 'xml_escape';
use Data::Dumper;

use Test::Mojo;
use Test::More tests => 220;

#############################################################################
# Benutzer anlegen
my ( $t, $path, $aname, $apass, $dbh ) = Testinit::start_test();
# Benutzerobjekte zur Weiterverarbeitung
# ( admin = userid 1 !!! )
my ( $u2, $u3, $u4 ) = Testinit::make_userobjs($t, 3, $aname, $apass);

###############################################################################
my %id2file;
my $fileid = 0;



###############################################################################
##  test subs  ################################################################
###############################################################################



sub set_chatloglength {
    my $cnt = shift;
    Testinit::test_login($t, $aname, $apass);
    $t->post_ok('/admin/boardsettings/chatloglength', form => {optionvalue => 1000})
      ->status_is(302)->content_is(''); # we dont want to run out of messages (u know, deleting old chat messages n stuff)
}

###############################################################################
sub fileupload {
    my ( $u ) = @_;
    my $t = $u->{t};
    #Testinit::login_userobj( $u ); # allready logged in
    # Dateiupload ohne Dateien failed
    $t->post_ok("/chat/upload", form => { } )
      ->status_is(200)->content_is('failed');
    # Richtiger Upload
    $fileid++;
    my $filename = Testinit::test_randstring() . '.png';
    my $content  = Testinit::test_randstring();
    note qq~uploading file "$filename" ($fileid) with content "$content"~;
    $id2file{$fileid} = { filename => $filename, content => $content, contenttype => 'imgage/png' };
    $t->post_ok("/chat/upload/",
        form => { 
            attachement => [
                {
                    file => Mojo::Asset::Memory->new->add_chunk($content),
                    filename => $filename,
                    'Content-Type' => 'image/png',
                }
            ]
        }
    );
    $t->status_is(200)->content_is('ok');
    return $filename, $fileid;
}

###############################################################################
sub check_file_system {
    my ( $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in file system~;
    my $uplpath = catfile $path, 'chatuploads', $fileid;
    if ( $deleted ) {
        ok not -e $uplpath, 'file is not in filesystem anymore';
        return;
    }
    ok -e $uplpath, 'file exists in filesystem' or return;
    ok -s $uplpath, 'file has nonzero size'     or return;
    my $fcontent = do {
        local $/;
        open my $fh, '<', $uplpath;
        ok $fh, 'could open file for reading';
        $fh ? <$fh> : '';
    };
    ok -s $fcontent, 'file contains data' or return;
    is $fcontent, $content, qq~filecontent is as expected~;
}

###############################################################################
sub check_file_databse {
    my ( $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in database~;
    my $res = $dbh->selectall_arrayref(
        q~SELECT "msgid", "filename", "content_type" FROM "attachements_chat" WHERE "id"=?~
        , $fileid);
    if ( $deleted ) {
        ok not( @$res ), 'file is not in database';
        return;
    }
    ok scalar(@$res), 'something is in database' or return;
    is scalar(@$res), 1, 'we got exact 1 entry'  or return;
    my ( $msgid, $rfilename, $rcontenttype ) = @{ $res->[0] };
    is $rfilename,   $filename,   'filename is correct';
    is $contenttype, 'image/png', 'contenttype is correct';
    $id2file{msgid} = $msgid;
    return $msgid;
}

###############################################################################
sub check_file_msg {
    my ( $u, $fileid, $msgid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in request~;
    my $msgstr = qq~<a href="/chat/download/$fileid" target="_blank" title="$filename" alt="$filename">Dateianhang</a>~;

    # request
    $u->{t}->get_ok('/chat/receive/focused')->status_is(200);
    my @res = @{ $u->{t}->tx->res->json->[0] };
    my @msgs = grep {; $_[0] =~ qr~href="/chat/download/$fileid"~ } @res;
    if ( $deleted ) {
        ok scalar(@msgs), 'file no longer in messsages';
        return;
    }
    is scalar(@msgs), 1, 'we got exactly 1 entry' or return;

    my $msg = $msgs[0];
    
    my ( $rmsgid, $rmsgstr, $ruserid ) = @{$msg}[ 0, 2, 5 ];
    is $rmsgid, $msgid, 'message id ok';
    is $ruserid, $u->{id}, 'userfrom id ok';
    like $rmsgstr, $msgstr, 'message content ok'; 
}

###############################################################################
sub check_file_download {
    my ( $u, $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'not' : '' ) . qq~ for download~;
}



###############################################################################
##  Test run  #################################################################
###############################################################################



set_chatloglength( 1000 );
set_chatloglength( 3 );
