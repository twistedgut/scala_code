package XTracker::Order::Printing::AddressCard;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::PrintFunctions;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Utilities qw(
    ucfirst_roman_characters
);

use vars qw($r $operator_id);

### Subroutine : generate_address_card          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_address_card :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $printer, $copies ) = @_;

    my $data = {
        shipment      => get_shipment_info( $dbh, $shipment_id )
    };

    ${$data}{shipping_address} = get_address_info( $dbh, ${$data}{shipment}{shipment_address_id} );

    ${$data}{shipping_address}{first_name} = ucfirst_roman_characters( ${$data}{shipping_address}{first_name} );
    ${$data}{shipping_address}{last_name} = ucfirst_roman_characters( ${$data}{shipping_address}{last_name} );

    my $result = 0;

    ${$data}{printer_info} = get_printer_by_name( $printer );

    if ( %{$data->{printer_info}||{}} ) {

        my $template_file = 'print/addresscard.tt';

        if (${$data}{printer_info}{orientation} && ${$data}{printer_info}{orientation} eq 'landscape') {
            $template_file = 'print/addresscard_landscape.tt';
        }
        my $html = create_document( 'addresscard-' . $shipment_id . '',
            $template_file, $data );

        $result = print_document( 'addresscard-' . $shipment_id . '',
            ${$data}{printer_info}{lp_name}, $copies );

        log_shipment_document(
            $dbh, $shipment_id,
            'Address Card',
            'addresscard-' . $shipment_id . '',
            ${$data}{printer_info}{name}
        );

    }

    return $result;

}

### Subroutine : _d2                            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;

