package Ffc::Plugin::Config;
use 5.010;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use DBI;
use File::Spec::Functions qw(splitdir catdir);
use Digest::SHA 'sha512_base64';
use Ffc::Plugin::Config::Lists;
use Ffc::Plugin::Config::Uploads;

our %Defaults = (
    title           => 'Ffc Forum',
    cookiename      => 'Ffc_Forum',
    urlshorten      => 30,
    sessiontimeout  => 259200,
    postlimit       => 7,
    backgroundcolor => '',
    starttopic      => 0,
);

sub register {
    my ( $self, $app ) = @_;
    $self->reset();
    my $datapath  = $self->_datapath();
    my $dbh       = $self->dbh();
    my $config    = $self->_config();
    my $secconfig = $self->{secconfig} = {};

    for my $c ( qw(cookiesecret cryptsalt) ) {
        $secconfig->{$c} = $config->{$c};
        delete $config->{$c};
    }

    $app->secrets([$secconfig->{cookiesecret}]);
    $app->sessions->cookie_name(
        $config->{cookiename} || $Defaults{cookiename});
    $app->sessions->default_expiration(
        $config->{sessiontimeout} || $Defaults{sessiontimeout});

    unless ( $config->{urlshorten} and $config->{urlshorten} =~ m/\A\d+\z/xmso ) {
        $config->{urlshorten} = $Defaults{urlshorten};
    }
    unless ( $config->{starttopic} and $config->{starttopic} =~ m/\A\d+\z/xmso ) {
        $config->{starttopic} = $Defaults{starttopic};
    }

    $app->helper(datapath     => sub { $datapath  });
    $app->helper(dbh          => sub { $self->dbh });
    $app->helper(configdata   => sub { $config    });

    $app->defaults({
        page     => 1,
        lastseen => -1,
        map( {; $_ => undef }
            qw(postid topicid) ),
        map( {; $_ => [] }
            qw(additional_params topics users attachements) ),
        map( {;$_.'count' => 0} 
            qw(newmsgs newpost note) ),
        map( {;$_ => ''} 
            qw(error info warning query textdata heading description backtext queryurl pageurl queryreset
               dourl returl editurl msgurl delurl uplurl delupl downld backurl topicediturl ) ),
    });

    for my $w ( qw(info error warning ) ) {
        $app->helper( "set_$w" => 
            sub { shift()->stash($w => join ' ', @_) } );
        $app->helper( "set_${w}_f" => 
            sub { shift()->flash($w => join ' ', @_) } );
    }

    $app->helper( hash_password  => 
        sub { sha512_base64 $_[1], $secconfig->{cryptsalt} } );
    $app->helper( counting           => \&_counting );
    $app->helper( newpostcount       => \&_newpostcount );
    $app->helper( newmsgscount       => \&_newmsgscount );
    $app->helper( generate_topiclist => \&_generate_topiclist );
    $app->helper( generate_userlist  => \&_generate_userlist );
    $app->helper( image_upload       => \&_image_upload );

    $app->hook( before_render => sub { 
        my $c = $_[0];
        my $s = $c->session;
        $c->stash(
            backgroundcolor => ( $s->{backgroundcolor} || $config->{backgroundcolor} ),
            title           => ( $config->{title}      || $Defaults{title}           ),
        );
    });

    return $self;
}

sub _datapath {
    my $self = $_[0];
    return $self->{datapath} if $self->{datapath};
    die qq~need a directory as "FFC_DATA_PATH" environment variable ('~.($ENV{FFC_DATA_PATH}//'').q~')~
        unless $ENV{FFC_DATA_PATH} and -e -d -r $ENV{FFC_DATA_PATH};
    return $self->{datapath} = [ splitdir $ENV{FFC_DATA_PATH} ];
}

sub _config {
    return { map { @$_ } 
        @{ $_[0]->{dbh}->selectall_arrayref(
            'SELECT "key", "value" FROM "config"') } };
}

sub dbh {
    my $self = $_[0];
    return $self->{dbh} if $self->{dbh};
    $self->{dbfile} = catdir @{ $self->_datapath() }, 'database.sqlite3';
    $self->{dbh} = DBI->connect("DBI:SQLite:database=$self->{dbfile}", 
        '', '', { AutoCommit => 1, RaiseError => 1 })
        or die qq~could not connect to database "$self->{dbfile}": $DBI::errstr~;
    $self->{dbh}->{sqlite_unicode} = 1;
    return $self->{dbh};
}

sub reset {
    @{$_[0]}{qw(datapath dbh dbfile)} = (undef,undef,undef);
}

1;

