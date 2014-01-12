#!/usr/bin/env perl
use 5.010;
use strict; use warnings; 
use utf8;
use FindBin;
use File::Spec;

my $wwwgroup = 'www';

my @publicexec = qw(
    script/ffc
);

my @closedexec = qw(
    script/inituser.pl
    script/paths.pl
);

my @closed = qw(
    data/avatars/avatar_pics_placed_here
    data/uploads/uploads_placed_here
    public/custom/custom_static_content_placed_here
    etc/ffc.json.example
    doc
    doc/db-schemas
    doc/INSTALL.txt
    doc/REQUIREMENTS.txt
    doc/Screenshot.png
    doc/db-schemas/database_mysql.sql
    doc/db-schemas/database_sqlite.sql
    .git
    README.pod
    t
    t/01_aux______01_errorhandling.t
    t/02_backend__01_data_00.t
    t/02_backend__01_data_01_auth.t
    t/02_backend__01_data_02_formats.t
    t/02_backend__01_data_03_general.t
    t/02_backend__01_data_04_board_00.t
    t/02_backend__01_data_04_board_01_optionsuser.t
    t/02_backend__01_data_04_board_02_optionsadmin.t
    t/02_backend__01_data_04_board_03_forms.t
    t/02_backend__01_data_04_board_04_views_00.t
    t/02_backend__01_data_04_board_04_views_01_categoryhide.t
    t/02_backend__01_data_04_board_05_datasecurity.t
    t/02_backend__01_data_04_board_06_avatars.t
    t/02_backend__01_data_04_board_07_uploads_01_functions.t
    t/02_backend__01_data_04_board_07_uploads_02_datasecurity.t
    t/02_backend__01_data_05_formats2.t
    t/03_frontend_00.t
    t/03_frontend_01_auth.t
    t/03_frontend_02_board_00.t
    t/03_frontend_02_board_01_errors.t
    t/03_frontend_02_board_02_options.t
    t/03_frontend_02_board_03_forms_00.t
    t/03_frontend_02_board_03_forms_01.t
    t/03_frontend_02_board_04_views_00.t
    t/03_frontend_02_board_04_views_01_categoryhide.t
    t/03_frontend_02_board_05_avatars.t
    t/03_frontend_02_board_06_uploads.t
    t/lib
    t/lib/Mock
    t/lib/Mock/Config.pm
    t/lib/Mock/Controller
    t/lib/Mock/Controller/App.pm
    t/lib/Mock/Controller/Log.pm
    t/lib/Mock/Controller.pm
    t/lib/Mock/Database.pm
    t/lib/Mock/Testuser.pm
    t/lib/Test
    t/lib/Test/Callcheck.pm
    t/lib/Test/General.pm
    t/var
    t/var/testdata.sql
);

my @public = qw(
    etc
    etc/ffc.json
    lib
    lib/Ffc
    lib/Ffc/Board.pm
    lib/Ffc/Auth.pm
    lib/Ffc/Board
    lib/Ffc/Board/Options.pm
    lib/Ffc/Board/Upload.pm
    lib/Ffc/Board/Views.pm
    lib/Ffc/Board/Forms.pm
    lib/Ffc/Board/Errors.pm
    lib/Ffc/Data
    lib/Ffc/Data/Board.pm
    lib/Ffc/Data/Auth.pm
    lib/Ffc/Data/Formats.pm
    lib/Ffc/Data/Board
    lib/Ffc/Data/Board/OptionsUser.pm
    lib/Ffc/Data/Board/Upload.pm
    lib/Ffc/Data/Board/Views.pm
    lib/Ffc/Data/Board/OptionsAdmin.pm
    lib/Ffc/Data/Board/Forms.pm
    lib/Ffc/Data/Board/Avatars.pm
    lib/Ffc/Data/General.pm
    lib/Ffc/Data.pm
    lib/Ffc/Errors.pm
    lib/Ffc.pm
    log
    log/development.log
    public
    public/custom
    public/custom/custom_static_content_placed_here
    public/themes
    public/themes/default
    public/themes/default/css
    public/themes/default/css/style.css
    public/themes/default/img
    public/themes/default/img/nofile.png
    public/themes/default/img/avatar.png
    public/themes/default/img/hg.png
    public/themes/default/img/favicon.png
    public/themes/default/img/smileys
    public/themes/default/img/smileys/devilsmile.png
    public/themes/default/img/smileys/unsure.png
    public/themes/default/img/smileys/look.png
    public/themes/default/img/smileys/sad.png
    public/themes/default/img/smileys/angry.png
    public/themes/default/img/smileys/smile.png
    public/themes/default/img/smileys/down.png
    public/themes/default/img/smileys/facepalm.png
    public/themes/default/img/smileys/what.png
    public/themes/default/img/smileys/evilgrin.png
    public/themes/default/img/smileys/tongue.png
    public/themes/default/img/smileys/ooo.png
    public/themes/default/img/smileys/smile.svg
    public/themes/default/img/smileys/cats.png
    public/themes/default/img/smileys/nope.png
    public/themes/default/img/smileys/no.png
    public/themes/default/img/smileys/sunny.png
    public/themes/default/img/smileys/crying.png
    public/themes/default/img/smileys/rofl.png
    public/themes/default/img/smileys/love.png
    public/themes/default/img/smileys/yes.png
    public/themes/default/img/smileys/twinkling.png
    public/themes/default/img/smileys/laughting.png
    public/themes/nostyle
    public/themes/nostyle/css
    public/themes/nostyle/css/style.css
    public/themes/nostyle/img
    public/themes/nostyle/img/nofile.png
    public/themes/nostyle/img/avatar.png
    public/themes/nostyle/img/favicon.png
    public/themes/nostyle/img/smileys
    public/themes/nostyle/img/smileys/devilsmile.png
    public/themes/nostyle/img/smileys/unsure.png
    public/themes/nostyle/img/smileys/look.png
    public/themes/nostyle/img/smileys/sad.png
    public/themes/nostyle/img/smileys/angry.png
    public/themes/nostyle/img/smileys/smile.png
    public/themes/nostyle/img/smileys/down.png
    public/themes/nostyle/img/smileys/facepalm.png
    public/themes/nostyle/img/smileys/what.png
    public/themes/nostyle/img/smileys/evilgrin.png
    public/themes/nostyle/img/smileys/tongue.png
    public/themes/nostyle/img/smileys/ooo.png
    public/themes/nostyle/img/smileys/cats.png
    public/themes/nostyle/img/smileys/nope.png
    public/themes/nostyle/img/smileys/no.png
    public/themes/nostyle/img/smileys/sunny.png
    public/themes/nostyle/img/smileys/crying.png
    public/themes/nostyle/img/smileys/rofl.png
    public/themes/nostyle/img/smileys/love.png
    public/themes/nostyle/img/smileys/yes.png
    public/themes/nostyle/img/smileys/twinkling.png
    public/themes/nostyle/img/smileys/laughting.png
    public/themes/README.pod
    script
    templates
    templates/layouts
    templates/layouts/default.html.ep
    templates/layouts/login.html.ep
    templates/board
    templates/board/optionsform.html.ep
    templates/board/uploadform.html.ep
    templates/board/help.html.ep
    templates/board/frontpage.html.ep
    templates/board/deletecheck.html.ep
    templates/board/uploaddeletecheck.html.ep
    templates/parts
    templates/parts/postboxform.html.ep
    templates/parts/categorylink.html.ep
    templates/parts/menu.html.ep
    templates/parts/error.html.ep
    templates/parts/footerlinks.html.ep
    templates/parts/attachement.html.ep
    templates/parts/info.html.ep
    templates/parts/userlistlinks.html.ep
    templates/parts/pagelinks.html.ep
    templates/parts/postbox.html.ep
    templates/auth
    templates/auth/loginform.html.ep
);

my @open = qw(
    data
    data/uploads
    data/avatars
);

sub processpath {
    my ( $paths, $dirmod, $filemod ) = @_;
    for my $path ( @$paths ) {
        my $abspath = File::Spec->catdir( File::Spec->splitpath( $FindBin::Bin  ), '..', File::Spec->splitpath( $path ) );
        say qq(    $abspath);
        `chgrp '$wwwgroup' '$abspath'`;
        if ( -d $abspath ) {
            `chmod '$dirmod' '$abspath'`;
        }
        else {
            `chmod '$filemod' '$abspath'`;
        }
    }
}

say '   #### plublic executable files';
processpath(\@publicexec, '750', '750');
say '   #### plublic readable files and directories';
processpath(\@public,     '750', '640');
say '   #### closed executables files';
processpath(\@closedexec, '700', '700');
say '   #### closed readable files and directories';
processpath(\@closed,     '700', '600');
say '   #### openly writable files and directories';
processpath(\@open,       '770', '660');

