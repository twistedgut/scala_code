package XTracker::Order::Printing::OutwardProforma;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::XTemplate;
use XTracker::PrintFunctions;

use XTracker::Document::OutwardProforma;

### Subroutine : generate_outward_proforma      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #
# TODO         : this should be remove after all the printing section have been ported

sub generate_outward_proforma :Export(:DEFAULT) {
    my ( $dbh, $shipment_id, $printer, $copies )   = @_;

    my $owp = XTracker::Document::OutwardProforma
        ->new( shipment_id => $shipment_id );

    my $data = $owp->gather_data();

    my $printer_info = get_printer_by_name( $printer );

    if ( %{ $printer_info//{} } ) {
        create_document( $owp->basename, $owp->template_path, $data );

        print_document( $owp->basename, $printer_info->{lp_name}, $copies );

        $owp->log_document($printer_info->{name});
   }

    return;
}

1;

