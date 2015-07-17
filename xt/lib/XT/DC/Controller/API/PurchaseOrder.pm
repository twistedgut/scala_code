package XT::DC::Controller::API::PurchaseOrder;

use NAP::policy "tt", 'class';
use Data::Dump qw [ pp ];

use XTracker::Logfile 'xt_logger';

BEGIN {
    extends 'Catalyst::Controller::REST';
}

__PACKAGE__->config( path => 'api/purchase-orders', );

=head1 NAME

XT::DC::Controller::PurchaseOrder - Catalyst REST controller for purchase orders

=head1 DESCRIPTION

This controller provides a RESTful interface to purchase orders in the DC database

=head1 ACTIONS

=head2 root

=cut

sub root : Chained('/') : PathPrefix : CaptureArgs(1) {
    my ( $self, $c, $po_number ) = @_;

    # 1. Check if po can be updated - does it exist in the database
    if ( my $purchase_order =
        $c->model('DB::Public::PurchaseOrder')
        ->find( { purchase_order_number => $po_number } ) )
    {

        # 2. Get backup of PO data in XT
        $c->stash( purchase_order => $purchase_order, );
    }
    else {
        $self->status_not_found( $c,
            message =>
              "Purchase order ID: $po_number not found", );

        $c->detach;
    }
}

sub purchase_order : Chained('root') : PathPart('') : ActionClass('REST') :
  Args(0) {
}

=head2 purchase_order_GET

Retrieve the stock orders for the requested id.

Endpoint:

=over

=item * GET /api/purchase-orders/{po_num}

=back

=cut

sub purchase_order_GET {
    my ( $self, $c ) = @_;

    my $po           = $c->stash->{purchase_order};
    my $stock_orders = $po->stock_orders;

    my $data = { $po->get_columns };

    while ( my $stock_order = $stock_orders->next ) {
        push(
            @{ $data->{stock_orders} },
            $c->uri_for_action( '/api/stockorder/stock_order',
                $stock_order->id )->as_string,
        );
    }

    $c->stash( rest => $data );
}

=head2 purchase_order_PUT

Allow to update a (severely) restricted set of metadata for the PO:

=over

=item * purchase_order_number

=back

Endpoint:

=over

=item * PUT /api/purchase-orders/{po_num}

=back

=cut

sub purchase_order_PUT {
    my ( $self, $c ) = @_;

    my %request_data = %{ $c->req->data };

    # Only update to the PO number is allowed at the moment via the API
    my $purchase_order_number = delete $request_data{purchase_order_number};

    if (!defined $purchase_order_number) {
        $self->status_bad_request( $c, message => "No PO specified" );
        return;
    }

    try {
        my $po = $c->stash->{purchase_order};

        my $updated_po = $po->update({ purchase_order_number => $purchase_order_number });

        if ( !$updated_po ) {
            $self->status_bad_request( $c, message => "Couldn't update PO ".$po->purchase_order_number );
        } else {
            $c->stash(
                rest =>
                    { id => $po->purchase_order_number }
            );
        }
    } catch {
        xt_logger->logdie("PO update failed - " . $_);
    };
}

=head2 edit_purchase_order

=cut

sub core_data : Chained('root') : PathPart('core-data') : ActionClass('REST') :
  Args(0) {
    my ( $self, $c ) = @_;

# stash current purchase_order_information ( ship_date, cancel_date, shipment_windows etc )
    my $products = $c->stash->{purchase_order}->stock_orders->search(
        undef,
        {
            join   => { 'public_product' => 'price_purchase' },
            select => [
                qw(
                  me.start_ship_date
                  me.cancel_ship_date
                  me.shipment_window_type_id
                  price_purchase.original_wholesale
                  price_purchase.wholesale_price
                  me.product_id
                  me.cancel
                  )
            ],
            as => [
                qw( start_ship_date cancel_ship_date shipment_window_type_id original_wholesale wholesale_cost product_id cancelled )
            ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );

    my %products;
    while ( my $edit_purchase_order = $products->next ) {
        $products{ $edit_purchase_order->{product_id} } = {
            start_ship_date         => $edit_purchase_order->{start_ship_date},
            cancel_ship_date        => $edit_purchase_order->{cancel_ship_date},
            shipment_window_type_id =>
              $edit_purchase_order->{shipment_window_type_id},
            original_wholesale      => $edit_purchase_order->{original_wholesale},
            wholesale_price         => $edit_purchase_order->{wholesale_cost},
            cancelled               => $edit_purchase_order->{cancelled},
        };
    }
    $c->stash( existing_core_data => \%products );
}

sub core_data_GET {
    my ( $self, $c ) = @_;
    $c->stash( rest => $c->stash->{existing_core_data} );
}

sub core_data_PUT {
    my ( $self, $c ) = @_;
    my $schema = $c->model('DB')->schema;

    try {
        my $guard = $schema->storage->txn_scope_guard;

        $c->stash->{purchase_order}->update_purchase_order( $c->req->data );
        $guard->commit;
        $c->stash( rest =>
            { previous_core_data => $c->stash->{existing_core_data} }
        );
    }
    catch {
        # Failed to save purchase order information
        xt_logger->error($_);
          $self->status_bad_request( $c,
            message => 'An error occurred updating the purchase order: '
              . $_, );
    };

}

=head2 enable_edit_po_in_xt

Allows users to enable purchase orders as editable in XT.
In turn disabling the EditPO option in Fulcrum.

=cut

sub enable_edit_po_in_xt : Chained('root') : PathPart('enable-editpo-xt')
    : ActionClass('REST') : Args(0) {
    my ( $self, $c ) = @_;

    # Show if editable in XT.
    my $is_editable_in_xt = $c->stash->{purchase_order}->is_editable_in_xt;

    # Store true or false value whether PO is editable in XT.
    $c->stash( existing_po_editable_status =>
        { xt => ( $is_editable_in_xt ) ? 1 : 0 }
    );

}

sub enable_edit_po_in_xt_GET {
    my ( $self, $c ) = @_;
    $c->stash( rest => $c->stash->{existing_po_editable_status} );
}

sub enable_edit_po_in_xt_PUT {
    my ( $self, $c ) = @_;
    my $schema = $c->model('DB')->schema;

    # Attempting to change the editable status to true in XT.
    try {
        my $guard = $schema->storage->txn_scope_guard;

        # Log editpo functionality turned off in Fulcrum and turned on in XT,
        # by user x.
        xt_logger->info( sprintf(
            "User %s attempting to enable edit po in XT for purchase order number %s",
            $c->req->data->{operator_username},
            $c->stash->{purchase_order}->purchase_order_number
        ) );

        $c->stash->{purchase_order}->enable_edit_po_in_xt( $c->req->data );
        $guard->commit;

        # Log editpo functionality turned off in Fulcrum and turned on in XT,
        # by user x.
        xt_logger->info( sprintf(
            "User %s enabled edit po in XT for purchase order number %s",
            $c->req->data->{operator_username},
            $c->stash->{purchase_order}->purchase_order_number
        ) );

        $c->stash( rest =>
            { previous_po_editable_status => $c->stash->{existing_po_editable_status} }
        );
    }
    catch {
        # PO is already editable in XT.
        # Catch exception because on the fulcrum side we should not show the
        # "Make Editable in XT" button, this means we are out of sync.
        when ( match_instance_of('NAP::XT::Exception::EditPO::PurchaseOrderAlreadyEditable') ) {
            xt_logger->error( sprintf(
                "Error user unable to make po editable in XT for purchase order number %s, %s",
                $c->req->data->{operator_username},
                $c->stash->{purchase_order}->purchase_order_number,
                $_
            ) );

            $self->status_bad_request( $c,
                message => 'EditPO api error: '
                . $_, );
        }
        default {
            xt_logger->logdie($_);
        }
    };

}

=head1 SEE ALSO

L<XT::DC>, L<Catalyst::Controller::REST>, L<Catalyst::Controller>

=head1 AUTHOR

Pete Smith,
Minesh Patel,
Nélio Nunes

=cut

