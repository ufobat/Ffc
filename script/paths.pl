#!/usr/bin/env perl
use 5.010;
use strict; use warnings; 
use utf8;
use FindBin;
use File::Spec;

my $wwwgroup = 'www';

my @publicexec = qw( script/ffc );

my @closedexec = qw( script/inituser.pl script/paths.pl );

my @closed = qw(
    .git
    README.pod
    etc/ffc.json.example
    t
    t/02_backend__01_data_02_formats.t
    t/02_backend__01_data_04_board_01_optionsuser.t
    t/03_frontend_02_board_02_options.t
    t/03_frontend_02_board_00.t
    t/02_backend__01_data_01_auth.t
    t/03_frontend_02_board_03_forms.t
    t/02_backend__01_data_04_board_02_optionsadmin.t
    t/02_backend__01_data_00.t
    t/01_aux______01_errorhandling.t
    t/02_backend__01_data_03_general.t
    t/03_frontend_00.t
    t/03_frontend_02_board_01_errors.t
    t/lib
    t/lib/Test
    t/lib/Test/Callcheck.pm
    t/lib/Test/General.pm
    t/lib/Mock
    t/lib/Mock/Testuser.pm
    t/lib/Mock/Config.pm
    t/lib/Mock/Database.pm
    t/lib/Mock/Controller.pm
    t/lib/Mock/Controller
    t/lib/Mock/Controller/App.pm
    t/lib/Mock/Controller/Log.pm
    t/02_backend__01_data_04_board_03_forms.t
    t/02_backend__01_data_04_board_05_datasecurity.t
    t/02_backend__01_data_04_board_04_views.t
    t/03_frontend_01_auth.t
    t/03_frontend_02_board_04_views.t
    t/var
    t/var/testdata.sql
    t/var/database.sql
    t/02_backend__01_data_04_board_00.t
    data/uploads/uploads_placed_here
    data/avatars/avatar_pics_placed_here
);

my @public = qw(
    lib
    lib/Ffc
    lib/Ffc/Board.pm
    lib/Ffc/Auth.pm
    lib/Ffc/Board
    lib/Ffc/Board/Options.pm
    lib/Ffc/Board/Views.pm
    lib/Ffc/Board/Forms.pm
    lib/Ffc/Board/Errors.pm
    lib/Ffc/Data
    lib/Ffc/Data/Board.pm
    lib/Ffc/Data/Auth.pm
    lib/Ffc/Data/Formats.pm
    lib/Ffc/Data/Board
    lib/Ffc/Data/Board/OptionsUser.pm
    lib/Ffc/Data/Board/Views.pm
    lib/Ffc/Data/Board/OptionsAdmin.pm
    lib/Ffc/Data/Board/Forms.pm
    lib/Ffc/Data/Board/Avatars.pm
    lib/Ffc/Data/General.pm
    lib/Ffc/Data.pm
    lib/Ffc/Errors.pm
    lib/Ffc.pm
    script
    templates
    templates/layouts
    templates/layouts/default.html.ep
    templates/layouts/login.html.ep
    templates/board
    templates/board/optionsform.html.ep
    templates/board/frontpage.html.ep
    templates/board/deletecheck.html.ep
    templates/parts
    templates/parts/postboxform.html.ep
    templates/parts/categorylink.html.ep
    templates/parts/menu.html.ep
    templates/parts/error.html.ep
    templates/parts/footerlinks.html.ep
    templates/parts/info.html.ep
    templates/parts/userlistlinks.html.ep
    templates/parts/pagelinks.html.ep
    templates/parts/postbox.html.ep
    templates/auth
    templates/auth/loginform.html.ep
    log
    log/development.log
    etc
    etc/ffc.json
    public
    public/themes
    public/themes/default
    public/themes/default/css
    public/themes/default/css/style.css
    public/themes/default/img
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
    public/themes/README.pod
    public/themes/blau
    public/themes/blau/css
    public/themes/blau/css/elements.css
    public/themes/blau/css/postbox.css
    public/themes/blau/css/menu.css
    public/themes/blau/css/body.css
    public/themes/blau/css/style.css
    public/themes/blau/img
    public/themes/blau/img/hg.png
    public/themes/blau/img/favicon.png
    public/themes/blau/img/smileys
    public/themes/blau/img/smileys/devilsmile.png
    public/themes/blau/img/smileys/unsure.png
    public/themes/blau/img/smileys/look.png
    public/themes/blau/img/smileys/sad.png
    public/themes/blau/img/smileys/angry.png
    public/themes/blau/img/smileys/smile.png
    public/themes/blau/img/smileys/down.png
    public/themes/blau/img/smileys/what.png
    public/themes/blau/img/smileys/evilgrin.png
    public/themes/blau/img/smileys/tongue.png
    public/themes/blau/img/smileys/ooo.png
    public/themes/blau/img/smileys/cats.png
    public/themes/blau/img/smileys/nope.png
    public/themes/blau/img/smileys/no.png
    public/themes/blau/img/smileys/sunny.png
    public/themes/blau/img/smileys/crying.png
    public/themes/blau/img/smileys/rofl.png
    public/themes/blau/img/smileys/love.png
    public/themes/blau/img/smileys/yes.png
    public/themes/blau/img/smileys/twinkling.png
    public/themes/blau/img/smileys/laughting.png
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

say '####### plublic executable files';
processpath(\@publicexec, '750', '750');
say '####### plublic readable files and directories';
processpath(\@public,     '750', '640');
say '####### closed executables files';
processpath(\@closedexec, '700', '700');
say '####### closed readable files and directories';
processpath(\@closed,     '700', '600');
say '####### openly writable files and directories';
processpath(\@open,       '770', '660');

