package XTracker::Stock::Actions::RTV::SetRTVShipment;

use strict;
use warnings;

use Hash::Util qw(lock_hash);

use XTracker::Handler;
use XTracker::Utilities qw(:edit :string);
use XTracker::Constants::FromDB qw(:rtv_shipment_status :rtv_shipment_detail_status);
use XTracker::Database::RTV     qw(:rma_request :rtv_shipment :rtv_document :validate update_rtv_status list_countries);
use XTracker::Error;
use XTracker::Config::Local 'config_var';

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $RTV_CONSTANTS_REF = {
        RTV_SHIP_STAT_AWAITING_DISPATCH => $RTV_SHIPMENT_STATUS__AWAITING_DISPATCH,
        RTV_SHIP_STAT_DISPATCHED        => $RTV_SHIPMENT_STATUS__DISPATCHED,
        RTV_SHIP_DET_STAT_DISPATCHED    => $RTV_SHIPMENT_DETAIL_STATUS__DISPATCHED,
        RTV_SHIP_STAT_HOLD              => $RTV_SHIPMENT_STATUS__HOLD,
    };
    lock_hash(%$RTV_CONSTANTS_REF);


    my $airway_bill     = defined $handler->{param_of}{txt_airwaybill}   ? $handler->{param_of}{txt_airwaybill}   : '';
    my $rtv_shipment_id = defined $handler->{param_of}{rtv_shipment_id}  ? $handler->{param_of}{rtv_shipment_id}  : '';

    my $redirect_url    = '/RTV/ListRTV?' . ($rtv_shipment_id eq '' ? '' : "rtv_shipment_id=$rtv_shipment_id");

    eval {

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        # Airwaybill entered
        if ( $handler->{param_of}{'submit_airwaybill'} ) {

            if ($airway_bill !~ m{\A\s*\z}xms && $rtv_shipment_id ne '') {

                ## update rtv_shipment airway_bill
                update_rtv_shipment({
                    dbh             => $dbh,
                    rtv_shipment_id => $rtv_shipment_id,
                    fields_ref      => { airway_bill => $airway_bill },
                });


                ## Update rtv_shipment and rtv_shipment_detail statuses
                update_rtv_shipment_statuses({
                    dbh                         => $dbh,
                    rtv_shipment_id             => $rtv_shipment_id,
                    rtv_shipment_status         => $RTV_CONSTANTS_REF->{RTV_SHIP_STAT_DISPATCHED},
                    rtv_shipment_detail_status  => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_STAT_DISPATCHED},
                    operator_id                 => $handler->{data}{operator_id},
                });

            }
            else {
                die 'Invalid Airwaybill entered, please check and try again.';
            } ## END if

            xt_success("AWB added successfully.");
        }
        # print picking list
        elsif ( $handler->{param_of}{'submit_print_rtv_picklist'} && $rtv_shipment_id ne '' ) {

            ## create picklist
            my $doc_name
                = create_rtv_shipment_picklist({
                    dbh             => $dbh,
                    rtv_shipment_id => $rtv_shipment_id,
                });

            # print picklist
            my $rtv_shipment = $schema->resultset('Public::RTVShipment')->find({ id => $rtv_shipment_id });
            my $config_section = $rtv_shipment->channel->config_name;
            my $printer_name = config_var('SetRTVChannelPrinterName', $config_section);
            print_rtv_document( { document => $doc_name, printer_name => $printer_name } );

            xt_success("Picking List printed successfully.");

        }

        $guard->commit();
    };

    if ($@) {
        xt_warn("An error occured:<br />$@");
    }

    return $handler->redirect_to( $redirect_url );
}

1;
