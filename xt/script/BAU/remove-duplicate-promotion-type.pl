#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/ get_database_handle /;

=head1 DESCRIPTION 

Quick script to delete the duplicate entry in the promotion_type table because
I don't know how to do this in SQL.

This must be run before the patch that alters the table to enforce the unqiueness:
05-add-unique-constraint-promotion-type.sql

=cut

my $schema = get_database_handle({
    name => 'xtracker_schema',
    type => 'transaction'
});

my $promotion_type_rs  = $schema->resultset('Public::PromotionType');
my $order_promotion_rs = $schema->resultset('Public::OrderPromotion');

my @duplicates = $promotion_type_rs->search({ name => 'MR PORTER Postcard' })->all;

foreach my $duplicate ( @duplicates ) {
    if ( $order_promotion_rs->search({promotion_type_id => $duplicate->id})->all != 0 ) {
        warn $duplicate->id . ' has related entries in the order_promotion table';
    }
    else {
        warn $duplicate->id . ' is a duplicate and will be deleted';
        $duplicate->delete;
    }
}

@duplicates = $promotion_type_rs->search({ name => 'MR PORTER Postcard' })->all;
if (scalar(@duplicates) > 1) {
    warn  <<FAILED
============== ERROR =========== 

We still have duplicated 'MR PORTER Postcard' 
This will cause the 2011.08 release deployment to fail

PLEASE REPORT THIS ERROR TO THE RELEASE MANAGER

FAILED

}
