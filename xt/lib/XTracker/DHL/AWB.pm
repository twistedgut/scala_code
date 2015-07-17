package XTracker::DHL::AWB;

use strict;
use warnings;
use Perl6::Export::Attrs;


### Subroutine : log_dhl_waybill        ###
# usage        :                                  #
# description  :  write DHL waybill to shipment table    #
# parameters   :   shipment_id, waybill, type                               #
# returns      :                                 #

sub log_dhl_waybill :Export() {
    my ( $dbh, $shipment_id, $waybill, $type ) = @_;

    my %qry = (
        "outward" => "update shipment set outward_airway_bill = ? where id = ?",
        "return" => "update shipment set return_airway_bill = ? where id = ?",
    );

    my $sth = $dbh->prepare($qry{$type});
    $sth->execute($waybill, $shipment_id);
}

1;
