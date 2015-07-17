package XTracker::Stock::Actions::SetSurplus;

use strict;
use warnings;

use Try::Tiny;
use URI;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Database::Logging         qw( log_delivery );
use XTracker::Database::StockProcess qw/
    check_stock_process_complete
    complete_stock_process
    get_delivery_id
    get_process_group_id
    set_stock_process_status
    set_stock_process_type
    split_stock_process
    stock_process_data
/;
use XTracker::Database::Delivery qw( get_delivery_channel get_stock_process_log );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Database::RTV qw( insert_rtv_stock_process );
use XTracker::Constants::FromDB qw(
    :delivery_action
    :stock_process_status
    :stock_process_type
);
use XTracker::Document::RTVStockSheet;
use XTracker::Document::SurplusSheet;
use XTracker::Logfile 'xt_logger';

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $uri_path = $handler->{r}->parsed_uri->path;

    my $surplus_items    = ();
    my $redirect_uri     = URI->new('/GoodsIn/Surplus');
    my $process_group_id = 0;

    try {
        # unpack request parameters
        my ( $data_ref, $rest_ref ) = $handler->unpack_params;

        $process_group_id = $rest_ref->{process_group_id} =~ s/^p-//ir;

        my $schema = $handler->schema;
        my $guard = $schema->txn_scope_guard;
        foreach my $stock_process_id ( sort keys %{$data_ref} ) {

            ### check that the sum of line quantities entered matches total line quantity.
            my $quantity_entered
                = ($data_ref->{$stock_process_id}{rtv}||0)
                + ($data_ref->{$stock_process_id}{accepted}||0)
                ;

            if ( $quantity_entered > 0 && $quantity_entered != $data_ref->{$stock_process_id}{quantity} ) {
                $redirect_uri->query_param(error_id => $stock_process_id);
                die "Please ensure that quantities entered sum to the correct line quantity!\n";
             }

            push @{$surplus_items}, {
                stock_process_id => $stock_process_id,
                rtv              => $data_ref->{$stock_process_id}{rtv},
                accepted         => $data_ref->{$stock_process_id}{accepted},
            };
        }

        process_surplus( $schema, $handler->msg_factory, $surplus_items, $handler->operator, $uri_path );

        $guard->commit;
    }
    catch {
        xt_logger->warn("error with setting surplus: $_ (process_group_id=$process_group_id)");
        $redirect_uri->query_param(
            $redirect_uri->query_form, process_group_id => $process_group_id
        );
        xt_warn($_);
    };

    return $handler->redirect_to( $redirect_uri );
}

sub process_surplus {
    my ( $schema, $msg_factory, $surplus_items, $operator, $uri_path ) = @_;

    my $total_approved = 0;
    my $total_rtv      = 0;

    # TODO: validation of input data

    my $dbh = $schema->storage->dbh;
    my $delivery_id = get_delivery_id( $dbh, get_process_group_id( $dbh, $surplus_items->[0]{stock_process_id}) );

    # get channel info on delivery
    my $channel_name = get_delivery_channel( $dbh, $delivery_id );
    my $channel_info = get_channel_details( $dbh, $channel_name );

    my $rtv_group_id    = 0;
    my $accept_group_id = 0;

    foreach my $surplus_ref ( @$surplus_items ) {
        # create process groups for rtv and accepted
        my $delivery_item_id = stock_process_data(
            $dbh,
            $surplus_ref->{stock_process_id},
            'delivery_item_id',
        );

        if ( $surplus_ref->{rtv} ) {
            my $new_sp = split_stock_process(
                $dbh,
                $STOCK_PROCESS_TYPE__SURPLUS,
                $surplus_ref->{stock_process_id},
                $surplus_ref->{rtv},
                \$rtv_group_id,
                $delivery_item_id
            );

            set_stock_process_type(   $dbh, $new_sp, $STOCK_PROCESS_TYPE__RTV );
            set_stock_process_status( $dbh, $new_sp, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );

            ## insert rtv_stock_process record
            insert_rtv_stock_process({
                dbh                 => $dbh,
                stock_process_id    => $new_sp,
                originating_path    => $uri_path,
                notes               => 'Surplus Stock',
            });

            $total_rtv += $surplus_ref->{rtv};
        }

        if ( $surplus_ref->{accepted} ) {
            my $new_sp = split_stock_process(
                $dbh,
                $STOCK_PROCESS_TYPE__SURPLUS,
                $surplus_ref->{stock_process_id},
                $surplus_ref->{accepted},
                \$accept_group_id,
                $delivery_item_id
            );

            set_stock_process_status( $dbh, $new_sp, $STOCK_PROCESS_STATUS__APPROVED );

            $total_approved += $surplus_ref->{accepted};
        }

        next unless check_stock_process_complete(
            $dbh, 'stock_process', $surplus_ref->{stock_process_id}
        );
        complete_stock_process( $dbh, $surplus_ref->{stock_process_id} );
    }

    # Assume (!) the user got here via the surplus landing page and hence the
    # op has chosen a printer
    my $printer_location = $operator->printer_location->name;
    if( $accept_group_id ){
        XTracker::Document::SurplusSheet->new(group_id => $accept_group_id)
            ->print_at_location($printer_location);
        $msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
            sp_group_rs => $schema->resultset('Public::StockProcess')->search_rs({
                group_id  => $accept_group_id,
                type_id   => $STOCK_PROCESS_TYPE__SURPLUS,
                status_id => $STOCK_PROCESS_STATUS__APPROVED,
            })
        });
    }

    if ( $rtv_group_id ) {
        # we need to print booked in dates(main|surplus) in stock sheet (from logs)
        my $booked_in_dates = get_stock_process_log($dbh, $delivery_id);

        XTracker::Document::RTVStockSheet->new(
            group_id      => $rtv_group_id,
            document_type => 'rtv',
            origin        => 'surplus',
        )->print_at_location($printer_location);

        $msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
            sp_group_rs => $schema->resultset('Public::StockProcess')->search_rs({
                group_id  => $rtv_group_id,
                type_id   => $STOCK_PROCESS_TYPE__RTV,
                status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            })
        });
    }

    if ( $total_approved ) {
        my %args = (
            delivery_id => $delivery_id,
            action      => $DELIVERY_ACTION__APPROVE,
            quantity    => $total_approved,
            operator    => $operator->id,
            type_id     => $STOCK_PROCESS_TYPE__SURPLUS,
            channel_id  => $channel_info->{id},
        );
        log_delivery( $dbh, \%args );
    }

    if ( $total_rtv ) {
        my %args = (
            delivery_id => $delivery_id,
            action      => $DELIVERY_ACTION__CREATE,
            quantity    => $total_rtv,
            operator    => $operator->id,
            type_id     => $STOCK_PROCESS_TYPE__RTV,
            channel_id  => $channel_info->{id},
        );
        log_delivery( $dbh, \%args );
    }

    return;
}

1;
