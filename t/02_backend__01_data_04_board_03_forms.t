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
srand;

use Test::More tests => 1;

Test::General::test_prepare();

use_ok('Ffc::Data::Board::Forms');

{
    note('sub insert_post( $username, $data, $category, $recipientname )');
}
{
    note('sub update_post( $username, $data, $postid )');
}
{
    note('sub delete_post( $username, $postid )');
}
