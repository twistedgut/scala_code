package XTracker::Order::Printing::PremierShipmentInfo;

use strict;
use warnings;
use Perl6::Export::Attrs;
use Time::Piece;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::PrintFunctions;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Finance;
use XTracker::Constants::FromDB qw( :shipment_item_status );
use XTracker::Utilities qw( number_in_list );

use vars qw($r $dbh $operator_id);

### Subroutine : generate_premier_info           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_premier_info :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $printer, $copies ) = @_;

    ### get all info required

    my $data;

    # See "perldoc Time::Piece"
    ${$data}{date} = localtime->strftime('%d/%m/%Y');

    ${$data}{shipment}     = get_shipment_info( $dbh, $shipment_id );
    ${$data}{item}     = get_shipment_item_info( $dbh, $shipment_id );
    ${$data}{order}        = get_order_info( $dbh, ${$data}{shipment}{orders_id} );
    ${$data}{customer}        = get_customer_info( $dbh, ${$data}{order}{customer_id} );
    ${$data}{customer}{notes} = get_customer_notes( $dbh, ${$data}{order}{customer_id} );
    ${$data}{invoice_address}        = get_address_info( $dbh, ${$data}{order}{invoice_address_id} );
    ${$data}{shipping_address}        = get_address_info( $dbh, ${$data}{shipment}{shipment_address_id} );


    ${$data}{shipment}{total_price} = 0;

    foreach my $id ( keys %{ ${$data}{item} } ) {

        if (number_in_list(${$data}{item}{$id}{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) ) {

            my $sku = ${$data}{item}{$id}{legacy_sku};

            if ( ${$data}{shipment_item}{$sku}{name} ){
                ${$data}{shipment_item}{$sku}{quantity}++;
            }
            else {
                ${$data}{shipment_item}{$sku} = _get_item_attributes($dbh, ${$data}{item}{$id}{product_id});

                ${$data}{shipment_item}{$sku}{quantity} = 1;
                ${$data}{shipment_item}{$sku}{unit_price} = _d2(${$data}{item}{$id}{unit_price});
                ${$data}{shipment_item}{$sku}{tax} = _d2(${$data}{item}{$id}{tax});
                ${$data}{shipment_item}{$sku}{duty} = _d2(${$data}{item}{$id}{duty});

                ${$data}{shipment_item}{$sku}{name} = ${$data}{item}{$id}{name};
                ${$data}{shipment_item}{$sku}{sku} = $sku;

                ${$data}{shipment_item}{$sku}{total_price} = _d2(${$data}{item}{$id}{unit_price} + ${$data}{item}{$id}{tax} + ${$data}{item}{$id}{duty});
            }

            ${$data}{shipment}{total_price} += ${$data}{item}{$id}{unit_price} + ${$data}{item}{$id}{tax} + ${$data}{item}{$id}{duty};
        }

    }

    ${$data}{shipment}{total_price} = _d2(${$data}{shipment}{total_price});

    ${$data}{shipment}{shipping} = _d2(${$data}{shipment}{shipping_charge});

    ${$data}{shipment}{grand_total} = _d2(${$data}{shipment}{total_price} + ${$data}{shipment}{total_tax} + ${$data}{shipment}{shipping});

    if (${$data}{country}{rate} > 0 ){
        ${$data}{shipment}{shipping_tax} = _d2(${$data}{shipment}{shipping} - (${$data}{shipment}{shipping} / ( 1 + ${$data}{country}{rate})));

        ${$data}{shipment}{shipping} = _d2(${$data}{shipment}{shipping} - ${$data}{shipment}{shipping_tax});
    }

    my $result = 0;

    ${$data}{printer_info} = get_printer_by_name( $printer );

    if ( %{$data->{printer_info}||{}} ) {

        my $html = create_document( 'prminfo-' . $shipment_id . '',
            'print/premier_info_form.tt', $data );

        $result = print_document( 'prminfo-' . $shipment_id . '',
            ${$data}{printer_info}{lp_name}, $copies );

        log_shipment_document(
            $dbh, $shipment_id,
            'Premier Shipment Information',
            'prminfo-' . $shipment_id . '',
            ${$data}{printer_info}{name}
        );

   }

    return $result;

}

### Subroutine : _get_item_attributes           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_item_attributes {

    my ( $dbh, $prod_id ) = @_;

    my $qry = "select sa.scientific_term, sa.packing_note,
                      sa.weight, sa.fabric_content, c.country as country_of_origin, hs.hs_code, pt.product_type || ' - ' || st.sub_type as product_type
               from shipping_attribute sa LEFT JOIN country c ON sa.country_id = c.id, product p LEFT JOIN hs_code hs ON p.hs_code_id = hs.id LEFT JOIN sub_type st ON p.sub_type_id = st.id LEFT JOIN product_type pt ON p.product_type_id = pt.id
               where sa.product_id = ?
               and sa.product_id = p.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($prod_id);

    my $info = $sth->fetchrow_hashref();

    return $info;
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

