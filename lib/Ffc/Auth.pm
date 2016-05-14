package Ffc::Auth;
use strict; use warnings; use utf8;
use Mojo::Base 'Mojolicious::Controller';

sub install_routes {
    my $r = $_[0];
    # Anmeldehandling und Anmeldeprüfung
    $r->post('/login')->to('auth#login')->name('login');
    $r->get('/logout')->to('auth#logout')->name('logout');
    return $r->under('/')
             ->to('auth#check_login')
             ->name('login_check');
}

sub check_login {
    my $c = shift;
    if ( $c->login_ok ) {
        my $s = $c->session();
        my $r = $c->dbh_selectall_arrayref(
            'SELECT "admin", "bgcolor", "name", "autorefresh", 
                "chronsortorder", COALESCE("topiclimit",20), COALESCE("postlimit",10), COALESCE("printpreviewdays", 7),
                "hidelastseen", "newsmail", "usercolor"
            FROM "users" WHERE "active"=1 AND "id"=?',
            $s->{userid});

        if ( $r and @$r and $r->[0]->[2] eq $s->{user} ) {
            @$s{qw(admin backgroundcolor autorefresh chronsortorder topiclimit postlimit printpreviewdays hidelastseen newsmail usercolor)}
                = @{$r->[0]}[0, 1, 3, 4, 5, 6, 7, 8, 9, 10];
            $s->{backgroundcolor} = $c->configdata->{backgroundcolor}
                unless $s->{backgroundcolor};
            $c->dbh_do('UPDATE "users" SET "lastonline"=CURRENT_TIMESTAMP WHERE "id"=? AND "hidelastseen"=0',
                $s->{userid}) unless $c->match->endpoint->name() eq 'countings';
            return 1;
        }
        else {
            $c->logout();
            $c->set_info('');
            $c->set_error('Fehler mit der Anmeldung');
            return;
        }
    }
    $c->session->{lasturl} = $c->req->url->path_query;
    $c->render(template => 'loginform');
    return;
}

sub login {
    my $c = shift;
    my $u = $c->param('username') // '';
    my $p = $c->param('password') // '';
    if ( !$u or !$p ) {
        $c->set_error('Bitte melden Sie sich an');
        return $c->render(template => 'loginform', status => 403);
    }
    my $r = $c->dbh_selectall_arrayref(
        'SELECT u.admin, u.bgcolor, u.name, u.id, u.autorefresh, 
            u.chronsortorder, u.topiclimit, u.postlimit
        FROM users u WHERE UPPER(u.name)=UPPER(?) AND u.password=? AND active=1',
        $u, $c->hash_password($p));
    if ( $r and @$r ) {
        @{$c->session}{qw(admin backgroundcolor user userid autorefresh chronsortorder topiclimit postlimit)}
            = @{$r->[0]}[0, 1, 2, 3, 4, 5, 6, 7];
        if ( my $lasturl = $c->session->{lasturl} ) {
            undef $c->session->{lasturl};
            $c->redirect_to($lasturl);
            return;
        }
        return $c->redirect_to('show');
    }
    $c->set_error('Fehler bei der Anmeldung');
    $c->render(template => 'loginform', status => 403);
}

sub logout {
    my $c = shift;
    my $s = $c->session;
    delete $s->{user};
    delete $s->{userid};
    delete $s->{backgroundcolor};
    delete $s->{usercolor};
    delete $s->{admin};
    delete $s->{autorefresh};
    delete $s->{chronsortorder};
    delete $s->{topiclimit};
    delete $s->{postlimit};
    delete $s->{printpreviewdays};
    $c->set_info('Abmelden erfolgreich');
    $c->render(template => 'loginform');
}

1;

