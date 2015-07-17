#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::EOL;
all_perl_files_ok({ trailing_whitespace => 1 }, 'lib', 't', 't_aggregate' );
