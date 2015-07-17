package XTracker::Stock::Actions::SetPutaway;

use strict;
use warnings;

use Data::Dump qw( pp );
use DateTime;

use XTracker::Handler;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(
    :delivery_action
    :pws_action
    :return_item_status
    :rtv_action
    :stock_action
    :stock_process_status
    :stock_process_type
    :flow_status
    :putaway_type
);
use XTracker::Database::Delivery qw(
    complete_delivery
    complete_delivery_item
    delivery_is_complete
    delivery_item_is_complete
);
use XTracker::Database::Logging  qw( log_delivery log_stock log_location :rtv );
use XTracker::Database::Operator qw( get_operator_by_id );
use XTracker::Database::Product  qw( product_present get_variant_details );
use XTracker::Database           qw( get_database_handle );
use XTracker::Database::Return;
use XTracker::Database::RTV qw(
    get_rtv_stock_process_row
    log_rtv_putaway
    update_fields
    :rtv_stock
);
use XTracker::Database::StockProcess qw(
    :DEFAULT
    :putaway
    get_delivery_item_id
    get_stock_process_row
);
use XTracker::Database::StockProcessCompletePutaway;
use XTracker::Database::Stock qw( :DEFAULT check_stock_location );
use XTracker::EmailFunctions;
use XTracker::Error;
use XTracker::Utilities qw( unpack_handler_params :string );
use XTracker::WebContent::StockManagement;

sub handler {
    my $handler = XTracker::Handler->new(shift);
    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $operator_id = $handler->operator_id;

    my $source           = "";
    my $putaway_type     = "";
    my $redirect_uri     = "";
    my $process_group_id = 0;

    my %args = ();

    ## unpack request parameters
    my ( $data_ref, $rest_ref ) = unpack_handler_params( $handler->{param_of} );

    die "error: $rest_ref->{error}\n"      if $rest_ref->{error};
    die "No channel config defined\n"      if !$rest_ref->{channel_config};
    die "No active channel id defined\n"   if !$rest_ref->{active_channel_id};
    die "No delivery channel id defined\n" if !$rest_ref->{delivery_channel_id};

    my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
        schema      => $schema,
        channel_id  => $rest_ref->{active_channel_id},
    });

    my $completed_sp_rs;
    eval{ $schema->txn_do(sub{
        my %vars   = ();
        my $di_ref = ();

        ## source, putaway type and process group id from the form
        $source              = $rest_ref->{source};
        $putaway_type        = $rest_ref->{putaway_type};
        $process_group_id    = $rest_ref->{process_group_id};
        $process_group_id =~ s/^p-//i; # compatibility with external WMS

        if ($process_group_id =~ m/-/){
            $process_group_id =  get_process_group_by_rma( $dbh, $process_group_id );
        }

        my $sp_group_rs = $schema->resultset('Public::StockProcess')
                                 ->get_group( $process_group_id );

        die "PGID $handler->{data}{process_group_id} is handled by IWS"
            if $sp_group_rs->first->is_handled_by_iws( $handler->iws_rollout_phase );

        ## set item count values
        if ($data_ref) {
            foreach my $stock_process_id ( keys %$data_ref ) {
                my $location = $data_ref->{$stock_process_id}{location};
                my $quantity = $data_ref->{$stock_process_id}{quantity};

                validate_location_type( $schema, $stock_process_id, $location, $quantity );
                check_suggested_location( $dbh, $location, $rest_ref );
                set_putaway_item( $dbh, $stock_process_id, $location, $quantity );
                # If we have a faulty voucher we need to set its type to dead
                my $stock_process = $schema->resultset('Public::StockProcess')
                                           ->find($stock_process_id);
                if ( $stock_process->get_voucher
                 and $stock_process->type_id == $STOCK_PROCESS_TYPE__FAULTY ) {
                    $stock_process->update({type_id=>$STOCK_PROCESS_TYPE__DEAD});
                }
            }

            ## redirect to delivery scan
            $redirect_uri  = "Book?process_group_id=$process_group_id";
            $redirect_uri .= '&view=HandHeld' if $source eq 'HandHeld';
        }

        ## complete putaway?
        if ( $rest_ref->{complete} ) {
            my ($variant_id, $variant_location) = complete_putaway(
                $schema,
                $stock_manager,
                $process_group_id,
                $operator_id,
                $handler->msg_factory,
            );

            xt_success("Process Group $process_group_id has been put away successfully.");
            ## redirect to putaway list
            $redirect_uri  = "/GoodsIn/Putaway";
            $redirect_uri .= '?view=HandHeld' if $source eq 'HandHeld';

            ## check for PI stock counting for returns put away
            if ( $putaway_type == $PUTAWAY_TYPE__RETURNS
              && check_stock_count_variant(
                $dbh,
                $variant_id,
                $variant_location,
                get_stock_count_setting($dbh, "returns")
              )
            ) {
                ## redirect to stock count
                $redirect_uri  = "/GoodsIn/Putaway/CountVariant"
                               . "?redirect_type=Return"
                               . "&variant_id=$variant_id"
                               . "&location=$variant_location";
                $redirect_uri .= '&view=HandHeld' if $source eq 'HandHeld'
            }

            if ( $rest_ref->{ignored_location_suggestion} ) {
                _email_suggestion_not_used( $dbh, {
                    operator_id     => $operator_id,
                    rest_ref        => $rest_ref,
                    data_ref        => $data_ref,
                    variant_id      => $variant_id,
                });
            }

            $completed_sp_rs = $schema->resultset('Public::StockProcess')
                                      ->get_group($process_group_id);
        }

        $stock_manager->commit;
    })};
    if ( my $err = $@ ) {
        if ( $err =~ /^Ignored Suggested Location/ ) {
            $err = 'Ignored Suggested Location';
        }

        xt_warn(strip_txn_do($err));

        $redirect_uri  = "/GoodsIn/Putaway/Book?process_group_id=$process_group_id";
        $redirect_uri .= '&view=HandHeld' if $source eq 'HandHeld';

        if ( $rest_ref->{ignored_location_suggestion} ) {
            $redirect_uri .= "&location_suggestion=".$rest_ref->{ignored_location_suggestion};
        }

        $stock_manager->rollback;
    }
    elsif ($rest_ref->{complete} && defined($completed_sp_rs) && $completed_sp_rs->count) {
        $handler->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::WMS::StockReceived', { sp_group_rs => $completed_sp_rs});
    }

    $stock_manager->disconnect;

    $handler->redirect_to( $redirect_uri );
}

sub validate_location_type {
    my ( $schema, $stock_process_id, $location, $quantity ) = @_;

    #my $dc_name = config_var('DistributionCentre', 'name');

    ## get stock process type
    my $dbh                = $schema->storage->dbh;
    my $sp_row_ref         = get_stock_process_row($dbh, { stock_process_id => $stock_process_id } );
    my $type_id            = $sp_row_ref->{type_id};
    my $delivered_quantity = $sp_row_ref->{quantity};

    my $loc_rs = $schema->resultset('Public::Location');
    my $loc_obj = $loc_rs->search({ location => $location })->first;

    ## sanity check for FAULTY put away - must be put into an RTV Goods In location
    if ( ($type_id == $STOCK_PROCESS_TYPE__FAULTY) ) {
        my $voucher = $schema->resultset('Public::StockProcess')
                             ->find($stock_process_id)
                             ->get_voucher;
        # A faulty voucher should go to dead stock
        if ( $voucher ) {
            die "A faulty voucher needs to be put in a dead stock location\n"
                if !$loc_rs->location_allows_status($location, $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS );
        }
        elsif ( !$loc_rs->location_allows_status($location, $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS) ){
            die "Please select an RTV Goods In location for this item.\n";
        }
        else {
            XT::Rules::Solve->solve('SetPutawayRTV::validate_location_type' => {
                floor      => $loc_obj->floor,
                stock_type => 'RTV Goods In',
            });
        }
    }

    ## sanity check for RTV put away - must be put into an RTV Process location
    if ( ($type_id == $STOCK_PROCESS_TYPE__RTV)
      or ($type_id == $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY)
      or ($type_id == $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR) ) {
        if ( !$loc_rs->location_allows_status($location, $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS) ) {
            die "Please select an RTV Process location for this item.\n";
        }
        else {
            XT::Rules::Solve->solve('SetPutawayRTV::validate_location_type' => {
                 floor      => $loc_obj->floor,
                 stock_type => 'RTV Process',
            });
        }
    }

    ## sanity check for Dead Stock put away - must be put into a Dead Stock location
    if ($type_id == $STOCK_PROCESS_TYPE__DEAD) {
        if ( !$loc_rs->location_allows_status($location, $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS) ) {
            die "Please select a Dead Stock location for this item.\n";
        }
        else {
            XT::Rules::Solve->solve('SetPutawayRTV::validate_location_type' => {
                floor      => $loc_obj->floor,
                stock_type => 'Dead Stock',
            });
        }
    }

    ## sanity check for Main Stock put away - must be put into a Main Stock location
    if ( $type_id == $STOCK_PROCESS_TYPE__MAIN
      || $type_id == $STOCK_PROCESS_TYPE__FASTTRACK
      || $type_id == $STOCK_PROCESS_TYPE__RTV_FIXED
      || $type_id == $STOCK_PROCESS_TYPE__QUARANTINE_FIXED
      || $type_id == $STOCK_PROCESS_TYPE__SURPLUS ) {


        if ( !$loc_rs->location_allows_status($location, $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS) ) {
            die "Please select a Main Stock location for this item.\n";
        }
        else {
            my $sp = $schema->resultset('Public::StockProcess')->find($stock_process_id);
            XT::Rules::Solve->solve('SetPutawayMain::validate_location_type' => {
                floor      => $loc_obj->floor,
                stock_type => $type_id,
                is_outnet  => $sp->channel->is_on_outnet,
            });
        }
    }

    ## get the quantity already submitted for this stock process
    my $stock_process = $schema->resultset('Public::StockProcess')->find($stock_process_id);
    my $submitted_putaway_quantities = $stock_process->putaways->total_quantity;

    ## sanity check for quantity entered not greater than in db
    if (($quantity + $submitted_putaway_quantities) > $delivered_quantity) {
        die "Quantity entered ($quantity) is greater than the quantity remaining for putaway (". ($delivered_quantity - $submitted_putaway_quantities).").\n";
    }
    return;
}

sub check_suggested_location {
    my ( $dbh, $location, $rest_ref ) = @_;

    ## sanity check for Returns or Stock Transfer - checks whether suggested location has been used
    if ( ( $rest_ref->{putaway_type} == $PUTAWAY_TYPE__RETURNS
        || $rest_ref->{putaway_type} == $PUTAWAY_TYPE__STOCK_TRANSFER )
      && ( $rest_ref->{location_suggestion} ) ) {
        my $used_suggestion = 1;
        if ( length($rest_ref->{location_suggestion}) > 4 ) {
            $used_suggestion = 0
                if ( $rest_ref->{location_suggestion} ne $location );
        }
        else {
            $used_suggestion = 0
                if ( $rest_ref->{location_suggestion} ne substr( $location, 0, 4 ) );
        }

        if ( !$used_suggestion ) {
            $rest_ref->{ignored_location_suggestion} = $location;
            if ( !$rest_ref->{ignore_suggestion} ) {
                die "Ignored Suggested Location\n";
            }
        }
    }
    return;
}

=head2 _email_suggestion_not_used

=head3 Usage

 _email_suggestion_not_used(
      $dbh, {
         operator_id,
         rest_ref,
         data_ref
         variant_id
  } );

=head3 Description

This emails the 'stockadmin' team when someone ignores the suggested location
to use when putawaying an item.

=head3 Parameters

A Database Handle, Operator Id, Rest Ref & Data Ref - a HASH of params split
out by unpack_params & Variant Id.

=head3 Returns

Nothing

=cut

sub _email_suggestion_not_used {
    my ( $dbh, $args )   = @_;

    my $operator    = get_operator_by_id( $dbh, $args->{operator_id} );
    my $variant     = get_variant_details( $dbh, $args->{variant_id} );

    my $now         = DateTime->now( time_zone => "local" );
    my $datetime    = $now->dmy('/')." @ ".$now->hms;

    my $subject = "Returns Putaway: Operator did not use 'suggested' location";
    my $message =<<MSG
An Operator while using the Returns - Putaway page did not use the suggested location or location zone shown on the page.

Date               : $datetime
Operator           : $operator->{name}
SKU                : $variant->{sku}
Suggested Location : $args->{rest_ref}{location_suggestion}
Location Used      : $args->{rest_ref}{ignored_location_suggestion}
MSG
;

    send_email( config_var('Email', 'xtracker_email'), "", config_var('Email','stockadmin_email'), $subject, $message );
    return;
}




1;
