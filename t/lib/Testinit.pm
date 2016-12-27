package Testinit;

use strict;
use warnings;
use 5.010;

use File::Spec::Functions qw(catfile splitdir catdir);
use File::Basename;
use File::Temp;
use Data::Dumper;
use Test::More;
use DBI;
use lib 
  catdir(splitdir(File::Basename::dirname(__FILE__)), '..', '..', 'lib');

our $Script 
    = catfile( splitdir(File::Basename::dirname(__FILE__)),
        '..', '..', 'script', 'init.pl' );
our @Chars = ('a' .. 'z', 'A' .. 'C', 'E' .. 'N', 'Q' .. 'X', 'Y', 'Z'); # 'D' und so wird in Smilies verwendet, das geht für Tests blöd, Smilies werden extra getestet
{
    my $scnt = 1;
    my $ts = sub { join '', map { $Chars[int rand @Chars] } 1 .. 3 }; # "oo" wegen den what.png-Smileys
    sub test_randstring { sprintf "%s%04d%s", $ts->(), $scnt++, $ts->() }
}

our $CookieName = test_randstring();
our @Users; our %Users;

sub start_test {
    my $testpath = File::Temp::tempdir( CLEANUP => 1 );
    note "using test data dir '$testpath'";
    $ENV{FFC_DATA_PATH} = $testpath;
    my ( $csecret, $salt, $user, $pw ) 
        = (split /\n+/, qx($Script '-d' '$CookieName' 2>&1) )[-4,-3,-2,-1];
    chomp $user; chomp $salt; chomp $pw; chomp $csecret;
    note "user '$user':'$pw' (salt $salt, secret $csecret) created";
    my $t = Test::Mojo->new('Ffc');
    _add_user_to_list($t, 1, $user, $pw);
    note "CONFIG:\n" . Dumper($t->app->configdata);
    @Users = ( $user ); $Users{$user} = 1;
    return $t, $testpath, $user, $pw, test_dbh($testpath), $salt, $csecret;
}

sub test_logout {
    $_[0]->get_ok('/logout')
         ->status_is(200)
         ->content_like(qr/Angemeldet als "\&lt;noone\&gt;"/);
}

sub test_login {
    my ( $t, $u, $p ) = @_;

    test_logout($t);
    note "try to login in as '$u'" . ( exists $Users{$u} ? " (id=$Users{$u})" : '' );
    #diag "login as user '$u'";

    $t->post_ok('/login', form => { username => $u, password => $p })
      ->status_is(302)
      ->header_like(location => qr~/~);
    $t->get_ok('/forum')
      ->status_is(200)
      ->content_like(qr/Angemeldet als "$u"/);

    note "logged in as '$u'" . ( exists $Users{$u} ? " (id=$Users{$u})" : '' );

    return $t;
}

sub test_dbh {
    my ( $path ) = shift;
    DBI->connect('dbi:SQLite:database='.catfile($path, 'database.sqlite3')
        , { AutoCommit => 1, RaiseError => 1 });
}

sub test_error {
    my ( $t, $error ) = @_;
    $t->content_like(qr~<div\s+class="error">\s*<h1>Fehler</h1>\s*<p>\s*$error\s*</p>\s*</div>~);
    unless ( $t->success ) {
        diag(Dumper([caller(1)])); 
        diag 'HERKUNFT: ' . join ' ; ', map {; join ', ', (caller($_))[1,2] } 0 .. 3; 
    }
}

sub test_info {
    my ( $t, $info ) = @_;
    $t->content_like(
        qr~<div\s+class="info">\s*<h1>Hinweis</h1>\s*<p>\s*$info\s*</p>\s*</div>~);
    unless ( $t->success ) {
       diag(Dumper([caller(1)])); 
    }
}

sub test_warning {
    my ( $t, $warning ) = @_;
    use Carp;
    $t->content_like(
        qr~<div\s+class="warning">\s*<h1>Warnung</h1>\s*<p>\s*$warning\s*</p>\s*</div>~);
    unless ( $t->success ) {
       diag(Dumper([caller(1)])); 
    }
}

sub test_add_user { &test_add_users } # Alias
sub test_add_users {
    my $t = shift; my $admin = shift; my $apass = shift;
    test_login($t, $admin, $apass);
    my $cnt = 0;
    while ( @_ ) {
        my $user = shift;
        my $pass = shift;
        last unless $user and $pass;
        push @Users, $user;
        $Users{$user} = @Users;
        $t->post_ok('/admin/useradd', form => {username => $user, newpw1 => $pass, newpw2 => $pass, active => 1})
          ->status_is(302)->header_is(Location => '/admin/form')->content_is('');
        $t->get_ok('/admin/form')->status_is(200)
          ->content_like(qr~Benutzer \&quot;$user\&quot; angelegt~);
        $cnt++;
    }
    test_logout($t);
    if ( $cnt ) {
        note $cnt == 1
            ? 'one user created'
            : "$cnt users created";
    }
    else {
        diag 'no users created';

    }
    return $t;
}

sub test_get_userid {
    my $dbh = shift;
    my $user = shift;
    $dbh->selectall_arrayref('SELECT id FROM users WHERE UPPER(name)=UPPER(?)', undef, $user)->[0]->[0];
}

###############################################################################
# Gebräuchliche Benutzer- und Beitragsverwaltung

my @userlist;
sub _add_user_to_list {
    push @userlist, { t => $_[0], userid => $_[1], username => $_[2], password => $_[3] };
}
sub make_userobjs {
    my ( $t, $cnt, $admininit, $apassinit ) = @_;
    return map {
        my $u = { userid => $_, t => Test::Mojo->new('Ffc') };
        $u->{$_} = Testinit::test_randstring() for qw~username password~;
        Testinit::test_add_users( $t, $admininit, $apassinit, $u->{username}, $u->{password} );
        Testinit::test_login($u->{t}, $u->{username}, $u->{password});
        push @userlist, $u;
        $u;
    } 2 .. $cnt + 1;
}
sub userlist { wantarray ? @userlist : \@userlist }

# Liste der Beiträge für weitere Verwendung
my $id = 1; my @forums; my @pmsgss;

# Abstrahierte Beitragserstellung
sub _add {
    my ($u, $tu, $cnt, $givenstr) = @_;
    my $uid = $u->{userid};
    for my $i ( 1 .. $cnt ) {
        my $str = $givenstr // '___' . Testinit::test_randstring() . '___';
        note '----------';
        note '  add to '.($tu?'pmsgs':'forum').": $str";
        note "    userfrom = $u->{userid} ($u->{username})";
        note "    userto   = $tu->{userid} ($tu->{username})" if $tu;
        my $new = {
            userfrom => $u, 
            userto   => $tu, 
            postid   => $id++,
            content  => $str, 
            newflags => {map {;$_->{userid} => {isnew => 1, user => $_}} @userlist}
        };
        $new->{newflags}->{$u->{userid}}->{isnew} = 0;
        my $arr = $tu? \@pmsgss : \@forums;
        push @$arr, $new;
        if ( $givenstr ) {
            note "  call allready done (topic creation?)";
        }
        else {
            note "  real insert call";
            my $url = $tu ? "/pmsgs/$tu->{userid}" : '/topic/1';
            $u->{t}->post_ok("$url/new", form => { textdata => $str })
              ->status_is(302)->content_is('')
              ->header_like(location => qr~$url~);
            $u->{t}->get_ok($url)->status_is(200)->content_like(qr~$str~);
        }
    }
}

# Forenbeitrag erstellen
sub add_forum { _add($_[0], undef, $_[1], $_[2]) }
# Privatnachricht erstellen
sub add_pmsgs { _add(@_[0,1,2,3]) }

# Forenbeiträge zu Debug-Zwecken anzeigen
sub _show_posts {
    my $posts = $_[0];
    my $usermap = sub {
        my $u = $_[0];
        return join ', ', map {"$_ = $u->{$_}"} qw~userid username~;
    };
    note '';
    note '--------------------';
    for my $p ( @$posts ) {
        note '';
        note ' -- ' . ( $p->{userto} ? 'pmsgs' : 'forum' ) . ": postid => $p->{postid} -- content => $p->{content}";
        my $k = 'userfrom';
        note '    - from  : ' . $usermap->($p->{$k});
        $k    = 'userto';
        note '    - to    : ' . $usermap->($p->{$k}) if $p->{$k};
        $k    = 'newflags';
        note '    - isnew : ';
        for my $fid ( sort keys %{$p->{$k}} ) {
            my ( $n, $u ) = @{$p->{$k}->{$fid}}{qw~isnew user~};
            note '       '.($n ? '*' : ' ').' '.$usermap->($u);
        }
    }
};

sub show_forums { _show_posts( \@forums ) }
sub show_pmsgss { _show_posts( \@pmsgss ) }

sub forums { wantarray ? @forums : \@forums }
sub pmsgss { wantarray ? @pmsgss : \@pmsgss }

sub isnew {
    return 
        $_[1]->{newflags}->{$_[0]->{userid}}->{isnew} 
            ? 1 : 0;
}

sub resetall {
    my $u = shift; my $url = shift; my @posts = @_;
    note '';
    note "---------- set all postings as read for userid $u->{userid} via $url";
    $u->{t}->get_ok($url)->status_is(200);
    $_->{newflags}->{$u->{userid}}->{isnew} = 0 for @posts;
}

1;

