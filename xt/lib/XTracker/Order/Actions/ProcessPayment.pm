package XTracker::Order::Actions::ProcessPayment;
use NAP::policy "tt";

use Data::Dump qw(pp);
use POSIX;
use List::MoreUtils qw(all uniq);

use Plack::App::FakeApache1::Constants qw(:common);
use XT::Domain::Payment;
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Container qw( :validation );
use XTracker::Database::Order qw( :DEFAULT );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Database::Shipment qw( :DEFAULT );
use XTracker::Database::Invoice;
use XTracker::Comms::FCP qw( update_web_order_status );
use XTracker::EmailFunctions;
use XTracker::Database::OrderPayment qw( process_payment );
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Error;
use XT::Domain::Payment;

use XTracker::Vertex qw( :ALL );
use XTracker::Constants qw[ :application ];
use XTracker::Constants::FromDB qw[
    :note_type
    :packing_exception_action
    :shipment_class
    :shipment_item_status
];

use NAP::DC::Barcode::Container;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $packing_printer = $handler->{param_of}{packing_printer} || "";

    my $shipment_id = $handler->{param_of}{shipment_id} || '';
    $shipment_id =~ s{\s+}{}g;
    # if no form data or no shipment id defined send user back to Packing screen
    if ( !defined $handler->{request}->method || !$shipment_id) {
        return $handler->redirect_to(
            "/Fulfilment/Packing"
        );
    }


    # get and validate (if passed) container ID(s)
    my $container_id = $handler->{param_of}{container_id};
    if ($container_id) {
        my $err;
        try {
            # handle case when $container_id holds ARRAY ref
            if ('ARRAY' eq ref $container_id) {
                $container_id = [
                    map {NAP::DC::Barcode::Container->new_from_id($_)}
                    @$container_id
                ];
            } else {
                $container_id = NAP::DC::Barcode::Container->new_from_id($container_id);
            }
            $err = 0;
        } catch {
            xt_warn('Failed to validate passed Container ID: ' . $_);
            $err = 1;
        };
        return $handler->redirect_to('/Fulfilment/Packing') if $err;
    }


    # set up some vars we'll need at the end of process
    my $order_nr;
    my $web_channel;
    my $dbh     = $handler->dbh;
    my $schema  = $handler->schema;

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);
    if ($shipment->has_packing_started) {
        xt_warn('QC has already been submitted, please see supervisor to resolve');
        return $handler->redirect_to(
            "/Fulfilment/Packing/PackShipment".
            "?shipment_id=".$shipment_id.
            "&packing_printer=".$packing_printer
        );
    }
    my %shipment_items_by_id = map { $_->id => $_ } $shipment->shipment_items;


    # begin transaction
    $schema->txn_begin();

    # Mark all containers in this shipment as not being in pack lane now that packing has started
    $shipment->shipment_items->mark_containers_out_of_pack_lane;

    my $channel = $shipment->link_orders__shipments->first->orders->channel;

    my $item_info = get_shipment_item_info( $dbh, $shipment_id );
    my $extra_item_info  = $shipment->picking_print_docs_info();
    unless ($shipment->has_gift_messages() && $shipment->can_automate_gift_message()) {
        # we weren't expecting the GiftMessage to come back
        delete($extra_item_info->{'GiftMessage'});
    }

    my $failures = 0;my $passed = 0;my $reasons=0;my $expected=0;my $failed_present=0;

    my $auto_rescan;

    # Let's first validate that what we're getting through the form matches the order.
    # e.g. (nothing was cancelled or size switched)

    # Get from the DB the items that we're supposed to be showing in the page that submitted into this one.
    # Make sure there's no virtual vouchers in there.
    my @items_from_db = ();
    foreach my $si_id (sort keys %$item_info) {
        next if ( defined $item_info->{$si_id}->{voucher}
                  && $item_info->{$si_id}->{voucher} == 1
                  && ! $item_info->{$si_id}->{is_physical});

        push @items_from_db,$si_id
            if $item_info->{ $si_id }{shipment_item_status_id} eq $SHIPMENT_ITEM_STATUS__PICKED;
    }

    # Get the items that were submitted as QC_OK
    my @items_from_form = sort map { m/shipment_item_qc_(\d+)/ && $1 || () }
                           grep { !/_reason/ } keys %{$handler->{param_of}};
    $auto_rescan = 1 unless join("\0",@items_from_db) eq join("\0",@items_from_form);

    # Get extra items from form and check against what we expect
    my @extra_items_from_form = sort map { m/shipment_extra_item_qc_(\w+)/ && $1 || () }
                                 grep { !/_reason/ } keys %{$handler->{param_of}};

    # %$extra_item_info is a dictionary containing just 'GiftMessage' as an entry. however
    # there may be multiple gift messages so we need to make sure $auto_rescan doesn't trigger
    # when it shouldn't do by reducing all the gift message entries in @extra_items_from_form down
    # to just one entry for a GiftMessage.
    @extra_items_from_form = uniq map { s/GiftMessage_(\d+)/GiftMessage/r } @extra_items_from_form;

    $auto_rescan = 1 unless join("\0", sort keys %$extra_item_info) eq join("\0", @extra_items_from_form);


    my $pack_status = $shipment->pack_status;
    if (   $pack_status->{notready}
        || $pack_status->{on_hold}
        || $pack_status->{cancelled}) {
        # can't really pack this shipment, which means it's changed from when we last looked at it. Re-scan.
        $auto_rescan = 1;
    }

    if ($auto_rescan) {
        xt_warn("This shipment has changed. Please restart process.");
        # re-scan tote id by preference
        my $id = $container_id || $shipment_id;
        $id = ('ARRAY' eq ref $id) ? $id : [ $id ];

        # rollback changes
        $schema->txn_rollback();

        return $handler->redirect_to(
            '/Fulfilment/Packing/CheckShipment'.
            '?'. join '&', map {"shipment_id=$_"} @$id
        );
    }

    for my $item_id (keys %$item_info) {
        if ( $item_info->{$item_id}{voucher} && !$item_info->{$item_id}{is_physical} ) {
            # virtual vouchers won't get checked
            next;
        }
        ++$expected if $item_info->{$item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__PICKED;

        my $qc_value = $handler->{param_of}{"shipment_item_qc_$item_id"};
        next unless defined $qc_value;

        if ($qc_value == 1) {
            ++$passed;
            next;
        }
        if (
            $qc_value == 0 || # Fail
            $qc_value == 2    # Missing
        ) {
            ++$failures;
            if ($handler->{param_of}{"shipment_item_qc_${item_id}_reason"}) {
                $handler->{param_of}{"shipment_item_qc_${item_id}_reason"} =~ s{\s+}{ }g;
                $handler->{param_of}{"shipment_item_qc_${item_id}_reason"} =~ s{^ | $}{}g;
            }

            my $item = $shipment_items_by_id{$item_id};
            my $packing_exception_action_id;
            # There is some previous validation (at least in javascript) such
            # that a '0' (failed) value here means the op has to have inputted
            # a reason
            if ($qc_value == 0) {
                ++$reasons;
                ++$failed_present;
                $packing_exception_action_id = $PACKING_EXCEPTION_ACTION__FAULTY;
                $item->update({
                    qc_failure_reason => $handler->{param_of}{"shipment_item_qc_${item_id}_reason"}
                });
            } elsif ( $qc_value == 2 ) {
                ++$reasons;
                $packing_exception_action_id = $PACKING_EXCEPTION_ACTION__MISSING;
                $item->update({
                    qc_failure_reason => "Marked as missing from ".$item->container_id
                });
                $item->unpick();
            }

            $item->update_status(
                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                $handler->{data}{operator_id},
                $packing_exception_action_id,
            );
        }
    }

    my $extra_item_state = {
        handler => $handler,
        shipment => $shipment,
        extra_item_info => $extra_item_info,
        passed => 0,
        failures => 0,
        reasons => 0
    };

    # same for shipment extra items
    for my $extra_item (sort keys %$extra_item_info){

        $extra_item_state->{'pick_doc_entry'} = $extra_item;
        $extra_item_state->{'input_name'} = $extra_item;

        if ($extra_item eq 'GiftMessage') {
            my $gms = $shipment->get_gift_messages();
            foreach my $gm (@$gms) {
                $expected++;

                if (defined($gm->shipment_item)) {
                    $extra_item_state->{'input_name'} = 'GiftMessage_' . $gm->shipment_item->id;
                };

                _check_extra_item_post_values($extra_item_state);

            }
        } else {
            $expected++;
            _check_extra_item_post_values($extra_item_state);
        }
    }

    $passed += $extra_item_state->{'passed'};
    $failures += $extra_item_state->{'failures'};
    $reasons += $extra_item_state->{'reasons'};

    eval {
        if ($failures+$passed != $expected) {
            die "Please mark each item as either OK or Fail\n";
        }
        if ($reasons < $failures) {
            die "Please provide a reason for each failed item. reasons : $reasons , failures : $failures  \n";
        }
    };
    if ($@) {
        xt_warn($@);
        $schema->txn_rollback();
        return $handler->redirect_to(
            "/Fulfilment/Packing/CheckShipment".
            "?shipment_id=".$shipment_id
        );
    }

    if ($failures) {
        my $message = sprintf("Please scan item(s) from shipment %d into new tote(s) and send to the packing exception desk", $shipment_id);
        if ($shipment->is_pigeonhole_only()) {
            $message = "Please return pigeon hole items to their original pigeon holes and take any labels and paperwork to the packing exception desk";
        } elsif ($shipment->containers->pigeonholes->count()) {
            $message = sprintf("Please return pigeon hole items to their original pigeon holes, scan other items from shipment %d into a new tote, place any labels into the tote and send the tote to packing exception", $shipment_id);
        }
        xt_warn($message) if $failed_present || $passed;
        $schema->txn_commit();

        # If we don't have any items physically available, just go straight to
        # rescan
        unless ( $failed_present || $passed ) {
            if ($shipment->shipment_class_id != $SHIPMENT_CLASS__RE_DASH_SHIPMENT) {
                # don't send for re-shipments because IWS doesn't know they exist
                $handler->msg_factory->transform_and_send(
                    'XT::DC::Messaging::Producer::WMS::ShipmentReject',
                    { shipment_id => $shipment_id }
                );
            }

            # set different user messages if current request has
            # container ID(s) which are "pigeon holes". Handle both cases:
            # $container_id is a ARRAY ref or just a single ID
            if ($container_id
                and (
                    (
                            ('ARRAY' eq ref $container_id)
                        and (all{$_->is_type('pigeon_hole')} @$container_id)
                    )
                    or $container_id->is_type('pigeon_hole')
                )
            ) {
                xt_success("Packing Exception has been informed that this item is missing. Please take any labels and paperwork related to this shipment to the packing exception desk.");
            } else {
                xt_info("The Packing Exception desk has been informed of this shipment");
            }
            # re-scan tote id by preference
            my $id = $container_id || $shipment_id;
            $id = ('ARRAY' eq ref $id) ? $id : [$id];

            return $handler->redirect_to(
                '/Fulfilment/Packing/CheckShipment'.
                '?auto=1&'. join '&', map{"shipment_id=$_"} @$id
            );
        }

        return $handler->redirect_to(
            '/Fulfilment/Packing/PlaceInPEtote'.
            '?shipment_id='.$shipment_id
        );
    }

    if ($shipment->has_packing_started) {
        xt_success('Packing resumed for this order');
        return $handler->redirect_to(
            "/Fulfilment/Packing/PackShipment".
            "?shipment_id=".$shipment_id.
            "&packing_printer=".$packing_printer
        );
    }

    # calculate and take payment for order
    eval {
        my $conf_section;
        # take the money
        ( $order_nr, $conf_section ) = process_payment( $schema, $handler->{param_of}{'shipment_id'} );

        # set web channel globals
        $web_channel    = 'Web_Live_'.$conf_section;

        $schema->txn_commit();
    };

    if ($@) {

        my $error = $@;
        xt_logger->error(qq{eval failed somewhere: $error});

        # rollback what's happened
        $schema->txn_rollback();

        # start a new transaction to create the note
        $schema->txn_begin();

        $shipment->create_related('shipment_notes',{
            operator_id => $handler->operator_id,
            note_type_id => $NOTE_TYPE__QUALITY_CONTROL,
            note => $error,
        });

        # redirect to Packing screen with error message for user
        xt_warn("Invalid payment.<br />Please scan the item(s) into new tote(s) and send to the packing exception desk");

        $schema->txn_commit();

        return $handler->redirect_to(
            '/Fulfilment/Packing/PlaceInPEtote'.
            '?shipment_id='.$shipment_id
        );
    }
    else {
        # new transaction for the next bit
        # using a transaction just in case people add more
        # stuff in the future, it's ready and waiting
        $schema->txn_begin();

        $shipment->update({has_packing_started => 1});

        # commiting here so as not to hold the transaction
        # open whilst talking to the Web Database
        $schema->txn_commit();

        # status update for non-fulfiment channels only
        if ($order_nr && !$channel->is_fulfilment_only){

            # TO-DO: Stop updating the Web-DB directly: CANDO-8464
            my $dbh_web = get_database_handle( { name => $web_channel, type => 'transaction' } );

            eval {
                update_web_order_status($dbh_web, { 'orders_id' => $order_nr, 'order_status' => "DISPATCH IN PROGRESS" } );
                $dbh_web->commit();
            };

            if ($@) {
                xt_logger->warn(qq{update_web_order_status: $@});
                $dbh_web->rollback();
            }

            $dbh_web->disconnect();
        }

        # redirect to Pack Shipment to continue packing process
        return $handler->redirect_to(
            "/Fulfilment/Packing/PackShipment?".
            "shipment_id=".$shipment_id.
            "&packing_printer=".($packing_printer||'')
        );
    }

    # we should never get this far
    return DECLINED;
}

sub _check_extra_item_post_values {
    my $arg = shift;

    my $handler = $arg->{'handler'};
    my $pick_doc_entry = $arg->{'pick_doc_entry'};
    my $input_name = $arg->{'input_name'};
    my $shipment = $arg->{'shipment'};
    my $extra_item_info = $arg->{'extra_item_info'};

    next unless exists $handler->{param_of}{"shipment_extra_item_qc_$input_name"};
    next unless defined $handler->{param_of}{"shipment_extra_item_qc_$input_name"};
    if ($handler->{param_of}{"shipment_extra_item_qc_$input_name"} == 1) {
        $arg->{passed}++;
    }
    elsif (
        $handler->{param_of}{"shipment_extra_item_qc_$input_name"} == 0 ||
        $handler->{param_of}{"shipment_extra_item_qc_$input_name"} == 2
    ) {
        $arg->{failures}++;

        # Force a sensible item failure message if it was missing
        $handler->{param_of}{"shipment_extra_item_qc_${input_name}_reason"} =
            "Marked as missing" if $handler->{param_of}{"shipment_extra_item_qc_$input_name"} == 2;

        if ($handler->{param_of}{"shipment_extra_item_qc_${input_name}_reason"}) {
            $arg->{reasons}++;

            # Clean the reason up
            $handler->{param_of}{"shipment_extra_item_qc_${input_name}_reason"} =~ s{\s+}{ }g;
            $handler->{param_of}{"shipment_extra_item_qc_${input_name}_reason"} =~ s{^ +| +$}{}g;

            # QC fail the relevant items
            $shipment->qc_fail_shipment_extra_item(
                $extra_item_info->{$pick_doc_entry}->{fullname},
                $handler->{param_of}{"shipment_extra_item_qc_${input_name}_reason"},
                $handler->operator_id
            );
        }
    }
}

=head1 NAME

XTracker::Order::Actions::ProcessPayment - payment processing

=head1 SYNOPSIS

  use XTracker::Order::Actions::ProcessPayment;

=head1 AUTHOR

Original author unknown, presumed to be:
Ben Galbraith C<< <ben.galbraith@net-a-porter.com> >>

Modifications and Vertex injection by:
Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut
