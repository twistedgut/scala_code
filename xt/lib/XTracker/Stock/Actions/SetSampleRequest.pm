package XTracker::Stock::Actions::SetSampleRequest;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Stock;
use XTracker::Database::Product                 qw( product_present );
use XTracker::Database::StockTransfer;
use XTracker::Database::Channel                 qw( get_channels get_web_channels );
use XTracker::Comms::FCP                        qw( update_web_stock_level );
use XTracker::Constants::FromDB                 qw(
    :pws_action
    :shipment_class
    :shipment_status
    :shipment_type
    :stock_transfer_status
);
use XTracker::Utilities                         qw( url_encode );
use XTracker::Config::Local                     qw( config_var :Samples samples_email );
use XTracker::EmailFunctions;
use XTracker::Error;

sub handler {

    my $handler = XTracker::Handler->new(
            shift,
            { dbh_type => q{transaction} }
        );

    my $ret_params  = "";
    my %success_msg;

    if ($handler->{param_of}{"approval"}) {
        my $stock_managers;

        eval {

            my @approved_transfers;
            my $channels = get_web_channels($handler->{dbh});

            # We want to keep track of new shipments we've created, so we can
            # allocate them all at the end.
            my @shipment_ids;

            my $dbh     = $handler->dbh;
            my $schema  = $handler->schema;

            # Count approve and cancel actions
            my %sample_action;
            foreach my $item ( grep { /^(approve|cancel)-\d+$/ } keys %{ $handler->{param_of} } ) {

                my ($action, $st_id) = split /-/, $item;

                # get details of stock transfer...
                my $transfer_data = get_stock_transfer($dbh, $st_id);
                my $variant_id = $transfer_data->{variant_id};

                # ...and arrange them by variant
                $sample_action{$variant_id} ||= { approve => [], cancel => [] };
                push @{ $sample_action{$variant_id}{$action} }, $transfer_data;

                # get a connection to the appropriate Web DB
                # unless there already is a connection available
                my $channel_id  = $transfer_data->{channel_id};
                if ( !exists( $stock_managers->{ $channel_id } ) ) {
                    my $channel = $schema->resultset('Public::Channel')->find( $channel_id );
                    $stock_managers->{ $channel_id }    = $channel->stock_manager;
                }
            }

            # Now we have a list of approve and cancel actions for each variant, we
            # can tell if there's enough stock to fulfil requests

            # Look at each variant to be processed
            foreach my $variant_id ( keys %sample_action ) {
                # cancel any requests to be cancelled
                for my $cancel_request ( @{ $sample_action{$variant_id}{cancel} } ) {
                    _cancel_sample_request($dbh, $cancel_request->{id});
                    $success_msg{Cancelled} = 1;
                }

                # get total needed to approve requests
                my $total_needed = scalar @{ $sample_action{$variant_id}{approve} };

                # skip this variant if there aren't any approvals to do
                next unless $total_needed;

                # find how many are available
                my $variant = $schema->resultset('Public::Variant')->find($variant_id);
                my $saleable_quantity_details = $variant->product->get_saleable_item_quantity;
                my $sales_channel = $sample_action{$variant_id}{approve}[0]{sales_channel};
                my $available_units = $saleable_quantity_details->{$sales_channel}{$variant_id};

                # if there aren't enough available to fulfil the requests,
                # don't approve any for this variant
                if ($available_units < $total_needed) {
                    xt_warn 'Not enough stock available to approve the sample requests for SKU ' . $variant->sku
                        . ": Stock available = $available_units, stock requested = $total_needed.";
                    next;
                }

                # if the product doesn't have a storage_type, we know PRL allocation will fail
                if ($handler->prl_rollout_phase && !$variant->product->storage_type) {
                    xt_warn 'Product '.$variant->product_id.' does not have a storage type. Please ensure the storage type is set before creating a sample shipment.';
                    next;
                }

                # approve requests to be approved
                for my $approve_request ( @{ $sample_action{$variant_id}{approve} } ) {
                    my $shipment_id = _approve_sample_request($dbh, $stock_managers, $approve_request->{id}, $handler, $channels, $approve_request);
                    push @approved_transfers, $approve_request->{id};
                    push @shipment_ids, $shipment_id;
                    $success_msg{Approved} = 1;
                }
            }

            ### approval email
            if (@approved_transfers) {

                my $transfer_id_list= join ',', @approved_transfers;

                my $num_transfers   = @approved_transfers;

                my $email_subject   = "Sample Requests Accepted";
                my $email_msg       = "Sample Requests Accepted ($num_transfers):\n\n";

                my $qry =<<QRY
SELECT  product_id || '-' || sku_padding(size_id) as sku
FROM    variant
WHERE   id IN (
        SELECT  variant_id
        FROM    stock_transfer
        WHERE   id IN ($transfer_id_list)
    )
QRY
;
                my $sth = $handler->dbh->prepare($qry);
                $sth->execute();

                my $request_count = 0;

                while (my $row = $sth->fetchrow_arrayref()) {
                    $email_msg  .= $row->[0]."\n";
                    $request_count++;
                }

                send_email(
                    config_var('Email', 'xtracker_email'),
                    config_var('Email', 'xtracker_email'),
                    config_var('Email_'.$handler->{config_section}, 'sample_arrival_email'),
                    $email_subject,
                    $email_msg
                );

            }

            foreach ( values %{$stock_managers} ) {
                $_->commit();
            }

            $handler->dbh->commit(); # Implicitly begins another transaction


            # We allocate after doing everything else, one at a time,
            # to avoid a race condition where the allocate_response is
            # consumed before the allocation details are committed to
            # the database. This still doesn't strictly prevent it,
            # but it makes it much less likely. Proper fix would be
            # using Net::Stomp::Producer::Transactional - real soon
            # now!
            foreach my $shipment_id (@shipment_ids) {
                # Allocate the sample shipment
                $handler->schema->resultset('Public::Shipment')
                    ->find( $shipment_id )
                    ->allocate({
                        factory     => $handler->msg_factory,
                        operator_id => $handler->{data}{operator_id},
                    });

                $handler->dbh->commit(); # Implicitly begins another transaction
            }

        };

        if ( my $err = $@ ) {
            foreach ( values %{$stock_managers} ) {
                $_->rollback();
            }
            $handler->dbh->rollback();
                        xt_warn( $err );
        }
        else {
            my $msg     = "";

            foreach ( sort keys %success_msg ) {
                $msg    .= " / "        if ($msg);
                $msg    .= $_;
            }
                        xt_success("Pending Stock Requests $msg");
        }

        foreach ( values %{$stock_managers} ) {
            $_->disconnect();
        }
    }

    # redirect to Sample Summary
    my $loc = "/StockControl/Sample/Request";
    return $handler->redirect_to( $loc.$ret_params );
}


sub _approve_sample_request {

    my ($dbh, $stock_managers, $stock_transfer_id, $handler, $channels, $transfer_data)    = @_;

    my $channel         = $channels->{ $transfer_data->{channel_id} };

    # get config section for channel to use when sending emails later
    $handler->{config_section}  = $channel->{config_section};

    set_stock_transfer_status($dbh, $stock_transfer_id, $STOCK_TRANSFER_STATUS__APPROVED);

    my ($sec,  $min,  $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $mon++;
    $year       = $year + 1900;
    my $date    = $year . "-" . $mon . "-" . $mday . " " . $hour . ":" . $min;

    my @samples_address = samples_addr();
    my $samples_tel     = samples_tel();
    my $samples_email   = samples_email( $channel->{config_section} );

    my %address = (
        first_name      => "Sample",
        last_name       => "Sample",
        address_line_1  => $channel->{business},
        address_line_2  => "Sample",
        address_line_3  => "Sample",
        towncity        => "Sample",
        county          => "",
        country         => $samples_address[3],
        postcode        => "SA MPLE"
    );

    my %new_shipment = (
        date                 => $date,
        type_id              => $SHIPMENT_TYPE__PREMIER,
        class_id             => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
        status_id            => $SHIPMENT_STATUS__PROCESSING,
        address_id           => '',
        gift                 => "false",
        gift_message         => '',
        email                => $samples_email,
        telephone            => $samples_tel,
        mobile_telephone     => '',
        pack_instruction     => 'Sample Shipment - No extra packaging',
        shipping_charge      => 0,
        comment              => "",
        force_manual_booking => 1,
        address              => \%address,
    );

    my $new_shipment_id = create_shipment($dbh, $stock_transfer_id, "transfer", \%new_shipment);

    my %new_shipment_item = (
        variant_id      => $$transfer_data{variant_id},
        unit_price      => 0,
        tax             => 0,
        duty            => 0,
        status_id       => 1,
        special_order   => "false"
    );

    create_shipment_item($dbh, $new_shipment_id, \%new_shipment_item);

    $stock_managers->{$transfer_data->{channel_id}}->stock_update(
        quantity_change => -1,
        variant_id      => $transfer_data->{variant_id},
        skip_non_live   => 1,
        pws_action_id   => $PWS_ACTION__SAMPLE,
        operator_id     => $handler->operator_id(),
        notes           => "T:::: to sample stock -1",
    );

    return $new_shipment_id;
}


sub _cancel_sample_request {

    my ($dbh, $stock_transfer_id) = @_;

    set_stock_transfer_status($dbh, $stock_transfer_id, $STOCK_TRANSFER_STATUS__CANCELLED);
}

1;

__END__
