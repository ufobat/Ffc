package Ffc::Admin; # AdminBoardsettings
use 5.18.0;
use strict; use warnings; use utf8;

###############################################################################
sub boardsettingsadmin {
    my $c = shift;
    my $optkey = $c->param('optionkey') // '';
    my $optvalue = $c->param('optionvalue') // '';
    my @setting = grep {$optkey eq $_->[0]} @Ffc::Admin::Settings;
    unless ( @setting ) {
        $c->redirect_to('admin_options_form');
        return; # theoretisch nicht möglich laut routen
    }
    my ( $tit, $re, $rechk, $err, $sub ) = @{$setting[0]}[1,2,3,7,8];
    # Die zentrale FarbRegex steht erst zur Laufzeit zur Verfügung und kann deswegen nicht oben schon in die
    # Array-Ref beim use hinein kopiert werden, deswegen hier der Umweg über die Sub:
    'CODE' eq ref $re and $re = $re->(); 

    unless ( $tit ) {
        $c->redirect_to('admin_options_form');
        return; # theoretisch nicht möglich laut routen
    }
    if ( ( $rechk and $optvalue =~ $re ) or ( not $rechk and ( $optvalue eq '1' or not $optvalue ) ) ) {
        $c->dbh_do('UPDATE "config" SET "value"=? WHERE "key"=?',
            $optvalue, $optkey);
        $c->configdata->{$optkey} = $optvalue;
        if ( $sub ) {
            $sub->($c, $optkey, $optvalue);
        }
        $c->set_info_f("$tit geändert");
    }
    else {
        $c->set_error_f($err);
    }

    $c->redirect_to('admin_options_form');
}

###############################################################################
sub set_starttopic {
    my $c = shift;
    my $tid = $c->param('topicid');
    $tid = 0 unless $tid;
    if ( $tid =~ $Ffc::Digqr ) {
        $c->dbh_do(q~UPDATE "config" SET "value"=? WHERE "key"='starttopic'~,
            $tid);
        $c->configdata->{starttopic} = $tid;
        $c->set_info_f("Startseitenthema geändert");
    }
    else {
        $c->set_error_f('Fehler beim Setzen der Startseite');
    }
    $c->redirect_to('admin_options_form');
}

1;

