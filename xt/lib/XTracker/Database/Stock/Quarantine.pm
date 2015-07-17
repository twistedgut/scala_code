package XTracker::Database::Stock::Quarantine;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;
use Perl6::Export::Attrs;
use Perl6::Junction 'any';

use XTracker::Constants::FromDB qw( :flow_status
                                    :pws_action
                                    :reservation_status
                                    :rtv_action
                                    :shipment_item_status
                                    :stock_action
                                    :stock_process_status
                                    :stock_process_type );

use XTracker::Database qw( get_schema_using_dbh get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Delivery qw( get_variant_delivery_ids );
use XTracker::Database::Logging qw( log_stock log_location log_rtv_stock );
use XTracker::Database::Product qw( product_present );
use XTracker::Database::RTV qw( create_rtv_stock_process );
use XTracker::Database::Stock qw ( check_stock_location insert_quantity update_quantity delete_quantity get_stock_location_quantity set_quantity_details );
use XTracker::Database::Utilities;
use XTracker::Logfile qw(xt_logger);
use XTracker::WebContent::StockManagement;
use MooseX::Params::Validate;
use MooseX::Types::Common::Numeric qw/PositiveInt/;

=head2 quarantine_stock

Moves some stock to quarantine.

param - dbh - A database handle
param - quantity_row : A DBIc Row that contains the stock that should be quarantined
param - quantity : The amount of stock that should be quarantined
param - reason : One of B<L> or B<V>, to represent I<Faulty> or I<Non-faulty> respectively
param - notes : String describing the fault
param - operator_id : user_id of operator that instigated the action
param - uri_path : URI called to instigate this action (usually from $request->parsed_uri->path)

=cut

sub quarantine_stock :Export(:quarantine_stock) {
    my ( $dbh, $quantity_row, $quantity, $reason,
        $notes, $operator_id, $uri_path,
    ) = validated_list(\@_,
        dbh         => { required => 1 },
        quantity_row=> { required => 1 },
        quantity    => { isa => 'Int' },
        reason      => { },
        notes       => { },
        operator_id => { isa => PositiveInt },
        uri_path    => {},
    );

    # For compatability with nasty old code, explode all our data in to another
    # hashref
    my $argref = {
        variant_id          => $quantity_row->variant_id(),
        location_id         => $quantity_row->location_id(),
        sku                 => $quantity_row->variant()->sku(),
        location            => $quantity_row->location()->location(),
        locationquantity    => $quantity_row->quantity(),
        quantity            => $quantity,
        reason              => $reason,
        notes               => $notes,
        channel_id          => $quantity_row->channel_id(),
        status_id           => $quantity_row->status_id(),
        operator_id         => $operator_id,
        uri_path            => $uri_path,
    };

    # pre-validation

    # verify that submitted quantity doesn't exceed location quantity
    if ( $argref->{quantity} > $argref->{locationquantity} ) {
        die "Please ensure quarantine quantity does not exceed current location quantity\n";
    }

    # check that reason was selected
    if ( !$argref->{reason} ) {
        die "Please select a reason\n";
    }

    # check that a note was entered
    if ( !$argref->{notes} ) {
        die "Please enter a note\n";
    }

    # return if no quantity was entered
    if ( $argref->{quantity} eq '' || $argref->{quantity} == 0 ) {
        return;
    }

    # fix quantity if entered as negative figure
    if ( $argref->{quantity} < 0 ) {
        $argref->{quantity} = $argref->{quantity} * -1;
    }

    if ( $argref->{status_id} && (
            $argref->{status_id} == $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS
                ||
            $argref->{status_id} == $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
        ) ) {
        $argref->{no_web_update} = 1;
        $argref->{stock_logging_quantity} = 0;
        $argref->{stock_status_id} = $argref->{status_id};
    }

    if ( uc($argref->{reason}) eq 'L' ) {
        # Reason - Faulty
        # send item to Quarantine location
        return _quarantine_faulty_stock ( $dbh, $argref );
    }
    elsif ( uc($argref->{reason}) eq 'V' ) {
        # Reason - Non-Faulty
        # send item to 'RTV Transfer Pending'
        return _quarantine_rtv_stock ( $dbh, $argref );
    }
    else {
        die "Please ensure you select a quarantine reason for each SKU\n";
    }
}

sub move_faulty_to_quarantine :Export(:quarantine_stock) {
    my ( $dbh, $argref ) = @_;

    $argref->{pws_action}   = $PWS_ACTION__QUARANTINED;
    $argref->{stock_action} = $STOCK_ACTION__QUARANTINED;
    $argref->{rtv_action}   = $RTV_ACTION__QUARANTINED;

    # always add a new quarantine quantity, even if there's one already there
    my $quantity_id = insert_quantity(
        $dbh,
        {
                   variant_id => $argref->{variant_id},
                     location => 'Quarantine',
                     quantity => $argref->{quantity},
                   channel_id => $argref->{channel_id},
            initial_status_id => $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
        }
    );

    set_quantity_details( $dbh, { details => $argref->{notes}, id => $quantity_id }  );

    $argref->{rtv_log_notes}  = $argref->{location} . ' to Quarantine';
}

sub _quarantine_faulty_stock {
    my ( $dbh, $argref ) = @_;

    move_faulty_to_quarantine( $dbh, $argref );

    return _quarantine_stock_tail( $dbh, $argref );
}

sub _quarantine_rtv_stock {
    my ( $dbh, $argref ) = @_;

    $argref->{pws_action}   = $PWS_ACTION__RTV_NON_DASH_FAULTY;
    $argref->{stock_action} = $STOCK_ACTION__RTV_NON_DASH_FAULTY;
    $argref->{rtv_action}   = $RTV_ACTION__NON_DASH_FAULTY;

    # insert/increment 'RTV Transfer Pending'
    my $rtv_transfer_pending_quantity = check_stock_location( $dbh, {
        variant_id => $argref->{variant_id},
        location => 'RTV Transfer Pending',
        channel_id => $argref->{channel_id},
        status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
    } );

    # update quantity
    if ($rtv_transfer_pending_quantity > 0) {
        update_quantity( $dbh, {
            variant_id => $argref->{variant_id},
            location => 'RTV Transfer Pending',
            quantity => $argref->{quantity},
            type => 'inc',
            channel_id => $argref->{channel_id},
            current_status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
        } );
    }
    # insert it
    else {
        insert_quantity( $dbh, {
            variant_id => $argref->{variant_id},
            location => 'RTV Transfer Pending',
            quantity => $argref->{quantity},
            channel_id => $argref->{channel_id},
            initial_status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
        } );
    }

    $argref->{rtv_log_notes} = $argref->{location} . " to 'RTV Transfer Pending'";

    # create RTV record
    _process_rtv_non_faulty(
        $dbh,
        {
            sku             => $argref->{sku},
            variant_id      => $argref->{variant_id},
            old_loc         => $argref->{location},
            designer_size   => $argref->{designer_size},
            quantity        => $argref->{quantity},
            reason          => $argref->{reason},
            notes           => $argref->{notes},
            channel_id      => $argref->{channel_id},
            uri_path        => $argref->{uri_path},
         }
    );

    return _quarantine_stock_tail( $dbh, $argref );
}

=head2 quarantine_stock_tail

Common stuff for anything that's been quarantined

=cut

sub _quarantine_stock_tail {
    my ( $dbh, $argref ) = @_;

    my $status_id = $argref->{stock_status_id} || $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    # remove stock from original location
    update_quantity( $dbh, {
        variant_id        => $argref->{variant_id},
        location          => $argref->{location},
        quantity          => ($argref->{quantity} * -1),
        type              => 'dec',
        channel_id        => $argref->{channel_id},
        current_status_id => $status_id
    } );

    log_quarantined_stock ( $dbh, $argref );

    # check if location now empty
    my $old_quantity = get_stock_location_quantity( $dbh, {
        variant_id => $argref->{variant_id},
        location   => $argref->{location},
        channel_id => $argref->{channel_id},
        status_id  => $status_id
    } );

    if ($old_quantity == 0) {
        delete_quantity( $dbh, {
            variant_id => $argref->{variant_id},
            location   => $argref->{location},
            channel_id => $argref->{channel_id},
            status_id  => $status_id
        } );

        log_location( $dbh, {
            variant_id  => $argref->{variant_id},
            location_id => $argref->{location_id},
            operator_id => $argref->{operator_id},
            channel_id  => $argref->{channel_id}
        } );
    }

    adjust_quarantined_web_stock( $dbh, $argref )
        unless $argref->{no_web_update};

    return;
}

sub adjust_quarantined_web_stock :Export(:quarantine_stock) {
    my ( $dbh, $argref ) = @_;

    my $stock_manager;
    eval{

        $stock_manager
            = XTracker::WebContent::StockManagement->new_stock_manager({
            schema      => get_schema_using_dbh( $dbh, 'xtracker_schema' ),
            channel_id  => $argref->{channel_id},
        });

        $stock_manager->stock_update(
            quantity_change => $argref->{quantity} * -1,
            variant_id      => $argref->{variant_id},
            skip_non_live   => 1,
            pws_action_id   => $argref->{pws_action},
            operator_id     => $argref->{operator_id},
            notes           => $argref->{notes},
        );

        $stock_manager->commit();
    };

    if($@){
        $stock_manager->rollback();
        die $@;
    }

    $stock_manager->disconnect();

}

sub log_quarantined_stock :Export(:quarantine_stock) {
    my ( $dbh, $argref ) = @_;

    my $quantity;

    # stock_logging_quantity is set by quarantine_stock() only,
    # and gets to override the quantity in logs

    if (exists $argref->{stock_logging_quantity}) {
        $quantity = $argref->{stock_logging_quantity};
    }
    else {
        $quantity = $argref->{quantity} * -1;
    }

    log_stock(
        $dbh,
        {
            variant_id  => $argref->{variant_id},
            action      => $argref->{stock_action},
            quantity    => $quantity,
            operator_id => $argref->{operator_id},
            notes       => $argref->{notes},
            channel_id  => $argref->{channel_id},
        },
    );

    # write rtv log record -- even for faulty stock,
    # since that will eventually be going back to the
    # vendor anyway
    log_rtv_stock({
        dbh             => $dbh,
        variant_id      => $argref->{variant_id},
        rtv_action_id   => $argref->{rtv_action},
        quantity        => $argref->{quantity},
        operator_id     => $argref->{operator_id},
        notes           => $argref->{rtv_log_notes},
        channel_id      => $argref->{channel_id}
    });
}

### Subroutine : _process_rtv_non_faulty
# usage        :
# description  :
# parameters   : dbh
#                          :
# returns      :
sub _process_rtv_non_faulty {
    my ( $dbh, $argref ) = @_;

    return if $argref->{quantity} <= 0;

    ## send to putaway list, type: 'RTV Non-Faulty'; status: 'Bagged and Tagged'
    my $sp_group = 0;
    my $delivery_id;
    my $delivery_item_id;

    ## get delivery item id from variant
    ($delivery_id, $delivery_item_id) = get_variant_delivery_ids($dbh, $argref->{variant_id}, $argref->{channel_id});
    croak "Invalid delivery_id ($delivery_id)" if $delivery_id !~ m{\A\d+\z}xms;
    croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ m{\A\d+\z}xms;

    create_rtv_stock_process({
        dbh                     => $dbh,
        stock_process_type_id   => $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY,
        delivery_item_id        => $delivery_item_id,
        quantity                => $argref->{quantity},
        process_group_ref       => \$sp_group,
        stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        originating_path        => $argref->{uri_path},
        notes                   => $argref->{notes},
    });

    return;

} ## END sub _process_rtv_non_faulty


1;

__END__

