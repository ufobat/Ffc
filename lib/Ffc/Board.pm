package Ffc::Board;

use 5.010;
use strict;
use warnings;
use utf8;

use Mojo::Base 'Mojolicious::Controller';
use base 'Ffc::Board::Options';
use base 'Ffc::Board::Forms';
use base 'Ffc::Board::Upload';
use base 'Ffc::Board::Views';

1;

