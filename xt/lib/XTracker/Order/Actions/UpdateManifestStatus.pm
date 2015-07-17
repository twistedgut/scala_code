package XTracker::Order::Actions::UpdateManifestStatus;

use strict;
use warnings;

use Try::Tiny;
use XTracker::Database;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Database::Address;
use XTracker::Handler;
use XTracker::DHL::Manifest qw( update_manifest_status get_manifest_shipment_list create_transaction_lock_on_manifest );
use XTracker::Config::Local qw( contact_telephone );
use XTracker::Error qw(xt_warn xt_success);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema  = $handler->schema;
    my $dbh     = $schema->storage->dbh;

    my $operator_id = $handler->operator_id;

    my $params = $handler->{param_of};
    my $manifest_id = $params->{manifest_id};

    eval {
        my $status      = $params->{status};

        my $guard = $schema->txn_scope_guard;

        # Create a lock on the Manifest
        create_transaction_lock_on_manifest( $dbh, $manifest_id );

        # flag to track any errors in dispatching shipments
        my @shipment_errors;

        # extra step for manifest completion - dispatch all shipments in manifest
        if ($status eq "Complete") {

            # get all shipments from manifest
            my $shipments = get_manifest_shipment_list( $dbh, $manifest_id );

            # We need a separate schema so once a shipment is marked as
            # dispatched an error later in the transaction doesn't roll this
            # back
            my $separate_schema = XTracker::Database->xtracker_schema_no_singleton;

            # loop through and dispatch them all
            foreach my $shipment_id ( keys %{ $shipments } ) {
                next unless $shipments->{$shipment_id}{status} eq "Processing";

                # get data we need to dispatch shipment
                my $data;

                $data->{shipment_info}      = get_shipment_info( $dbh, $shipment_id );
                $data->{shipment_items}     = get_shipment_item_info( $dbh, $shipment_id );
                $data->{shipment_boxes}     = get_shipment_boxes( $dbh, $shipment_id );
                $data->{order_id}           = get_shipment_order_id($dbh, $shipment_id);
                $data->{order_info}         = get_order_info($dbh, $data->{order_id});
                $data->{channel}            = get_channel_details($dbh, $data->{order_info}{sales_channel});
                $data->{invoice_address}    = get_address_info($schema, $data->{order_info}{invoice_address_id});
                $data->{contact_telephone}  = contact_telephone( $data->{channel}{config_section} );

                eval {

                    # quick check for outbound AWB set before dispatching
                    if ( $data->{shipment_info}{outward_airway_bill} eq 'none' ) {
                        die 'no outbound AWB';
                    }
                    $separate_schema->txn_do(sub{
                        dispatch_shipment($separate_schema, $data, $operator_id);
                    });
                };
                if ( my $err = $@ ) {
                    push @shipment_errors, "Shipment Id: ${shipment_id} - $err";
                    next;
                }
                try {
                    my $row = $schema->resultset('Public::Shipment')->find($shipment_id);
                    $handler->msg_factory->transform_and_send(
                        'XT::DC::Messaging::Producer::Orders::Update',
                        { order_id => $row->order->id }
                    );
                } catch {
                    xt_warn( $_ );
                };
            }
            if ( @shipment_errors ) {
                die join q{<br />},
                    'Unable to complete manifest due to problems dispatching the following shipments:',
                    @shipment_errors;
            }
        }

        # update manifest status
        update_manifest_status($dbh, $manifest_id, $status, $operator_id);

        $guard->commit();
        xt_success("Manifest status updated to $status");
    };
    if ($@) {
        #DBD::Pg::st execute failed: ERROR: could not obtain lock on row in relation "manifest"
        #Can one guarantee that this error message will always be the same throughout Pg versions ?!

        my $error_msg;
        if ( $@ =~ /execute/ && $@ =~ /lock/ && $@ =~ /manifest/ ) {
            $error_msg = "There already seems to be a manifest being completed at this very moment.";
        }
        else {
            $error_msg = $@;
            $error_msg =~ s/at \/opt\/.*//gi;
        }
        xt_warn($error_msg);
    }
    return $handler->redirect_to( "/Fulfilment/Manifest?mid=$manifest_id" );
}

1;
