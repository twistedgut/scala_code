#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Barcode;
use XTracker::Config::Local qw( config_var );

chdir config_var('SystemPaths','barcode_dir');

for my $f (glob('sub_delivery-*.png')) {
    my ($group_id)=($f =~ /^sub_delivery-(\d+)\.png/);
    if (!$group_id) {
        warn "$f ?!\n";
        next;
    }
    unlink $f;
    create_barcode( "sub_delivery-$group_id", "p-$group_id", 'small', 3, 1, 65);
}
