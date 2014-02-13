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
use Ffc::Data::General;
srand;

use Test::More tests => 21;

Test::General::test_prepare();
my @themes = @{ Ffc::Data::General::get_themes() };
my @colors = @Ffc::Data::Colors;

use_ok('Ffc::Data::Board::OptionsUser');

run_test(0,0);
run_test(1,0);
run_test(0,1);
run_test(1,1);

sub test_data {
    my $session = {user => Mock::Testuser->new_active_user()->{name}};
    my $color = $colors[ int rand $#colors ];
    my $theme = $themes[ int rand $#themes ];
    return $session, $color, $theme;
}

sub run_test {
    my  ( $fixbgcolor, $fixtheme ) = @_;
    note('testing view customization');
    note('bgcolor can'.($fixbgcolor ? ' not' : '').' be changed'); 
    note('theme can'.($fixtheme ? ' not' : '').' be changed'); 

    $Ffc::Data::FixBgColor = $fixbgcolor;
    $Ffc::Data::FixTheme   = $fixtheme;

    my ( $session, $color, $theme ) = test_data();

    {
        eval { Ffc::Data::Board::OptionsUser::update_bgcolor($session, $color) };
        if ( $fixbgcolor ) {
            ok $@, 'error changing color';
            like $@, qr'Hintergrundfarbe kann nicht geändert werden, wenn sie vom Forenadmin festgelegt wurde', 'error changing color looks good';
            isnt $session->{bgcolor}, $color, 'color not changed in session';
        }
        else {
            ok !$@, 'no error changing color';
            is $session->{bgcolor}, $color, 'color changed in session';
        }
    }

    {
        eval { Ffc::Data::Board::OptionsUser::update_theme($session, $theme) };
        if ( $fixtheme ) {
            ok $@, 'error changing theme';
            like $@, qr'Anzeigethema kann nicht geändert werden, wenn es vom Forenadmin festgelegt wurde', 'error changing theme looks good';
            isnt $session->{theme}, $theme, 'theme not changed in session';
        }
        else {
            ok !$@, 'no error changing theme';
            is $session->{theme}, $theme, 'theme changed in session';
        }
    }
}


