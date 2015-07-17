package XTracker::DHL::RoutingRequest;

use strict;
use warnings;

use XTracker::Database::Shipment qw( get_shipping_address );
use XTracker::Config::Local qw( dhl_xmlpi config_var );
use XTracker::Database qw(get_schema_using_dbh);
use NAP::ShippingOption;
use Perl6::Export::Attrs;
use XTracker::Logfile qw( xt_logger );
use Data::Dump qw/pp/;

### Subroutine : get_dhl_destination_code        ###
# usage        :                                  #
# description  :  request destination code via DHL Rounting XMLPI     #
# parameters   :   shipment id                               #
# returns      :    3 character Destination Code     - errors logged to DB                       #

sub get_dhl_destination_code :Export() {

    my ( $dbh, $shipment_id ) = @_;
    my $schema = get_schema_using_dbh($dbh,'xtracker_schema');
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);
    my $current_time = $schema->db_now();

    #need to know DHL global code for shipping option
    my $shipping_option_info = {
        shipping_account_name => $shipment->shipping_account->name,
        shipment_type         => $shipment->shipment_type->type,
        sub_region            => $shipment->get_shipment_sub_region,
        is_voucher_only       => $shipment->is_voucher_only ? 1 : 0,
    };
    my $shipping_option = NAP::ShippingOption->new_from_query_hash($shipping_option_info);
    my $destination_code;

    # get shipment data for XML request
    my $row = get_shipping_address($dbh, $shipment_id);
    $$row{date} =~ s/ /T/;

    # send request to dhl
    my $response = send_dhl_destination_code_request( {
            shipment_address  => $row,
            is_dutiable       => $shipment->is_dhl_dutiable,
            shipment_value    => $shipment->total_price,
            current_time      => $current_time,
    } );

    # log any errors
    my $errors_do_not_query_db;
    if ( $response->{error} ) {

        my $qry = "INSERT INTO routing_request_log (
                       date,
                       shipment_id,
                       error_code,
                       error_message )
                   VALUES ( current_timestamp, ?, ?, ? )";

        my $sth = $dbh->prepare($qry);

        while ( my ($code, $message) = each %{$response->{error}} ) {
            $sth->execute( $shipment_id, $code, substr($message, 0, 255) );
            $errors_do_not_query_db = 1;
        }
    }
    # successful response
    else {
        $destination_code = $response->{ServiceAreaCode};
    }

    # if no destination code returned from DHL API check previous orders for
    # customer but ONLY do this if we did not get an error from DHL.
    # The net effect of this is that we only fall back to this if we cannot
    # connect to DHL to make the query.
    if ( ! $destination_code && ! $errors_do_not_query_db ) {
        my $qry = "SELECT destination_code
            FROM shipment
            WHERE shipment_address_id = (select shipment_address_id from shipment where id = ?)
            AND id != ?
            AND destination_code != ''
            ORDER BY date DESC LIMIT 1";

        my $sth = $dbh->prepare($qry);
        $sth->execute($shipment_id, $shipment_id);

        while ( my $row = $sth->fetchrow_hashref() ) {
            $destination_code = $row->{destination_code};
        }
    }

    return $destination_code;
}


### Subroutine : send_dhl_destination_code_request        ###
# usage        :                                  #
# description  :  validate address via DHL Rounting XMLPI     #
# parameters   :   address hash                               #
# returns      :    parsed XML response                            #

sub send_dhl_destination_code_request :Export() {
    my $args = shift;

    my $destination_code = "";
    my $request_xml;
    my $response_xml;
    my $data;

    ### get xmlpi details from the config
    my $xmlpi_info = dhl_xmlpi();
    my $maximum_call_retries = 10;

    ### build routing request XML
    $request_xml = XTracker::DHL::XMLDocument::build_request_xml( $args );

    ### send XML request
    eval {
        my $xml_request = XTracker::DHL::XMLRequest->new(client_host => $xmlpi_info->{address}, request_xml => $request_xml);
        $response_xml = $xml_request->send_xml_request;
    };

    if ($@){
        $data->{error}{X} = $@;
    }
    else {
        ### parse response
        eval {
            $data = XTracker::DHL::XMLDocument::parse_xml_response(
                $response_xml);
        };
        if (my $e = $@) {
            xt_logger->warn( __PACKAGE__ .": parse_xml_response failed - "
                . pp($e)
                ."\nREQUEST:\n$request_xml" )
                    unless exists $ENV{HARNESS_ACTIVE} && $ENV{HARNESS_ACTIVE};

            $data->{error} = $e;
        }
    }
    return $data;
}


### Subroutine : set_dhl_destination_code        ###
# usage        :                                  #
# description  :  write the DHL 3 letter destination code to shipment table     #
# parameters   :   shipment_id,  destination_code                              #
# returns      :                                 #

sub set_dhl_destination_code :Export() {

    my ( $dbh, $shipment_id, $destination_code ) = @_;

    $destination_code = "" unless $destination_code;

    my $qry = "update shipment set destination_code = ? where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($destination_code, $shipment_id);

}


### Subroutine : get_routing_request_log          ###
# usage        :                                  #
# description  :   returns error log entries for routing requests on a shipment                               #
# parameters   :                                  #
# returns      :                                  #

sub get_routing_request_log :Export() {

    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT id, to_char(date, 'YYMMDDHH24MI') as datesort, to_char(date, 'DD-MM-YY HH24:MI') as date, error_code, error_message
               FROM routing_request_log
               WHERE shipment_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %log;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $log{ $$row{datesort}.$$row{id} } = $row;
    }

    return \%log;
}

1;
