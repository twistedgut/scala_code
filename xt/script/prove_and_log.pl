#!/usr/bin/env perl
use strict;
use warnings;

use App::Prove;
use Log::Log4perl ':easy';
$ENV{Log4perlLevel} ||= $TRACE;
Log::Log4perl->easy_init( $ENV{Log4perlLevel} );

my $app = App::Prove->new;
$app->process_args(@ARGV);
exit( $app->run ? 0 : 1 );

