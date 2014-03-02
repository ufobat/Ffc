package Ffc::Options;
use Mojo::Base 'Mojolicious::Controller';

sub options_form {
    my $c = shift;
    $c->stash(act => 'options');
    $c->render(template => 'board/optionsform');
}

sub switch_theme {
    my $c = shift;
    my $s = $c->session();
    $s->{style} = $s->{style} ? 0 : 1;
    $c->options_form();
}

sub font_size {
    my $c = shift;
    my $fs = $c->param('fontsize');
    $c->session()->{fontsize} = $fs
        if exists $Ffc::Config::FontSizeMap{$fs};
    $c->options_form();
}

sub no_bg_color {
    my $c = shift;
    my $s = $c->session();
    delete $s->{backgroundcolor};
    $c->dbh()->do(
        'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
        undef, '', $s->{user});
    $c->options_form();
}

sub bg_color {
    my $c = shift;
    unless ( $c->config()->{fixbackgroundcolor} ) {
        my $bgcolor = $c->param('bgcolor');
        my $s = $c->session();
        $c->dbh()->do(
            'UPDATE users SET bgcolor=? WHERE UPPER(name)=UPPER(?)',
            undef, $bgcolor, $s->{user});
        $s->{backgroundcolor} = $bgcolor;
    }
    $c->options_form();
}

1;

