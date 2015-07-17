package XTracker::Order::Printing::RefundForm;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::Database::Invoice;
use XTracker::Database::Customer;
use XTracker::PrintFunctions;
use XTracker::DBEncode qw( decode_db );

use vars qw($r $operator_id);

### Subroutine : generate_refund_form           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_refund_form :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $printer, $copies ) = @_;

    my ($Second, $Minute,  $Hour,      $Day, $Month,
        $Year,   $WeekDay, $DayOfYear, $IsDST
        )
        = localtime(time);

    my $date_today = $Day . "-"
        . ( $Month + 1 ) . "-"
        . ( $Year + 1900 ) . " "
        . $Hour . ":"
        . $Minute;

    my $data = {
        today        => $date_today,
        order        => _get_refund_form_info( $dbh, $invoice_id ),
        invoice      => get_invoice_info( $dbh, $invoice_id ),
        invoice_item => get_invoice_item_info( $dbh, $invoice_id )
    };

    ${$data}{invoice}{total}
        = ${$data}{invoice}{shipping} + ${$data}{invoice}{misc_refund};

    foreach my $item_id ( keys %{ ${$data}{invoice_item} } ) {

        ${$data}{invoice_item}{$item_id}{sub_total}
            = _d2( ${$data}{invoice_item}{$item_id}{unit_price}
                + ${$data}{invoice_item}{$item_id}{tax}
                + ${$data}{invoice_item}{$item_id}{duty} );

        ${$data}{invoice_item}{$item_id}{unit_price}
            = _d2( ${$data}{invoice_item}{$item_id}{unit_price} );
        ${$data}{invoice_item}{$item_id}{tax}
            = _d2( ${$data}{invoice_item}{$item_id}{tax} );
        ${$data}{invoice_item}{$item_id}{duty}
            = _d2( ${$data}{invoice_item}{$item_id}{duty} );

        ${$data}{invoice}{total}
            += ${$data}{invoice_item}{$item_id}{sub_total};

    }

    ${$data}{invoice}{shipping}    = _d2( ${$data}{invoice}{shipping} );
    ${$data}{invoice}{misc_refund} = _d2( ${$data}{invoice}{misc_refund} );
    ${$data}{invoice}{total}       = _d2( ${$data}{invoice}{total} );

    if (${$data}{invoice}{alt_customer_nr} > 0 ){
        my $alt_cust_id = check_customer($dbh, ${$data}{invoice}{alt_customer_nr});

        if ( $alt_cust_id > 0 ){
            my $cust_info = get_customer_info( $dbh, $alt_cust_id );

            ${$data}{invoice}{alt_customer}{name} = $$cust_info{first_name}." ".$$cust_info{last_name};
            ${$data}{invoice}{alt_customer}{email} = $$cust_info{email};
        }
        else {
            ${$data}{invoice}{alt_customer}{name} = "Not Available";
            ${$data}{invoice}{alt_customer}{email} = "Not Available";
        }
    }

    ${$data}{currency_symbol} = "&#163;";

    if (${$data}{invoice}{currency_id} == 2){ ${$data}{currency_symbol} = "&#36;"; }
    if (${$data}{invoice}{currency_id} == 3){ ${$data}{currency_symbol} = "&#8364;"; }

    my $result = 0;

    ${$data}{printer_info} = get_printer_by_name( $printer );



    my $html = create_document( 'refundform-' . $invoice_id . '', 'print/refundform.tt', $data );

    ### only print it if its a valid printer
    if ( %{$data->{printer_info}||{}} ) {
        $result = print_document( 'refundform-' . $invoice_id . '',
                  ${$data}{printer_info}{lp_name}, $copies );

    log_shipment_document(
                  $dbh, ${$data}{invoice}{shipment_id},
                  'Refund Form',
                  'refundform-' . $invoice_id . '',
                  ${$data}{printer_info}{name}
                  );
    }
    else {
    $result = 0;
    }
    return $result;

}

### Subroutine : _get_refund_form_info          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_refund_form_info {

    my ( $dbh, $invoice_id ) = @_;

    my %info = ();

    my $qry
        = "SELECT o.order_nr, o.basket_nr, o.email, o.total_value, c.is_customer_number as customer_nr, a.first_name, a.last_name
                FROM renumeration r, shipment s, link_orders__shipment los, orders o LEFT JOIN customer c ON o.customer_id = c.id, order_address a
                WHERE r.id = ?
                AND r.shipment_id = s.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND o.invoice_address_id = a.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    my $info = $sth->fetchrow_hashref();
    $info->{$_} = decode_db( $info->{$_} ) for (qw(
        first_name
        last_name
    ));

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

