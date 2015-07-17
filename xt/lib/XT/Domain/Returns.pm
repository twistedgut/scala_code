package XT::Domain::Returns;
use strict;
use warnings;
use Data::Dump qw/pp/;
use namespace::autoclean;
use Moose;
use MooseX::Types::Moose qw( Bool );
use Carp qw(confess croak cluck);
use Try::Tiny;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment qw(
    :DEFAULT
    create_returns_shipment
);
use XTracker::Database::Reservation qw(get_reservation_details cancel_reservation);
use XTracker::Database::Return qw(
    :DEFAULT release_return_invoice_to_customer
    generate_RMA
);
use XTracker::Database::Invoice;
use XTracker::Database::Product;
use XTracker::Database::Stock   qw( get_saleable_item_quantity get_cust_reservation_variants );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Order::Printing::PremierReturnNote;
use XTracker::Constants::FromDB qw(
    :shipment_class
    :shipment_status
    :shipment_type
    :shipment_item_status
    :customer_issue_type
    :pws_action
    :return_status
    :return_type
    :return_item_status
    :renumeration_type
    :renumeration_status
    :renumeration_class
    :return_item_status
    :correspondence_templates
);
use XTracker::Config::Local qw( config_var arma_can_accept_exchange_charges );
use XTracker::Utilities 'number_in_list';
use XTracker::WebContent::StockManagement;
use DateTime;
require Catalyst::Utils;
with 'XTracker::Role::WithAMQMessageFactory';

has schema => (
    isa => 'XTracker::Schema',
    required => 1,
    is => 'ro',
    handles => [qw|resultset|]
);

has order => (
    isa => 'XTracker::Schema::Result::Public::Orders',
    is => 'rw',
);

# CANDO-180:
# because of the rollback hack in 'XTracker::Order::Functions::Return::Create'
# this flag is used to indicate whether we need to update web-site stock levels
# or not and also other stuff that isn't necessary when the hack is being used
has called_in_preview_create_mode => (
    is => 'rw',
    isa => Bool,
    required => 0,
    default => 0,
);

# CANDO-141:
# this flag will be set when the Return is being instantiated by ActiveMQ in the 'model'
# and therefor being called by the ARMA (Automated RMA) Process
has requested_from_arma => (
    isa => Bool,
    is => 'rw',
    required => 1,
    default => 0,
);

sub dbh { $_[0]->schema->storage->dbh; }

with 'XT::Domain::Returns::Email';
with 'XT::Domain::Returns::Calc';

=head1 NAME

XT::Domain::Returns - model for creating Return/RMAs

=head1 REFACTOR NOTICE

TODO: Eventually all of this could do with moving to DBIC, but I dont have time
right now (as part of DCS-757) to do it. Just be glad all this code is in one
file, not 3+.

=head1 METHODS

=head2 create

 $return = $handler->domain('Returns')->create($data);

Create a return, returning the L<XTracker::Schema::Result::Public::Return>
object. C<$data> is a hash that should match the following type

  Dict[
    shipment_id => Int,
    operator_id => Int,
    refund_type_id => Optional[Int], # $RENUMERATION_TYPE__xxx
    shipping_charge => Num,  # if a refund_type_id
    shipping_refund => Bool, # if a refund_type_id


    pickup => Bool, # Convert Premier pickup option

    rma_number => Str, # Currently required, should perhaps be optional and
                         generated if not passed

    return_items => Dict[
      # Keys are the shipment_item ids
      slurpy Dict[
        type => Enum['Exchange', 'Return'],
        reason_id => Int,

        # required if type eq 'Exchange'. Is a variant.id
        exchange_variant => Int,
      ]
    ],
    alt_customer_nr => Optional[Str],

    # Return notes if needed
    notes => Optional[ArrayRef[Str]]

    send_email => Optional[Bool],
    # If send_email_true
    email_from => Str,
    email_replyto => Str,
    email_to => Str,
    email_subject => Str,
    email_body => Str,
    # End if

  ]

=cut

sub _throw_error {
    my ($self, $message) = @_;
    cluck $message; # stack trace for the logs - we should monitor these and fix
    die $message; # short message for the user - displayed on XTracker page
}

sub create {
    my ($self, $data) = @_;

    # CANDO-180: set the flag for the hack to not update Web-Stock and other things
    my $called_in_preview_create_mode = delete $data->{called_in_preview_create_mode};
    if ( defined $called_in_preview_create_mode && $called_in_preview_create_mode == 1 ) {
        $self->called_in_preview_create_mode( 1 );
    }

    $self->_setup_shipment_info($data->{shipment_id}, $data);
    # create return and return item records
    my $error_message = "ERROR: Couldn't create return from:\n[".join(", ", map { $_."=".($data->{$_}//q{<undef>}) } keys %$data)."]";
    try {
        $data->{return} = $self->_create_return( $data )
            or die "_create_return did not return anything";
    } catch {
        if (ref($_) eq 'DBIx::Class::Exception') {
            if (/value violates unique constraint "return__rma_number_unique"/) {
                 $self->_throw_error("$error_message\n...Prevented from creating a duplicate return (WHM-3522).");
            }
            else {
                 $self->_throw_error("$error_message\n...due to unexpected database exception: "
                     .ref($_)."\nMore details:\n".$_);
            }
        }
        else {
             $self->_throw_error("$error_message\n...due to unknown exception: "
                 .ref($_)."\nMore details:\n".$_);
        }
    };

    $self->_store_renumeration($data);

    # extra steps for exchanges only
    $self->_create_exchange_shipment( $data ) if $data->{create_exchange} == 1;

    # CANDO-180: if this is using the hack from create returns then don't proceed and just return now
    return $data->{return}      if ( $self->called_in_preview_create_mode );

    # extra step for Premier orders only to generate return document
    # APS-93 - they don't want it for samples though
    if ( $data->{shipment_info}{shipment_type_id} == $SHIPMENT_TYPE__PREMIER
                                            && !$data->{this_is_a_sample_return}) {

        # Pass a printer name to function only if premier docs required.
        my $printer = (config_var('Print_Document', 'requires_premier_nonpacking_printouts')) ? 'Premier Collection Note' : '';
        generate_premier_return_note( $self->dbh, $data->{return}->id, $printer, 2 );
    }

    # send customer email & log it
    my $email_type = $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE;
    $self->_build_return_email($data, $email_type) if $data->{send_default_email};
    $self->_send_email($data, $email_type) if $data->{send_email};

    # Send the status update message to the Website if its a standard shipment
    # I.e. not for sample returns (which get created as RMAs)
    $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::Orders::Update',{order_id => $data->{return}->shipment->order->id})
        if (!$data->{this_is_a_sample_return}
                && $data->{return}->shipment->is_standard_class);

    if ( $data->{return}->shipment->get_channel->business->fulfilment_only ) {
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Return::RequestSuccess',
            {
                return => $data->{return},
                return_request_date => $data->{return_request_date} // '',
            }
        );
    }

    return $data->{return};
}

sub lost_shipment {
    my ($self, $data) = @_;

    $self->_setup_shipment_info($data->{shipment_id}, $data);
    # create return and return item records
    # $data->{return} = $self->_create_return( $data )
    #    or
    #  die "couldn't create return from:\n".pp($data);

    $self->_store_renumeration($data);
}

# get renumeration split and store renumeration
sub _store_renumeration {
    my ($self, $data) = @_;

    my $split = $self->get_renumeration_split($data);

    # For exchanges we frequently don't need a refund/charge
    unless (@$split) {
        $data->{refund_type_id} = 0;
        return;
    }

    $data->{return}->discard_changes unless $data->{is_lost_shipment};

    $data->{refund_type_id} = $split->[0]{renumeration_type_id};

    for my $renum (@$split) {
        $renum->{currency_id} = $data->{shipment}->order->currency_id;

        my $items = delete $renum->{renumeration_items};

        if ( $renum->{renumeration_type_id} == $RENUMERATION_TYPE__STORE_CREDIT && $data->{alt_customer_nr} ) {
            $renum->{alt_customer_nr}   = $data->{alt_customer_nr};
        }

        my $renumeration;
        $renum->{invoice_nr} = '';

        # if its lost link to shipment rather than return.
        if ($data->{is_lost_shipment}) {
            $renum->{renumeration_class_id} = $RENUMERATION_CLASS__CANCELLATION;
            $renum->{renumeration_status_id} = $RENUMERATION_STATUS__AWAITING_ACTION;

            $renumeration = $data->{shipment}->add_to_renumerations($renum);
        }
        else {
            # EN-2036: Got rid of using 'add_to_renumerations' because it wasn't working properly
            #          and assigning renumerations to a previous return instead of the new one
            $renumeration   = $self->schema->resultset('Public::Renumeration')->create( $renum );
            $data->{return}->create_related( 'link_return_renumeration', { renumeration_id => $renumeration->id } );
        }

        log_invoice_status( $self->dbh, $renumeration->id,
                $renum->{renumeration_status_id}, $data->{operator_id} );

        for my $i (@$items) {
            $renumeration->add_to_renumeration_items({
                map {
                    $_ => $i->{$_}
                } qw/tax duty unit_price shipment_item_id/,
            })
        }
    }
}

=head2 cancel

 $return_id = $handler->domain('Returns')->cancel($data);

Cancels the RMA. C<$data> is a hash that should match the
following type:

  Dict[
    return_id => Int,
    operator_id => Int,

    send_email => Optional[Bool],
    # If send_email_true
    email_from => Str,
    email_replyto => Str,
    email_to => Str,
    email_subject => Str,
    email_body => Str,
    # End if

  ]

=cut

sub cancel {
    my ($self, $data) = @_;

    my $return_id = $data->{return_id};
    my $return = $self->schema->resultset('Public::Return')->find($return_id)
      or croak "Return $return_id could not be found!";

    my $stock_manager = $data->{stock_manager} || croak 'You have to pass a stock_manager';

    $self->_setup_shipment_info($return->shipment_id, $data);

    # update return status & log
    $return->update({return_status_id => $RETURN_STATUS__CANCELLED});
    log_return_status( $self->dbh, $data->{return_id}, $RETURN_STATUS__CANCELLED, $data->{operator_id} );

    # update item statuses and log
    foreach my $ret_item ( $return->return_items->all) {
        next unless $ret_item->is_awaiting_return;

        $ret_item->update({return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED} );
        # TODO: These log_*_status so want to use the audit log component that Alex wrote.
        log_return_item_status( $self->dbh, $ret_item->id, $RETURN_ITEM_STATUS__CANCELLED, $data->{operator_id} );

        # update shipment item status & log
        $ret_item->shipment_item->update({
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED }
        );
        log_shipment_item_status($self->dbh, $ret_item->shipment_item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED, $data->{operator_id} );
    }

    # cancel exchanges - if present
    my $exch_shipment = $return->exchange_shipment;
    $exch_shipment->cancel(
        operator_id => $data->{operator_id},
        customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__CANCELLED_EXCHANGE,
        notes => 'Exchanged, exchange_shipment_id: ' . $exch_shipment->id,
        stock_manager => $stock_manager,
    ) if $exch_shipment;

    # cancel invoices - if present
    my $invoice = get_return_invoice( $self->dbh, $data->{return_id} );

    foreach my $inv_id ( keys %$invoice ) {
        if ( number_in_list( $invoice->{$inv_id}{renumeration_status_id},
                                $RENUMERATION_STATUS__PENDING,
                                $RENUMERATION_STATUS__AWAITING_AUTHORISATION,
                                $RENUMERATION_STATUS__AWAITING_ACTION,
                            ) ) {
            update_invoice_status( $self->dbh, $inv_id, $RENUMERATION_STATUS__CANCELLED );
            log_invoice_status( $self->dbh, $inv_id, $RENUMERATION_STATUS__CANCELLED, $data->{operator_id} );
        }
    }

    set_return_note( $self->dbh, $return_id, $data->{notes}, $data->{operator_id} )
        if ( $data->{notes} );

    my $email_type = $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN;

    $self->_build_return_email($data, $email_type) if ($data->{send_default_email});

    # send customer email & log it
    $self->_send_email($data, $email_type) if $data->{send_email};

    $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::Orders::Update',
        { order_id => $return->shipment->order->id }
    );
}

=head2 add_items

 $return_id = $handler->domain('Returns')->add_items($data);

Add items to an existing return. C<$data> is a hash that should match the
following type

  Dict[
    return_id => Int,.
    shipment_id => Int,
    operator_id => Int,
    refund_type_id => Optional[Int], # $RENUMERATION_TYPE__xxx

    return_items => Dict[
      # Keys are the shipment_item ids
      slurpy Dict[
        type => Enum['Exchange', 'Return'],
        reason_id => Int,

        # required if type eq 'Exchange'. Is a variant.id
        exchange_variant => Int,
      ]
    ],
    alt_customer_nr => Optional[Str],

    # Return notes if needed
    notes => Optional[ArrayRef[Str]]


    send_email => Optional[Bool],
    # If send_email_true
    email_from => Str,
    email_replyto => Str,
    email_to => Str,
    email_subject => Str,
    email_body => Str,
    # End if

  ]

=cut

=head2 expand an existing return into a request

=cut

sub _return_to_request {
    my ($self, $data) = @_;

    my $req;
    $req->{shipment_id} = $data->{return}->shipment_id;

    for my $item ($data->{return}->return_items) {
       next if $item->return_item_status_id == $RETURN_ITEM_STATUS__CANCELLED;

        $req->{return_items}{$item->shipment_item_id} = {
            reason_id => $item->customer_issue_type_id,
            type => $item->type->type,
            shipment_item_id => $item->shipment_item_id,
        };
    }

    return $req;
}

sub add_items {
    my ($self, $data) = @_;

    $data->{return} = $self->resultset('Public::Return')->find($data->{return_id})
      or croak "Return $data->{return_id} could not be found!";

    my $request = $self->_return_to_request($data);

    # remove items from renumeration and update status
    $data->{return}->renumerations->cancel_for_returns( $data->{operator_id} );

    $self->_setup_shipment_info($data->{return}->shipment_id, $data);
    $self->_add_return_items( $data );

    {
        # For some reason if we don't do this _store_renumeration doesn't do
        # the right thing. Ash did this fix on a Saturday a week after he was
        # meant to leave and didn't have time to fix it properly. Sorry.
        my $data = Catalyst::Utils::merge_hashes($request, $data);
        $data->{pickup} ||= 0;
        $data->{create_exchange} = 0;

        $self->_setup_shipment_info($data->{return}->shipment_id, $data);

        # recreate renumeration
        $self->_store_renumeration($data);
    }

    $self->_update_or_create_exchange_shipment( $data )
        if $data->{create_exchange};

    set_return_note( $self->dbh, $data->{return_id}, $data->{notes}, $data->{operator_id} )
        if ( $data->{notes} );

    my $email_type = $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM;
    $self->_build_return_email($data, $email_type)
        if ($data->{send_default_email});

    # send customer email & log it
    $self->_send_email($data, $email_type) if $data->{send_email};

    # Send the status update message to the Website.
    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Orders::Update',
        { order_id       => $data->{return}->shipment->order->id }
    );
}

=head2 remove_items

 $return_id = $handler->domain('Returns')->remove_items($data);

Remove items from an existing return. Will handle all processing needed if the
removing items completes the return. C<$data> is a hash that should match the
following type:

  Dict[
    return_id => Int,.
    shipment_id => Int,
    operator_id => Int,
    refund_type_id => Optional[Int], # $RENUMERATION_TYPE__xxx

    return_items => Dict[
      # Keys are the return_item ids
      slurpy Dict[
        shipment_item_id => Int,
        remove => Optional[Bool],
      ]
    ],
    alt_customer_nr => Optional[Str],

    send_email => Optional[Bool],
    # If send_email_true
    email_from => Str,
    email_replyto => Str,
    email_to => Str,
    email_subject => Str,
    email_body => Str,
    # End if

  ]

=cut

sub remove_items {
    my ($self, $data) = @_;

    $data->{return} = $self->resultset('Public::Return')->find($data->{return_id})
      or croak "Return $data->{return_id} could not be found!";

    $self->_setup_shipment_info($data->{return}->shipment_id, $data);

    my $cancel_exchange = $self->_remove_return_items($data);
    $self->_cancel_exchange_items($data) if $cancel_exchange;

    # remove items from renumeration and update status
    $data->{return}->renumerations->cancel_for_returns( $data->{operator_id} );

    # remove old return items
    my @items = keys %{$data->{return_items}};
    delete $data->{return_items}{$_} for @items;

    my $request = $self->_return_to_request($data);
    $data = Catalyst::Utils::merge_hashes($request, $data);

    # re-create renumeration
    $self->_store_renumeration($data);

    ### check if removed item means Return is now complete! if so do stuff
    my ($complete, $exchange_complete) = check_return_complete($self->dbh,
        $data->{return_id});

    # release refund
    if ($complete == 1) {

        update_return_status($self->dbh, $data->{return_id}, $RETURN_STATUS__COMPLETE);

        #update logs
        log_return_status( $self->dbh, $data->{return_id}, $RETURN_STATUS__COMPLETE, $data->{operator_id});
    }

    # release any pending invoices. This does it CONDITIONALLY. Badly named method
    release_return_invoice_to_customer( $self->schema, $self->msg_factory, $data->{return_id}, $data->{operator_id} );

    # got an exchange and its ready for release
    if ( $exchange_complete == 1 && $data->{return}->exchange_shipment ) {
        $data->{return}->exchange_shipment->discard_changes;

        # shipment on hold - release it
        if ( $data->{return}->exchange_shipment->is_on_return_hold ) {
            update_shipment_status($self->dbh, $data->{return}->exchange_shipment->id,
                $SHIPMENT_STATUS__PROCESSING, $data->{operator_id});
        }
    }

    set_return_note( $self->dbh, $data->{return_id}, $data->{notes}, $data->{operator_id} )
        if ( $data->{notes} );

    my $email_type = $CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM;
    $self->_build_return_email($data, $email_type)
        if ($data->{send_default_email});
    $self->_send_email($data, $email_type)
        if $data->{send_email};

    # Send the status update message to the Website.
    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Orders::Update',
        { order_id       => $data->{return}->shipment->order->id }
    );

    # Return indication of whether any items removed were exchange items.
    # Most callers need this to determine whether to send messages
    # to IWS.
    return $cancel_exchange;
}

sub convert_items {
    my ($self, $data) = @_;

    $data->{return} = $self->resultset('Public::Return')->find($data->{return_id})
      or croak "Return with id $data->{return_id} could not be found!";

    my $request = $self->_return_to_request($data);

    # remove items from renumeration and update status
    $data->{return}->renumerations->cancel_for_returns( $data->{operator_id} );

    $self->_setup_shipment_info($data->{return}->shipment_id, $data);

    my $cancel_exchange = $self->_remove_return_items($data);
    $self->_cancel_exchange_items($data) if $cancel_exchange;

    # Need to convert from keyed on return_item_id to shipment_item_id
    my $ris = $data->{return_items};
    $data->{return_items} = { map {

        # So that add_items doesn't think this item is still 'return pending'
        $data->{shipment_items}{ $ris->{$_}{shipment_item_id} }->discard_changes;

        # Convert to the other type.
        $ris->{$_}{type} = ($ris->{$_}{type} eq 'Exchange') ? 'Return' : 'Exchange';

        # The 'return' from the map
        $ris->{$_}{shipment_item_id} => $ris->{$_}
    } keys %$ris };

    $self->_add_return_items( $data );

    my $refund_type_id = 0;
    {
        # For some reason if we don't do this _store_renumeration doesn't do
        # the right thing. Ash did this fix on a Saturday a week after he was
        # meant to leave and didn't have time to fix it properly. Sorry.
        my $data = Catalyst::Utils::merge_hashes($request, $data);
        $data->{pickup} ||= 0;
        $data->{create_exchange} = 0;

        $self->_setup_shipment_info($data->{return}->shipment_id, $data);

        # recreate renumeration
        $self->_store_renumeration($data);
        $refund_type_id = $data->{refund_type_id};
    }

    $data->{refund_type_id} = $refund_type_id;
    $self->_update_or_create_exchange_shipment( $data )
        if $data->{create_exchange};

    my $email_type = delete $data->{email_template_id};
    $self->_build_return_email($data, $email_type)
        if ($data->{send_default_email});

    # send customer email & log it
    $self->_send_email($data, $email_type) if $data->{send_email};

    # Send the status update message to the Website.
    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Orders::Update',
        { order_id       => $data->{return}->shipment->order->id }
    );

    # Return indication of whether any items removed were exchange items.
    # Most callers need this to determine whether to send messages
    # to IWS.
    return $cancel_exchange;
}

sub manual_alteration {
    my ($self, $data)   = @_;

    $data->{return} = $self->resultset('Public::Return')->find($data->{return_id})
      or croak "Return with id $data->{return_id} could not be found!";

    my $cancel_exchange = $self->_remove_return_items($data);
    $self->_cancel_exchange_items($data) if $cancel_exchange;

    if ( $data->{num_convert_items} ) {
        # if there are items that need converting
        # then flip the Type of Return
        foreach my $retitem_id ( keys %{ $data->{return_items} } ) {
            my $item    = $data->{return_items}{ $retitem_id };

            # get rid of anything that does not need converting
            if ( !exists $item->{change} ) {
                delete $data->{return_items}{ $retitem_id };
                next;
            }

            # flip the type of Return
            $item->{type}   = ( $item->{type} eq 'Exchange' ? 'Return' : 'Exchange' );

            # delete the item keyed using 'return_item_id'
            # then add the item keyed using 'shipment_item_id'
            delete $data->{return_items}{ $retitem_id };
            $data->{return_items}{ $item->{shipment_item_id} }    = $item;
        }

        $self->_setup_shipment_info($data->{return}->shipment_id, $data);

        $self->_add_return_items( $data );
    }

    ### check if removed items means Return is now complete! if so do stuff
    my ($complete, $exchange_complete)  = check_return_complete( $self->dbh, $data->{return_id} );

    if ( $complete == 1 ) {
        # update Return
        update_return_status($self->dbh, $data->{return_id}, $RETURN_STATUS__COMPLETE);

        #update the logs
        log_return_status( $self->dbh, $data->{return_id}, $RETURN_STATUS__COMPLETE, $data->{operator_id} );
    }

    # got an exchange and its ready for release
    if ( $exchange_complete == 1 && $data->{return}->exchange_shipment ) {
        $data->{return}->exchange_shipment->discard_changes;

        # shipment on hold - release it
        if ( $data->{return}->exchange_shipment->shipment_status_id == $SHIPMENT_STATUS__RETURN_HOLD ) {
            $data->{return}->exchange_shipment->update_status($SHIPMENT_STATUS__PROCESSING, $data->{operator_id});
        }
    }

    # Send the status update message to the Website.
    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Orders::Update',
        { order_id => $data->{return}->shipment->order->id }
    );

    # Return indication of whether any items removed were exchange items.
    # Most callers need this to determine whether to send messages
    # to IWS.
    return $cancel_exchange;
}

sub _create_return {
    my ($self, $data) = @_;

    my $rma_number = $data->{rma_number} || generate_RMA($self->dbh, $data->{shipment_id});

    confess 'erk' if $data->{pickup} eq 'Anytime';

    my $now = DateTime->now;

    my $shipment = $data->{shipment} || $self->schema->resultset('Public::Shipment')
                                             ->find( $data->{shipment_id} );

    # We don't care about the expiry date for sample returns
    my $expiry = $data->{this_is_a_sample_return}
               ? $now->clone->add(days => 14)
               : $self->_default_return_expiry_date($shipment->order->channel, $now);

    # Don't allow the creation of a return for a sample shipment if one already exists (this is fine for other
    # types of shipment)
    my $is_duplicated_return = $self->schema->resultset('Public::Return')
        ->search( { shipment_id => $data->{shipment_id} } )
        ->not_cancelled
        ->count > 0;
    die sprintf('A return already exists for sample shipment %s', $data->{shipment_id})
        if ( $data->{this_is_a_sample_return} && $is_duplicated_return );

    my $return = $self->schema->resultset('Public::Return')->create({
        shipment_id => $data->{shipment_id},
        rma_number => $rma_number,
        return_status_id => $RETURN_STATUS__AWAITING_RETURN,
        comment => '',
        exchange_shipment_id => undef,
        pickup => $data->{pickup} || 0,
        creation_date => $now,
        expiry_date => $expiry,
        cancellation_date => $expiry->clone,
    });

    $data->{return} = $return;
    $data->{return_id} = $return->id;

    # return log entry
    log_return_status( $self->dbh, $return->id, $RETURN_STATUS__AWAITING_RETURN, $data->{operator_id} );

    # create return note entry if needed
    if ( $data->{notes} ){
        set_return_note( $self->dbh, $return->id, $data->{notes}, $data->{operator_id} );
    }

    # flag to keep track of exchange items
    # and work out if we need to create one
    $data->{create_exchange} = 0;

    # create return items
    $self->_add_return_items($data);

    return $return;
}

sub _add_return_items {
    my ($self, $data) = @_;

    my $return = $data->{return};
    my $return_id = $data->{return_id};
    my $shipment_id = $data->{shipment}->id;
    my $shipment_items = $data->{shipment_items};

    my $num = 0;
    foreach my $shipment_item_id ( keys %{ $data->{return_items} } ) {
        # clone item
        my $item = {%{$data->{return_items}{$shipment_item_id}}};

        my $shipment_item = $shipment_items->{$shipment_item_id}
            or croak "$shipment_item_id is not a shipment item of shipment $shipment_id";

        # final check on shipment item status
        # must be "Dispatched" to create a return on it
        # EN-1529: Unless it is converting an Exchange to a Return then
        #          it needs to preserve the existing status, the key {change}
        #          is set when Converting an Exchange to a Return
        if ( !$item->{change} && $shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__DISPATCHED ){
            die 'Item does not have the correct status to be returned, '
              . "shipitem_id: ". $shipment_item->id
              . ' '. $shipment_item->variant->sku
              . ': '
              . $shipment_item->shipment_item_status->status;
        }

        if ( $item->{type} eq 'Exchange' ){
            $item->{type} = $RETURN_TYPE__EXCHANGE;
            $data->{create_exchange}   = 1;
            $data->{num_exchange_items}++;
        }
        else {
            $item->{type} = $RETURN_TYPE__RETURN;
        }

        # if we DO NOT have a reason_id, let's know about it!
        # -- DCS-1109
        # at least we'll have more of an idea about the failure
        if (not defined $item->{reason_id}) {
            die   "Reason missing for shipment item $shipment_item_id. "
                . "Return: $return_id. "
                . "Item type: $item->{type}. "
            ;
        }

        $item->{return} = 1;

        # Gift Vouchers can't be returned, this is used
        # when an order with Gift Vouchers is being 'Dispatch/Returned'
        if ( $shipment_item->voucher_variant_id ) {
            # if Dispatch/Return then Cancel the Item
            if ( $data->{dispatch_return} ) {
                # set shipment item status and log
                update_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__CANCELLED );
                log_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__CANCELLED, $data->{operator_id} );
            }
            next;
        }

        # create return item entry
        my $ri = $return->return_items->create({
            shipment_item_id => $shipment_item_id,

            # EN-1529: if converting from Exchange to Return then the new return item needs
            #          to be set to the same status as the cancelled exchange return item was
            #          as the physical returned item hasn't changed state
            return_item_status_id => $item->{current_status_id} || $RETURN_ITEM_STATUS__AWAITING_RETURN,

            customer_issue_type_id => $item->{reason_id},
            return_type_id => $item->{type},

            # EN-1529: if converting from Exchange to Return then we already have an AWB so can set the
            #          new Return to have the same.
            return_airway_bill => ( defined $item->{current_return_awb} ? $item->{current_return_awb} : undef ),

            variant_id => $shipment_item->variant_id,
            creation_date => DateTime->now,
        });

        # log it
        log_return_item_status( $self->dbh, $ri->id, $ri->return_item_status_id, $data->{operator_id} );

        # EN-1529: When Converting an Exchange to a Return we shouldn't alter the status
        #          of the original Shipment Item as it hasn't altered, otherwise we can.
        #          The key {change} is is set when Converting an Exchange to a Return.
        if ( !$item->{change} ) {
            # set shipment item status and log
            update_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__RETURN_PENDING );
            log_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__RETURN_PENDING, $data->{operator_id} );
        }

        if ( $item->{change} ) {
            # EN-1529: Change an existing link on a delivery item to point to the new return item
            if ( exists( $item->{current_link_to_delivery} ) ) {
                my $delivery_item_id    = $item->{current_link_to_delivery}->delivery_item_id;
                $item->{current_link_to_delivery}->delete;
                $ri->create_related( 'link_delivery_item__return_items', {
                                delivery_item_id => $delivery_item_id,
                        } );
            }
        }

        $num++;
    }

    # Needed for email templates
    $data->{num_return_items} = $num;
}

sub _update_or_create_exchange_shipment {
    my ($self, $data) = @_;

    my $return = $data->{return};

    return $self->_update_exchange_shipment($data) if $return->exchange_shipment;

    return $self->_create_exchange_shipment($data);
}

sub _update_exchange_shipment {
    my ($self, $data) = @_;

    # if there's a debit pending set to 'Exchange Hold'
    my $shipment_status_id = $self->_new_exchange_shipment_status($data);

    my $exchange_shipment = $data->{return}->exchange_shipment;

    # if it's cancelled we need to update status
    if ( $exchange_shipment->shipment_status_id == $SHIPMENT_STATUS__CANCELLED ) {

        update_shipment_status(
            $self->dbh,
            $exchange_shipment->id,
            $shipment_status_id,
            $data->{operator_id}
        );
    }
    $self->_update_exchange_shipment_items($data, $exchange_shipment->id);
}

sub _new_exchange_shipment_status {
    my ($self, $data) = @_;
    # work out status of new shipment
    # default to 'Return Hold'

    croak "refund_type_id missing" unless
      exists $data->{refund_type_id};

    # if there's a debit pending set to 'Exchange Hold'
    return $data->{refund_type_id} == $RENUMERATION_TYPE__CARD_DEBIT
         ? $SHIPMENT_STATUS__EXCHANGE_HOLD
         : $SHIPMENT_STATUS__RETURN_HOLD;

}

sub _create_exchange_shipment {
    my ($self, $data) = @_;

    my $orig_shipment       = $data->{shipment}->order->get_standard_class_shipment;
    my $new_shipment_status = $self->_new_exchange_shipment_status($data);

    my %new_shipment = (
        type_id             => $data->{shipment_info}{shipment_type_id},
        class_id            => $SHIPMENT_CLASS__EXCHANGE,
        status_id           => $new_shipment_status,
        address_id          => $data->{shipment_info}{shipment_address_id},
        gift                => $data->{shipment_info}{gift},
        gift_message        => '',
        email               => $data->{shipment_info}{email},
        telephone           => $data->{shipment_info}{telephone},
        mobile_telephone    => $data->{shipment_info}{mobile_telephone},
        pack_instruction    => $data->{shipment_info}{packing_instruction},
        shipping_charge     => '0',
        comment             => '',
        address             => '',
        destination_code    => $data->{shipment_info}{destination_code},
        shipping_charge_id  => $data->{shipment_info}{shipping_charge_id},
        shipping_account_id => $data->{shipment_info}{shipping_account_id},
        ( defined $data->{shipment_info}{av_quality_rating} ?
            ( av_quality_rating   => $data->{shipment_info}{av_quality_rating} ) : () ),
        map { $_ => $orig_shipment->$_ } qw/
            force_manual_booking
            has_valid_address
            signature_required
        /
    );

    # Create new exchange shipment and log it
    my $exchange_shipment_id = create_returns_shipment(
        $self->dbh, $data->{shipment}->order->id, 'order', \%new_shipment);
    log_shipment_status(
        $self->dbh,
        $exchange_shipment_id,
        $new_shipment_status,
        $data->{operator_id}
    );

    # add newly created shipment id back
    # into the return table
    update_return_exchange_id(
        $self->dbh,
        $data->{return_id},
        $exchange_shipment_id
    );

    $self->_update_exchange_shipment_items($data, $exchange_shipment_id);

    if ( defined $data->{return} && ref( $data->{return} ) =~ /Public::Return/ ) {
        # update the 'return' object to reflect the Exchange Created
        $data->{return}->discard_changes;
    }
}

sub _update_exchange_shipment_items {
    my ($self, $data, $exchange_shipment_id) = @_;

    my $sales_channel = $data->{shipment}->order->channel->name;

    # create exchange shipment items & do web adjustments
    ITEM:
    foreach my $shipment_item_id ( keys %{ $data->{return_items} } ) {

        my $item = $data->{return_items}{$shipment_item_id};

        # not an exchange item - skip it
        { no warnings 'numeric';
          next ITEM unless ($item->{type} eq 'Exchange' ||
                            $item->{type} == $RETURN_TYPE__EXCHANGE);
        }

        die "Please select an exchange variant for @{[$data->{shipment_items}{$shipment_item_id}->variant->sku]}->\n"
            unless $item->{exchange_variant};

        my $use_reservation = 0;
        my $reserv_details;

        # check stock level for exchange item
        my $free_stock      = get_saleable_item_quantity( $self->dbh, $data->{shipment_items}{$shipment_item_id}->product_id );

        # check if customer has a reservation for the correct variant in the same Sales Channel as the order
        my $reservations    = get_cust_reservation_variants( $self->dbh, $shipment_item_id );
        if ( exists( $reservations->{ $item->{exchange_variant} } ) ) {
            $use_reservation    = 1;
            $reserv_details     = get_reservation_details( $self->dbh, $reservations->{ $item->{exchange_variant} }{reservation_id} );
        }

        unless ( ( $free_stock->{ $sales_channel }{ $item->{exchange_variant} } > 0 ) || ( $use_reservation ) ) {
            die 'Not enough stock to complete exchange of ' .
                $data->{shipment_items}{$shipment_item_id}->variant->sku .
                ' for ' .
                $self->schema->resultset('Public::Variant')->find($item->{exchange_variant})->sku
            ;
        }

        # create shipment item
        my %new_shipment_item = (
                variant_id      => $item->{exchange_variant},
                unit_price      => $data->{shipment_items}{ $shipment_item_id }->unit_price,
                tax             => $data->{shipment_items}{ $shipment_item_id }->tax,
                duty            => $data->{shipment_items}{ $shipment_item_id }->duty,
                status_id       => $SHIPMENT_ITEM_STATUS__NEW,
                special_order   => 'false',
                sale_flag_id    => $data->{shipment_items}{ $shipment_item_id }->sale_flag_id,
        );

        my $ex_si_id = create_shipment_item( $self->dbh, $exchange_shipment_id, \%new_shipment_item);

        $data->{return}
             ->return_items->not_cancelled
             ->by_shipment_item($shipment_item_id)
             ->update({exchange_shipment_item_id => $ex_si_id});

        # CANDO-180:
        # if this is using the hack from create returns then don't proceed
        # otherwise we will end up taking 2 items of stock off the web-site
        # because this whole thing gets called again when the user confirms
        # the return on the second page
        next ITEM       if ( $self->called_in_preview_create_mode );

        # adjust website stock level

        my $channel_info = get_channel_details( $self->dbh, $sales_channel );

        if ( !$channel_info->{config_section} ) {
            die 'Unable to get channel config section for channel: '.$sales_channel;
        }


        my $stock_manager;
        eval{
            $stock_manager
                = XTracker::WebContent::StockManagement->new_stock_manager({
                schema => $self->schema,
                channel_id => $channel_info->{id},
            });

            # if customer has a reservation for the variant then cancel the reservation
            # before adjusting WEB stock level
            if ( $use_reservation ) {
                # FIXME This will have to be a XTracker::WebContent::StockManagement
                # method for reservations to be available for ThirdParty websites
                cancel_reservation( $self->dbh, $stock_manager, {
                    reservation_id  => $reserv_details->{id},
                    status_id       => $reserv_details->{status_id},
                    variant_id      => $reserv_details->{variant_id},
                    operator_id     => $data->{operator_id},
                    customer_nr     => $reserv_details->{is_customer_number},
                    skip_upload_reservations => 1,
                } );

            }

            $stock_manager->stock_update(
                quantity_change => -1,
                variant_id      => $item->{exchange_variant},
                operator_id     => $data->{operator_id},
                pws_action_id   => $PWS_ACTION__ORDER,
                notes           => 'Exchange on '.$data->{shipment_info}{id},
            );

            $stock_manager->commit();
        };

        if(my $error = $@){
            $stock_manager->rollback();
            die $error;
        }
    }

}

sub _remove_return_items {
    my ($self, $data) = @_;

    my $return = $data->{return};


    # flag to keep track of exchange items
    # and work out if we remove them from shipment
    my $cancel_exchange = 0;

    # cancel items
    my $num_remove_items = 0;

    foreach my $return_item_id ( keys %{ $data->{return_items} } ) {
        my $hash_row = $data->{return_items}{$return_item_id};

        unless ($hash_row->{remove}) {
            delete $data->{return_items}{$return_item_id};
            next;
        }

        my $r_item = $return->return_items->find($return_item_id);
        die "couldn't find return_item with id $return_item_id" unless $r_item;
        my $shipment_item_id = $r_item->shipment_item_id;

        # Needed for building email templates.
        $hash_row->{shipment_item_id} = $shipment_item_id;

        update_return_item_status( $self->dbh, $return_item_id, $RETURN_ITEM_STATUS__CANCELLED );
        log_return_item_status( $self->dbh, $return_item_id, $RETURN_ITEM_STATUS__CANCELLED, $data->{operator_id} );

        # EN-1529: When Converting an Exchange to a Return we should leave the original Shipment Item
        #          status alone as it will be at the appropriare stage, otherwise set it to be Dispatched
        if ( !$hash_row->{change} ) {
            update_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED );
            log_shipment_item_status( $self->dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED, $data->{operator_id} );
        }

        if ( $hash_row->{change} ) {
            # EN-1529: See if there are any 'link_delivery_item__return_item' links
            #          to this return item so that they can be put on the new one
            #          when converting an exchange to a return
            if ( $r_item->link_delivery_item__return_items->count() ) {
                $hash_row->{current_link_to_delivery}   = $r_item->link_delivery_item__return_items->first;
            }
        }

        if ( $r_item->return_type_id == $RETURN_TYPE__EXCHANGE ) {
            $cancel_exchange = 1;
        }
        $num_remove_items++;
    }

    # Needed for template data
    $data->{num_remove_items} = $num_remove_items;

    return $cancel_exchange;
}


sub _cancel_exchange_items {
    my ($self, $data ) = @_;

    my $stock_manager = $data->{stock_manager} || croak 'You have to pass a stock_manager';

    my $return = $data->{return};
    my $exchange_shipment = $return->exchange_shipment;

    my $exchange_shipment_items   = get_shipment_item_info( $self->dbh, $exchange_shipment->id );

    # exchange order still active - not cancelled or dispatched
    return unless $exchange_shipment->is_active;

    # cancel the removed return items from exchange order
    foreach my $return_item_id ( keys %{ $data->{return_items} } ) {
        next unless $data->{return_items}{$return_item_id}{remove};

        my $r_item = $return->find_related('return_items', $return_item_id);

        my $exch_item = $r_item->exchange_shipment_item;
        # No exchange
        next unless $exch_item;
        next unless $exch_item->can_cancel;
        $exch_item->cancel({
            operator_id => $data->{operator_id},
            customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__CANCELLED_EXCHANGE,
            pws_action_id => $PWS_ACTION__CANCELLATION,
            notes => 'Exchanged, exchange_shipment_id: ' . $exch_item->id,
            stock_manager => $stock_manager,
        });
    }

    if ( !$exchange_shipment->non_cancelled_items->count ) {
        $exchange_shipment->set_cancelled( $data->{operator_id} );
    }
}


# This sub sends the appropriate messages for items that have been cancelled in
# sub _cancel_exchange_items. This message-sending was in that sub but didn't work
# correctly because that sub normally runs in a transaction. This can cause race
# conditions where we send messages to IWS and it replies before we have updated
# the database to the state that is correct for receiving the replies.
#
# The $iws_knows value should be obtained from method_iws_know_about_me on the
# given exchange shipment before _cancel_exchange_items runs, since that sub
# removes items from the shipment and can thus affect the result returned by
# does_iws_know_about_me.
sub send_msgs_for_exchange_items {
    my ($self, $exchange_shipment, $iws_knows ) = @_;

    # If there are no uncancelled items we cancel the shipment, otherwise we
    # update our shipment request
    if ( !$exchange_shipment->non_cancelled_items->count ) {
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
            {shipment => $exchange_shipment});
    }
    elsif (!config_var('PRL', 'rollout_phase')) {
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ShipmentRequest',
            $exchange_shipment);
    }
}

sub _setup_calculate_returns_charge_stash {
    my($self,$data) = @_;
    my $ret = {
      return_items => {}
    };

    my $shipment_address = {
        $self->schema
             ->resultset('Public::Shipment')
             ->find( $data->{shipment_id} )
             ->shipment_address
             ->get_inflated_columns
    };

    # Needed for calculate_returns_charge
    $ret->{got_faulty_items} = 0;
    my ($got_refund, $got_debit);

    foreach my $key (keys %{$data->{return_items}}) {
        my $item = $data->{return_items}->{$key};

        my $shipment_item = $data->{shipment_items}->{$key};
        if ($item->{reason_id} == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY) {
            $ret->{got_faulty_items} = 1;
        }

        my($refund,$duty,$tax,$num_exchange_items) = calculate_refund_charge_per_item(
            $self->schema,
            $item,
            $shipment_item,
            $shipment_address
        );

        $ret->{charge_duty} += $duty
            if ($duty);

        $ret->{charge_tax} += $tax
            if ($tax);

        $ret->{num_exchange_items} += $num_exchange_items
            if ($num_exchange_items);


        $item->{return} = 1
            if ($item->{type} eq 'Return' ||
                $item->{type} =~ /^[0-9]+$/ && $item->{type} == $RETURN_TYPE__RETURN);

        # The return flag actually just says 'we need to create an renumeration item for it'
        if ($refund) {
            $got_refund = 1;
            $ret->{return_items}{$key} = { %$item };
        }
        elsif ($duty || $tax) {
            # If we need to charge tax or duty we need to create a renumeration for it.
            $got_debit = 1;
            $ret->{return_items}{$key} = { %$item };
            $ret->{return_items}{$key}{return} = 1;
            $ret->{return_items}{$key}{unit_price} = 0;
        }

    }

    if ($got_refund) {
        $ret->{refund_type_id} = $data->{refund_type_id};
    }
    elsif ($got_debit) {
        $ret->{refund_type_id} = $RENUMERATION_TYPE__CARD_DEBIT;
    }


    # this is setting it above
    #$ret->{num_exchange_items} = $data->{num_exchange_items};
    $ret->{num_return_items} = $data->{num_return_items};

    if (not defined $data->{shipment}) {
        die __PACKAGE__ ." - \$data->{shipment} is not defined - [".join(", ", map { $_."=".$data->{$_} } keys %$data)."]";
    }

    $ret->{order} = {
        channel_id      => $data->{shipment}->order->channel->id,
        currency_id     => $data->{shipment}->order->currency_id,
    };

    $ret->{channel} = {
        config_section => $data->{shipment}->order->channel->business->config_section
    };

    $ret->{shipment_address} = {
        country  => $data->{shipment}->shipment_address->country,
    };

    $ret->{shipment_info} = {
        shipping_charge => $data->{shipment}->shipping_charge,
        carrier         => $data->{shipment}->shipping_account->carrier->name,
    };

    $ret->{previous_shipping_refund} = $data->{shipment}->renumerations->previous_shipping_refund;

    return $ret;
}

# checks to see if any debit can go straight to pending
sub _can_set_debit_to_pending {
    my $self    = shift;

    my $retval  = 0;

    if ( $self->requested_from_arma && arma_can_accept_exchange_charges() ) {
        $retval = 1;
    }

    return $retval;
}

1;
