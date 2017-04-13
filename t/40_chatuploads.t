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
use Test::More tests => 796;

#############################################################################
# Benutzer anlegen
my ( $t, $path, $aname, $apass, $dbh ) = Testinit::start_test();
# Benutzerobjekte zur Weiterverarbeitung
# ( admin = userid 1 !!! )
my ( $u2, $u3 ) = Testinit::make_userobjs($t, 2, $aname, $apass);
Testinit::test_login( $t, $aname, $apass );

###############################################################################
my %id2file;
my @msgids = (['-', '-']);
my $fileid = 0;
my $msgid = 0;



###############################################################################
##  test subs  ################################################################
###############################################################################



###############################################################################
sub init_started {
    my $new = shift;
    for my $u ( $u2, $u3 ) {
        Testinit::login_userobj($u);
        $u->{t}->get_ok('/chat/receive/started')->status_is(200);
        if ( $new ) {
            $msgid++;
            push @msgids, [$msgid, 0];
        }
    }
}

###############################################################################
sub set_chatloglength {
    my $cnt = shift;
    note "setting chatlog length to $cnt";
    $t->post_ok('/admin/boardsettings/chatloglength', form => {optionvalue => $cnt})
      ->status_is(302)->content_is(''); # we dont want to run out of messages (u know, deleting old chat messages n stuff)
}

###############################################################################
sub idstring {
    return "----------\n" . join( '', map {;
        qq~msgid=$_->[0], ~ 
        . ( $_->[1] ? qq~fileid=$_->[1]~ : qq~no file~ )
        . "\n"
    } @msgids),
    '----------';
}

###############################################################################
sub fileupload {
    my ( $u ) = @_;
    my $t = $u->{t};
    note qq~-------- uploading file by user "$u->{username}" ($u->{userid})~;
    # Dateiupload ohne Dateien failed
    $t->post_ok("/chat/upload", form => { } )
      ->status_is(200)->content_is('failed');
    # Richtiger Upload
    $fileid++;
    my $filename = Testinit::test_randstring() . '.png';
    my $content  = Testinit::test_randstring();
    note qq~uploading file "$filename" ($fileid) with content "$content"~;
    $id2file{$fileid} = { filename => $filename, content => $content, contenttype => 'image/png' };
    $t->post_ok("/chat/upload/",
        form => { 
            attachement => [
                {
                    file => Mojo::Asset::Memory->new->add_chunk($content),
                    filename => $filename,
                    'Content-Type' => 'text/ong',
                }
            ]
        }
    );
    $t->status_is(200)->content_is('ok');
    $msgid++;
    $id2file{$fileid}{calmsgid} = $msgid;
    push @msgids, [$msgid, $fileid];
    return $filename, $fileid;
}

###############################################################################
sub check_file_system {
    my ( $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in file system~;
    my $uplpath = catfile $path, 'chatuploads', $fileid;
    if ( $deleted ) {
        ok !-e $uplpath, 'file is not in filesystem anymore';
        return;
    }
    ok -e $uplpath, 'file exists in filesystem' or return;
    ok -s $uplpath, 'file has nonzero size'     or return;
    my $fcontent = do {
        local $/;
        open my $fh, '<', $uplpath;
        ok $fh, 'could open file for reading' or return;
        <$fh>;
    };
    is $fcontent, $content, qq~filecontent is as expected~;
}

###############################################################################
sub check_file_database {
    my ( $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in database~;
    my $res = $dbh->selectall_arrayref(
        q~SELECT "msgid", "filename", "content_type" FROM "attachements_chat" WHERE "id"=?~
        , {}, $fileid);
    if ( $deleted ) {
        ok not( @$res ), 'file is not in database';
        return;
    }
    ok scalar(@$res), 'something is in database' or return;
    is scalar(@$res), 1, 'we got exact 1 entry'  or return;
    my ( $msgid, $rfilename, $rcontenttype ) = @{ $res->[0] };
    is $rfilename,   $filename,   'filename is correct';
    is $contenttype, 'image/png', 'contenttype is correct';
    is $msgid, $id2file{$fileid}{calmsgid}, 'database msg id is correct';
    $id2file{$fileid}{gotmsgid} = $msgid;
    return $msgid;
}

###############################################################################
sub check_file_msg {
    my ( $u, $uf, $fileid, $deleted ) = @_;
    my ( $filename, $content, $contenttype, $msgid ) = @{$id2file{$fileid}}{qw~filename content contenttype calmsgid~};
    note qq~checking file "$filename" ($fileid) ~ . ( $deleted ? 'deleted' : 'existing' ) . qq~ in messages request ($msgid)~;
    my $url = "/chat/download/$fileid";
    my $msgstr = qq~<a href="$url" target="_blank" title="$filename" alt="$filename">$filename</a>~;

    # request
    $u->{t}->get_ok('/chat/receive/started')->status_is(200);
    my @res = @{ $u->{t}->tx->res->json->[0] };

    my @msgs = grep {; $_->[2] =~ qr~href="/chat/download/$fileid"~ } @res;
    if ( $deleted ) {
        my $cnt = @msgs;
        is $cnt, 0, 'file no longer in messsages';
        return;
    }
    is scalar(@msgs), 1, 'we got exactly 1 entry' or return;

    my $msg = $msgs[0];
    
    my ( $rmsgid, $rmsgstr, $ruserid ) = @{$msg}[ 0, 2, 5 ];
    is $rmsgid, $msgid, 'message id ok';
    is $ruserid, $uf->{userid}, 'userfrom id ok';
    like $rmsgstr, qr~$msgstr~, 'message content ok'; 
}

###############################################################################
sub check_file_download {
    my ( $u, $fileid, $deleted ) = @_;
    my $t = $u->{t};
    my ( $filename, $content, $contenttype ) = @{$id2file{$fileid}}{qw~filename content contenttype~};
    note qq~checking file "$filename" ($fileid)~ . ( $deleted ? ' not' : '' ) . qq~ for download~;
    $t->get_ok( "/chat/download/$fileid" );
    if ( $deleted ) {
        $t->status_is(404)->content_unlike(qr~$content~);
        return;
    }
    $t->status_is(200)
      ->header_like( 'Content-Disposition', qr~(?:inline|attachment);\s*filename="?$filename"?~xmsi)
      ->header_like( 'Content-Type', qr~$contenttype~ )
      ->content_like(qr~$content~);
}



###############################################################################
##  Test parts  ###############################################################
###############################################################################



#                          set_chatloglength(   $cnt );
# ( $filename, $fileid ) = fileupload(          $u );
# ( $msgid )             = check_file_databse(  $fileid, $deleted );
#                          check_file_system(   $fileid, $deleted );
#                          check_file_msg(      $u, $fileid, $deleted );
#                          check_file_download( $u, $uf, $fileid, $deleted );

###############################################################################
# default checking
sub check_online {
    my ( $uf, $fileid, $deleted ) = @_;
    check_file_database( $fileid, $deleted );
    check_file_system(   $fileid, $deleted );
    check_file_msg(      $u2, $uf, $fileid, $deleted );
    check_file_download( $u2, $fileid, $deleted );
    check_file_msg(      $u3, $uf, $fileid, $deleted );
    check_file_download( $u3, $fileid, $deleted );
}
###############################################################################
# complete check run
sub check_complete {
    my ( $uf, $deleted ) = @_;
    my ( $filename, $fileid ) = fileupload($uf);
    check_online( $uf, $fileid, $deleted );
};

###############################################################################
# normal up- and download
sub normaltest {
    set_chatloglength( 1000 );
    init_started(1);
    check_complete($u2); # 1
    check_complete($u2); # 2
    check_complete($u3); # 3
    check_complete($u3); # 4
    check_online($u2, $_) for 1,2;
    check_online($u3, $_) for 3,4;
}

###############################################################################
# reduced chat log length
sub reducedlogtest {
    set_chatloglength( 1000 );
    check_complete($u2); # 5
    check_complete($u2); # 6 - in
    check_complete($u3); # 7 - in
    check_complete($u3); # 8 - in
    set_chatloglength( 5 );
    init_started();
    my $minfid = 4;
    my $check = sub {
        my ( $uf, $fid ) = @_;
        check_online($uf, $fid, $fid < $minfid ? 1 : 0);
    };
    $check->($u2, $_) for 1, 2, 5, 6;
    $check->($u3, $_) for 3, 4, 7, 8;
}

###############################################################################
# show uploadet images inline
sub inlinimgtest {
    $t->post_ok('/admin/boardsettings/inlineimage', 
        form => {optionvalue => 1}
    )->status_is(302);
    init_started();
    check_complete($u2);
}

###############################################################################
##  Test run  #################################################################
###############################################################################

normaltest();
reducedlogtest();
inlinimgtest();
#note idstring();
#diag Dumper \%id2file;


