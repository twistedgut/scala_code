package XTracker::Stock::Actions::SetQualityControl;
use strict;
use warnings FATAL=>'all';

use XTracker::Handler;
use XTracker::Error;
use XTracker::Utilities qw( unpack_handler_params );
use XTracker::Constants ':conversions';
use XTracker::Database qw( :common );
use XTracker::Database::Logging qw( log_delivery );
use XTracker::Database::Product qw( get_product_data
                                    validate_product_weight
                                );
use XTracker::Database::Delivery qw ( :DEFAULT get_delivery_channel get_stock_process_log );
use XTracker::Database::StockProcess qw( :DEFAULT :iws );
use XTracker::Database::Attributes qw(:update);
use XTracker::Barcode;
use XTracker::Document::PutawaySheet;
use XTracker::PrintFunctions;
use XTracker::Constants::FromDB qw(
    :delivery_action
    :delivery_item_status
    :delivery_status
    :stock_process_status
    :stock_process_type
    :storage_type
);
use XTracker::Config::Local qw( config_var );
use XTracker::Logfile qw( xt_logger );
use XT::Rules::Solve;

use DateTime;
use DBIx::Class::Row::Delta;
use NAP::DC::Barcode::Container;
use Scalar::Util 'looks_like_number';
use Smart::Match instance_of => { -as=>'match_instance_of' };
use Try::Tiny;
use XTracker::PrinterMatrix;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $sp_ref      = [];
    my $location    = "";
    my $delivery_id = 0;
    my $shipping_atts;

    my $operator_id = $handler->operator_id;

    # initialize structure to hold VariantMeasurement data to be sent via AMQ
    my %variants_to_sync;

    my $schema = $handler->schema;
    try {
        my $dbh = $schema->storage()->dbh();

        my $total_checked = 0;
        my ( $data_ref, $rest_ref ) = unpack_handler_params( $handler->{param_of} );

        $delivery_id = $rest_ref->{delivery_id};

        foreach my $stock_process_id ( keys %{$data_ref} ) {
            die "checked field must be an integer"
                if $data_ref->{$stock_process_id}->{checked} !~ /^\d+$/;

            die "faulty field must be an integer"
              if $data_ref->{$stock_process_id}->{faulty} !~ /^\d+$/;

            push @{$sp_ref}, {
                stock_process_id => $stock_process_id,
                checked          => $data_ref->{$stock_process_id}->{checked},
                faulty           => $data_ref->{$stock_process_id}->{faulty},
            };

            $total_checked += $data_ref->{$stock_process_id}->{checked};
        }

        # make sure container ID is instance of Barcode
        $rest_ref->{faulty_container} =
            NAP::DC::Barcode::Container->new_from_id($rest_ref->{faulty_container})
                if $rest_ref->{faulty_container};

        die "Container code too long"
            if grep( { $_->{faulty} > 0 } @$sp_ref )
                and $rest_ref->{faulty_container}
                and length($rest_ref->{faulty_container}) > 255;

        my $guard = $schema->txn_scope_guard();

        # start of WHM-198/DCA-4565: fixing double QC submission
        if( get_delivery( $dbh, $delivery_id )->{status_id} >= $DELIVERY_STATUS__PROCESSING ) {
            die bless { error => 'This delivery has already been submitted, please contact your supervisor.' } , 'ErrorDoubleQC';
        }

        log_delivery( $dbh, {
                delivery_id => $delivery_id,
                action      => $DELIVERY_ACTION__CHECK,
                quantity    => $total_checked,
                operator    => $operator_id,
                type_id     => $STOCK_PROCESS_TYPE__MAIN,
        } );

        # set the qc values
        my $printgroup = _set_quality_control( $schema, $sp_ref, $rest_ref->{faulty_container}, $delivery_id, $operator_id);

        # set packing notes if modified
         if ($rest_ref->{'packing_note_modified'}){
            set_shipping_attribute(
                $dbh, $rest_ref->{'prod_id'},
                'packing_note',
                $rest_ref->{'packing_note'},
                $operator_id
            );
        }

        ## set shipping attributes locally
        if ($rest_ref->{'country'}){
            set_shipping_attribute(
                $dbh, $rest_ref->{'prod_id'},
                'country',
                $rest_ref->{'country'},
                $operator_id
            );
            $shipping_atts->{'origin_country_id'} = $rest_ref->{'country'};
        }


        # consider weight changing only if its new value was passed
        if (defined $rest_ref->{weight}) {

            # sanitise passed weight value
            $rest_ref->{weight} =~ s/\s+//g;

            # if product weight appears to be incorrect - an exception is thrown
            validate_product_weight( product_weight => $rest_ref->{weight} );

            set_shipping_attribute(
                $dbh, $rest_ref->{'prod_id'},
                'weight',
                $rest_ref->{'weight'},
                $operator_id
            );
            $shipping_atts->{'weight'}      = $rest_ref->{'weight'};
            $shipping_atts->{'weight_unit'} = config_var('Units', 'weight');
        }

        if ($rest_ref->{'fabric_content'}){
            set_shipping_attribute(
                $dbh,
                $rest_ref->{'prod_id'},
                'fabric_content',
                $rest_ref->{'fabric_content'},
                $operator_id
            );
            $shipping_atts->{'fabric_content'} = $rest_ref->{'fabric_content'};
        }

        # XT no longer allow length, width or height to be updated through this
        # end-point, so if any of them are present, throw an error
        die 'Product length, width and height can no longer be updated through Quality Control'
            if grep { $rest_ref->{$_} } qw/length width height/;

        if (!$rest_ref->{voucher}) {
            my $product = $schema->resultset('Public::Product')->find($rest_ref->{'prod_id'})
                or die "couldn't find product with id: $rest_ref->{'prod_id'}";

            if ($rest_ref->{'storage_type'}){

                unless ($product->storage_type_id) {
                    my $storage_type = $schema->resultset('Product::StorageType')
                        ->find({ id => $rest_ref->{'storage_type'} });
                    unless ($storage_type) { die "Invalid Storage Type"; }

                    $product->storage_type_id( $rest_ref->{'storage_type'});
                    $product->update();
                }
                # else we already have a storage type, no need to do anything
            }
            else {
                unless ($product->storage_type_id) {
                    die "Storage type is required.";
                }
            }

            $shipping_atts->{storage_type} = $product->storage_type->name;
        }
        # else we have a voucher and storage is assumed to be cage

        ## create job to push attributes to Fulcrum
        # if anything was set by user
        my $job_payload;

        # loop over attributes populate job payload
        foreach my $attr ( keys %{$shipping_atts} ) {
            $job_payload->{ $attr } = $shipping_atts->{$attr};
        }

        # create job if we have any updates
        if (keys %{$job_payload}){
            $job_payload->{product_id}  = $rest_ref->{'prod_id'};
            $job_payload->{operator_id} = $operator_id;
            $job_payload->{from_dc}     = config_var('DistributionCentre', 'name');
            my $job     = $handler->create_job( "Send::Product::ShippingData", $job_payload );
        }

        unless ($rest_ref->{voucher}) {
            # set variant measurements

            my %unique_measurement;
            my $product = $schema->resultset('Public::Product')->find( $rest_ref->{'prod_id'} );
            my $date = DateTime->now();
            # loop through data
            foreach my $field_name ( keys %$rest_ref ) {
                # get measurement name and variant id from form field name
                my ($field_type, $variant_id, $measurement) = split /-/, $field_name;

                # if we got both and a value was entered set it
                next unless $measurement;
                next unless $variant_id;
                next unless defined $rest_ref->{$field_name};

                my $variant = $schema->resultset('Public::Variant')->find( $variant_id );
                my $variant_notes_delta = DBIx::Class::Row::Delta->new({
                    dbic_row => $variant,
                    changes_sub => sub{
                        my ($row) = @_;
                        my %hash = map {
                            $_->measurement->measurement => $_->value
                        } $row->variant_measurements->all;
                        return \%hash; # returns from this sub, not the try
                    }
                });

                try {
                    $rest_ref->{$field_name} = clean_measurement($rest_ref->{$field_name});
                } catch {
                    die "You entered bad data: $_\n";
                };

                set_measurement(
                    $dbh,
                    $measurement,
                    $variant_id,
                    $rest_ref->{$field_name}
                );

                # get mesurement id's and cache them in a hash for later usage
                unless (exists $unique_measurement{$measurement}) {
                    my $measurement_id = $schema->resultset('Public::Measurement')
                        ->find({ measurement => $measurement })
                        ->id;

                    $unique_measurement{$measurement} = $measurement_id;
                }

                $variants_to_sync{$variant_id} = 1;

                if(my $changes = $variant_notes_delta->changes) {
                    $variant->create_related('variant_measurements_logs', {
                        operator_id => $operator_id,
                        note        => $changes,
                        date        => $date,
                    });
                }
            }

            # redirect to delivery scan
            $product->show_default_measurements;
        }
        $location = "/GoodsIn/QualityControl";

        my $delivery = $schema->resultset('Public::Delivery')->find($delivery_id);
        if ( $delivery->has_been_qced ) {
            die bless { error => 'This delivery has already been submitted, please contact your supervisor.' } , 'ErrorDoubleQC';
        }
        # Send preadvice messages
        _send_all($handler->msg_factory, $schema, $printgroup);
        # Print putaway sheets
        XTracker::Document::PutawaySheet->new(group_id => $_)->print_at_location(
            $handler->operator->operator_preference->printer_station_name
        ) for ( sort { $a <=> $b } values %$printgroup );

        set_delivery_status($dbh,
                            $delivery_id,
                            'delivery_id',
                            $DELIVERY_STATUS__PROCESSING
                        );

        $guard->commit;
        xt_success('Quality control successful');

        # Let's now send the AMQ updates into all the other DCs - not fatal if
        # we fail
        try {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Sync::VariantMeasurement',
                {
                    variants => [ keys %variants_to_sync ],
                    schema => $schema,
                },
            );
        } catch {
            xt_logger->warn($_);
        };
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('ErrorDoubleQC')) {
            xt_warn( $_->{error} );
            $location = '/GoodsIn/QualityControl';
        }
        else {
            xt_warn( $_ );
            $location = sprintf( 'Book?delivery_id=%s', $delivery_id );
        }
    };

    return $handler->redirect_to( $location );
}

sub _set_quality_control {
    my ( $schema, $stock_process_items, $faulty_container, $delivery_id, $operator_id) = @_;
    my $main_group    = 0;
    my $faulty_group  = 0;
    my $surplus_group = 0;

    my $total_faulty  = 0;
    my $total_surplus = 0;
    my $total_main    = 0;

    my $dbh = $schema->storage->dbh;

    my $is_voucher_delivery = $schema->resultset('Public::Delivery')
                                     ->find($delivery_id)
                                     ->is_voucher_delivery;

    my $stock_process_status = $is_voucher_delivery
                             ? $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                             : $STOCK_PROCESS_STATUS__APPROVED;
    # Save main group
    $main_group = get_process_group_id( $dbh, $stock_process_items->[0]{stock_process_id} );

    foreach my $sp_ref ( @$stock_process_items ) {

        my $total_ordered = stock_process_data( $dbh,
            $sp_ref->{stock_process_id},
            'ordered' );

        if (!$total_ordered){ $total_ordered = 1; }

        my $delivery_count = stock_process_data( $dbh,
            $sp_ref->{stock_process_id},
            'delivered' );

        my $total_passed = stock_process_data( $dbh,
            $sp_ref->{stock_process_id},
            'passed' ) || 0;

        my $delivery_item_id = stock_process_data( $dbh,
            $sp_ref->{stock_process_id},
            'delivery_item_id' );

        my $surplus = ( $delivery_count - $sp_ref->{faulty} )
            - ( $total_ordered - $total_passed );

        my $main    = $delivery_count - ( $sp_ref->{faulty} + $surplus );
        $total_main += $main;

        # quick check for negative main stock remaining - try to catch bug in surplus calculation
        if ( $main < 0 ) {
            if( get_delivery( $dbh, $delivery_id )->{status_id} >= $DELIVERY_STATUS__PROCESSING ) {
                die bless { error => 'This delivery has already been submitted, please contact your supervisor.' } , 'ErrorDoubleQC';
            }
            else{
                die "Error in surplus calculation: Main: $main, Surplus: $surplus\n\nPlease contact XTrequests";
            }
        }

        ### All faulty stock now goes straight to Put Away as sp type 'Faulty'
        if ( $sp_ref->{faulty} ) {
            my $sp          = $schema->resultset('Public::StockProcess')->find( $sp_ref->{stock_process_id} );
            my $new_sp      = $sp->split_stock_process( $STOCK_PROCESS_TYPE__FAULTY, $sp_ref->{faulty}, $faulty_group );
            if ( $is_voucher_delivery ) {
                # For Vouchers Only:
                #   automatically create several logs indicating
                #   the voucher is faulty & dead
                $new_sp->mark_qcfaulty_voucher( $operator_id );
            }
            else {
                # We only send messages and print putaway sheets for faulty
                # products, so we set this here to omit it from our return
                # value
                $faulty_group = $new_sp->group_id;
                set_stock_process_status( $dbh, $new_sp->id, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );
                if ($faulty_container) {
                    set_stock_process_container( $dbh, $new_sp->id, $faulty_container );
                }
            }

            $total_faulty += $sp_ref->{faulty};
        }

        if ( $surplus > 0 ) {
            my $sp          = $schema->resultset('Public::StockProcess')->find( $sp_ref->{stock_process_id} );
            my $new_sp      = $sp->split_stock_process( $STOCK_PROCESS_TYPE__SURPLUS, $surplus, $surplus_group );
            $surplus_group  = $new_sp->group_id;
            #my $new_sp = split_stock_process( $dbh,
            #    $STOCK_PROCESS_TYPE__SURPLUS,
            #    $sp_ref->{stock_process_id},
            #    $surplus,
            #    \$surplus_group,
            #    $delivery_item_id );

            if ( $is_voucher_delivery ) {
                set_stock_process_status( $dbh, $new_sp->id, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );
            }
            else {
                set_stock_process_status( $dbh, $new_sp->id, $STOCK_PROCESS_STATUS__NEW );
            }

            $total_surplus += $surplus;
        }

        set_stock_process_status( $dbh,
            $sp_ref->{stock_process_id},
            $stock_process_status
        );

        set_delivery_item_status( $dbh,
            $sp_ref->{stock_process_id},
            'stock_process_id',
            $DELIVERY_ITEM_STATUS__PROCESSING );

        # translation of this "complete" thing: if the stock_process
        # is empty (e.g. all the items were split off as faulty), the
        # (now empty) process is complete, because we don't have
        # anything else to do with this 0 items

        my $has_quantity_zero_or_less = check_stock_process_complete( $dbh,
            'stock_process',
            $sp_ref->{stock_process_id} );

        # Instead of marking it complete, remove it: a zero-quantity stock
        # process is of no use later.
        if ($has_quantity_zero_or_less) {
            my $sp = $schema->resultset('Public::StockProcess')->find( $sp_ref->{stock_process_id} );
            $sp->delete;
            #complete_stock_process( $dbh, $sp_ref->{stock_process_id} );
        }
    }

    # logging
    if( $total_main ){
        my %args = ();
        $args{delivery_id} = $delivery_id;
        $args{action}      = $DELIVERY_ACTION__APPROVE;
        $args{quantity}    = $total_main;
        $args{operator}    = $operator_id;
        $args{type_id}     = $STOCK_PROCESS_TYPE__MAIN;

        log_delivery( $dbh, \%args );
    }

    if( $total_faulty ){
        my %args = ();
        $args{delivery_id} = $delivery_id;
        $args{action}      = $DELIVERY_ACTION__CREATE;
        $args{quantity}    = $total_faulty;
        $args{operator}    = $operator_id;
        $args{type_id}     = $STOCK_PROCESS_TYPE__FAULTY;

        log_delivery( $dbh, \%args );
    }

    if( $total_surplus ){
        my %args = ();
        $args{delivery_id} = $delivery_id;
        $args{action}      = $DELIVERY_ACTION__CREATE;
        $args{quantity}    = $total_surplus;
        $args{operator}    = $operator_id;
        $args{type_id}     = $STOCK_PROCESS_TYPE__SURPLUS;

        log_delivery( $dbh, \%args );
    }

    my $main_group_rs = $schema->resultset('Public::StockProcess')
        ->get_group( $main_group )->main;

    return {
        $faulty_group                               ? (faulty_group => $faulty_group)   : (),
        $surplus_group                              ? (surplus_group => $surplus_group) : (),
        $main_group_rs->get_column('quantity')->sum ? (main_group => $main_group)       : (),
    };
}

sub _send_all {
    my ($msg_factory,$schema,$pg) = @_;
    if( my $group = $pg->{faulty_group} ){
        # only for regular products, faulty vouchers are destroyed
        send_pre_advice( $msg_factory, $schema, $group,
                         $STOCK_PROCESS_TYPE__FAULTY, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                     );
    }

    if( my $group = $pg->{surplus_group} ){
        # only for vouchers, which are automatically accepted;
        # surplus regular products are handled in
        # XTracker::Stock::Actions::SetSurplus
        send_pre_advice( $msg_factory, $schema, $group,
                         $STOCK_PROCESS_TYPE__SURPLUS, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                     );
    }

    if( my $group = $pg->{main_group} ){
        my $sent=0;
        # this is for vouchers
        send_pre_advice( $msg_factory, $schema, $group,
                         $STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                     ) and ++$sent;
        # this is for regular products
        send_pre_advice( $msg_factory, $schema, $group,
                         $STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_STATUS__APPROVED
                     ) and ++$sent;
        # only one will actually generate messages
        die qq{The PGID $group contains both "bagged and tagged" and "new" main items}
            if $sent>1;
    }
}

1;
