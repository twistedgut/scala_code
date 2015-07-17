package ReportingInvoice;

use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::PrintFunctions;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::Customer;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Channel qw(get_channel_details);
use Encode::Encoder qw(encoder);

use XTracker::Config::Local qw( config_var returns_email shipping_email comp_addr comp_tel comp_fax );

use vars qw($r $operator_id);

sub generate_invoice :Export(:DEFAULT) {

    my ( $dbh, $pre_conversion_rate, $invoice_id, $printer, $copies, $use_country_currency ) = @_;

    my $data;

    # get invoice data
    $data->{invoice}            = get_invoice_info( $dbh, $invoice_id );
    $data->{item}               = get_invoice_item_info( $dbh, $invoice_id );
    $data->{invoice}{date}      = get_invoice_date( $dbh, $invoice_id );

    # get order/shipment data
    $data->{shipment}           = get_shipment_info( $dbh, $data->{invoice}{shipment_id} );
    $data->{order}              = get_order_info( $dbh, $data->{shipment}{orders_id} );
    $data->{channel}            = get_channel_details( $dbh, $data->{order}{sales_channel} );
    $data->{customer}           = get_customer_info( $dbh, $data->{order}{customer_id} );
    $data->{invoice_address}    = get_address_info( $dbh, $data->{order}{invoice_address_id} );
    $data->{shipping_address}   = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );
    $data->{country}            = get_invoice_country_info( $dbh, $data->{shipping_address}{country} );

    ### get stuff from config
    $data->{returns_email}      = returns_email( $data->{channel}{config_section} );
    $data->{shipping_email}     = shipping_email( $data->{channel}{config_section} );
    $data->{tt_comp_addr}       = comp_addr( $data->{channel}{config_section} );
    $data->{tt_comp_tel}        = comp_tel( $data->{channel}{config_section} );
    $data->{tt_comp_fax}        = comp_fax( $data->{channel}{config_section} );


    # use shipment date if no invoice date
    if ($data->{invoice}{date} eq ""){
        my ($part1, $part2) = split(/ /, $data->{shipment}{date});
        $data->{invoice}{date} = $part1;
    }


    # we may need to convert GBP to EUR but we'll default it to 1
    $data->{pre_conversion_rate} = 1;

    # we may need to convert totals into a local currency but we'll default it to 1
    $data->{conversion_rate}    = 1;

    # flag set to use country currency on invoice rather than order currency
    if ( $use_country_currency ) {
        $data->{conversion}             = _get_country_currency( $dbh, $data->{shipping_address}{country}, $data->{invoice}{date} );
    #die $data->{conversion}{rate};
        if ($data->{conversion}) {
            $data->{conversion_rate}    = $data->{conversion}{rate};
        }
    }

    # check for orders which were incorrectly placed in GBP
    if ($data->{order}{currency} eq 'GBP'){

        $data->{pre_conversion_rate} = $pre_conversion_rate;
        $data->{order}{currency} = 'EUR';

    }

    # default currency symbol to GBP
    $data->{currency_symbol} = "&#163;";

    if ($data->{order}{currency} eq "USD"){
        $data->{currency_symbol} = "&#36;";
    }

    if ($data->{order}{currency} eq "EUR"){
        $data->{currency_symbol} = "&#8364;";
    }

    if ($data->{conversion}{local_currency_code}) {
        $data->{currency_symbol} = $data->{conversion}{local_currency_code};
    }


    # not a customer order invoice
    if ($data->{invoice}{renumeration_class_id} != 1){
        $data->{shipment}{shipment_type_id} = 0;
        $data->{shipment}{gift} = "false";
        $data->{shipment}{gift_message} = "";
    }

    # workout item sub-totals
    foreach my $id ( keys %{ $data->{item} } ) {

        # if we've already got this item just increment quantity & sub_total
        if ( $data->{invoice_item}{$data->{item}{$id}{variant}} ){
            $data->{invoice_item}{$data->{item}{$id}{variant}}{quantity}    = $data->{invoice_item}{$data->{item}{$id}{variant}}{quantity} + 1;
            $data->{invoice_item}{$data->{item}{$id}{variant}}{total_price} += (($data->{item}{$id}{unit_price} + $data->{item}{$id}{tax} + $data->{item}{$id}{duty}) * $data->{pre_conversion_rate}) * $data->{conversion_rate};
        }
        else {

            $data->{invoice_item}{$data->{item}{$id}{variant}}{quantity}    = 1;
            $data->{invoice_item}{$data->{item}{$id}{variant}}{total_price} = (($data->{item}{$id}{unit_price} + $data->{item}{$id}{tax} + $data->{item}{$id}{duty}) * $data->{pre_conversion_rate}) * $data->{conversion_rate};
            $data->{invoice_item}{$data->{item}{$id}{variant}}{unit_price}  = _d2(($data->{item}{$id}{unit_price} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
            $data->{invoice_item}{$data->{item}{$id}{variant}}{tax}         = _d2(($data->{item}{$id}{tax} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
            $data->{invoice_item}{$data->{item}{$id}{variant}}{duty}        = _d2(($data->{item}{$id}{duty} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
            $data->{invoice_item}{$data->{item}{$id}{variant}}{name}        = $data->{item}{$id}{designer}." ".$data->{item}{$id}{name};

        $data->{invoice_item}{$data->{item}{$id}{variant}}{tax_rate} = $data->{country}{rate} * 100;
        }
    }

    # set up total invoice price
    $data->{invoice}{total_price} = 0;

    # add item sub totals to total price
    foreach my $id ( keys %{ $data->{invoice_item} } ) {
        $data->{invoice_item}{$id}{total_price} = _d2($data->{invoice_item}{$id}{total_price});
        $data->{invoice}{total_price}           += $data->{invoice_item}{$id}{total_price};
    }


    # tidy up values to 2 decimal places
    $data->{invoice}{total_price}   = _d2($data->{invoice}{total_price});
    $data->{invoice}{shipping}      = _d2(($data->{invoice}{shipping} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
    $data->{invoice}{store_credit}  = _d2(($data->{invoice}{store_credit} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
    $data->{invoice}{gift_credit}   = _d2(($data->{invoice}{gift_credit} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
    $data->{invoice}{misc_refund}   = _d2(($data->{invoice}{misc_refund} * $data->{pre_conversion_rate}) * $data->{conversion_rate});
    $data->{invoice}{grand_total}   = _d2($data->{invoice}{total_price} + $data->{invoice}{shipping} + $data->{invoice}{store_credit} + $data->{invoice}{gift_credit} + $data->{invoice}{misc_refund} );

    # split tax out of shipping if required
    if ($data->{country}{rate} > 0 ){
        $data->{invoice}{shipping_tax}  = _d2($data->{invoice}{shipping} - ($data->{invoice}{shipping} / ( 1 + $data->{country}{rate})));
        $data->{invoice}{shipping}      = _d2($data->{invoice}{shipping} - $data->{invoice}{shipping_tax});
    }

    # get default tax name and code from config if not set for shipping country
    if (!$data->{country}{tax_name}){
        $data->{country}{tax_name} = config_var('Tax', 'default_tax_name'); # "VAT"
    }

    if (!$data->{country}{tax_code}){
        $data->{country}{tax_code} = config_var('Tax', 'default_tax_code'); # "GB 743 7967 86"
    }


    # print result to return
    my $result = 1;

    my $document_name       = 'Invoice';
    my $document_filename   = 'invoice-VATREPORT-' . $invoice_id;

    # create html doc
    my $html = create_document( $document_filename, 'print/vat_report_invoice.tt', $data );

    return $result;

}

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

sub _get_country_currency :Export(:DEFAULT) {

    my ( $dbh, $country, $date ) = @_;

    my $rate;

    my $qry = "
        select c.local_currency_code, ler.rate
        from country c, local_exchange_rate ler
        where c.country = ?
        and c.id = ler.country_id
        and start_date < ?
        and (end_date is null or end_date > ?)
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country, $date, $date);

    $rate = $sth->fetchrow_hashref();

    return $rate;

}

1;
