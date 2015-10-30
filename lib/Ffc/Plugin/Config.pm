package Ffc::Plugin::Config;
use 5.010;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Plugin';

use DBI;
use File::Spec::Functions qw(splitdir catdir catfile);
use Digest::SHA 'sha512_base64';
use Ffc::Plugin::Config::Lists;

our %Defaults = (
    title           => 'Ffc Forum',
    urlshorten      => 30,
    sessiontimeout  => 259200,
    backgroundcolor => '',
    starttopic      => 0,
    maxscore        => 10,
    cookiename      => 'ffc_cookie',
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

    for ( qw(urlshorten starttopic) ) {
        unless ( $config->{$_} and $config->{$_} =~ m/\A\d+\z/xmso ) {
            $config->{$_} = $Defaults{$_};
        }
    }

    $app->helper(datapath    => sub { $datapath  });
    $app->helper(configdata  => sub { $config    });
    $app->helper(data_return => \&_data_return    );

    $app->helper(dbh                    => sub { dbh($self) }        );
    $app->helper(dbh_selectall_arrayref => \&_dbh_selectall_arrayref );
    $app->helper(dbh_do                 => \&_dbh_do                 );

    for ( qw(title backgroundcolor) ) {
        $config->{$_} = $Defaults{$_}
            unless $config->{$_};
    }

    $app->defaults({
        configdata => $config,
        page       => 1,
        lastseen   => -1,
        map( {; $_ => undef }
            qw(postid topicid) ),
        map( {; $_ => [] }
            qw(additional_params topics users attachements) ),
        map( {;$_.'count' => 0} 
            qw(newmsgs newpost note readlater) ),
        map( {;$_ => ''} 
            qw(error info warning query textdata heading description backtext queryurl pageurl queryreset
               dourl returl editurl moveurl msgurl delurl uplurl delupl downld backurl topicediturl ) ),
    });

    for my $w ( qw(info error warning ) ) {
        $app->helper( "set_$w" => 
            sub { $_[0]->stash($w => join ' ', ($_[0]->stash($w) // ()), @_[1 .. $#_]) } );
        $app->helper( "set_${w}_f" => 
            sub { $_[0]->flash($w => join ' ', ($_[0]->stash($w) // ()), @_[1 .. $#_]) } );
    }

    $app->helper( hash_password  => 
        sub { sha512_base64 $_[1], $secconfig->{cryptsalt} } );
    $app->helper( counting           => \&_counting );
    $app->helper( newpostcount       => \&_newpostcount );
    $app->helper( newmsgscount       => \&_newmsgscount );
    $app->helper( readlatercount     => \&_readlatercount );
    $app->helper( generate_topiclist => \&_generate_topiclist );
    $app->helper( generate_userlist  => \&_generate_userlist );

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
    return $_[0]->{dbh} if $_[0]->{dbh};
    my $self = $_[0];
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

{
my %sths;
sub _dbh_selectall_arrayref {
    my $c = shift; my $sql = shift;
    my $sth = exists $sths{$sql}
        ? $sths{$sql}
        : $sths{$sql} = $c->dbh->prepare($sql)
            || die $sths{$sql}->errstr;
    $sth->execute( @_ ) or die $sth->errstr;
    return $sth->fetchall_arrayref || die $sth->errstr;
}
sub _dbh_do {
    my $c = shift; my $sql = shift;
    my $sth = exists $sths{$sql}
        ? $sths{$sql}
        : $sths{$sql} = $c->dbh->prepare($sql)
            || die $sths{$sql}->errstr;
    $sth->execute( @_ ) or die $sth->errstr;
    $sth->finish;
}
}

sub _data_return {
    my ( $c, $template, $data ) = @_;
    my $h = $c->req->headers->header('X-Requested-With');
    if ( $h and $h eq 'XMLHttpRequest' ) {
        $c->render_json($data);
    }
    else {
        $c->render(template => $template);
    }
}

1;

