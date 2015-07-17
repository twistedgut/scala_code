#!/opt/xt/xt-perl/bin perluse strict;
use strict;
use warnings;
# Hard-code lib directory so this script can be run from any dir on live
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw/schema_handle/;

my $schema = schema_handle;

# get all variants 
my $return_arrival_rs = $schema->resultset('Public::ReturnArrival')->search({},
                                            {
                                                join        =>   'shipment' ,
                                                '+select'   => [ 'shipment.id' ],
                                                '+as'       => [ 'shipment_id' ],
                                            },
                                        );
while (my $r_arrival = $return_arrival_rs->next){
    next unless $r_arrival->get_column('shipment_id');
    print "Adding link between return_arrival_id ". $r_arrival->id." and shipment_id " . $r_arrival->get_column('shipment_id')."\n";
    $schema->resultset('Public::LinkReturnArrivalShipment')->create({
        return_arrival_id => $r_arrival->id,
        shipment_id       => $r_arrival->get_column('shipment_id'),
    });
}
                                                         
