#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

use Data::Dump qw(pp);
use FindBin;

use lib qq{$FindBin::RealBin/../lib};
use FindBin::libs qw( base=lib_dynamic );
use Event::Import;

my $filename = $ARGV[0]
    or die "usage: $0 filename\n";

my $ei = Event::Import->new;

if ($ei->parse( $filename )) {
    $ei->create_event;
    #pp $ei->get_prepared_data;
}
