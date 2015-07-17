#!/opt/xt/xt-perl/bin/perl
##
# Inserts entries in the web db product_type table so
# we don't get missing foreign key problems
##

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

my $mrp_web_dbh = get_transfer_sink_handle({ environment => 'live', channel => "MRP" })->{dbh_sink};

my $sth = $mrp_web_dbh->prepare("
insert into product_type (code, description)
values (?, ?)
on duplicate key update description=description
");

foreach my $code (1..500) {
    my $product_type = sprintf("%03d", $code);
    $sth->execute($product_type, $product_type);
}

$mrp_web_dbh->commit();


1;
