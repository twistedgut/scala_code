package XT::DC::Controller::API::Product;

use NAP::policy "tt", 'class';

use Data::Dump qw [ pp ];
use XT::Domain::Product::Sizing;
use XTracker::Logfile 'xt_logger';

BEGIN {
    extends 'Catalyst::Controller::REST';
}

__PACKAGE__->config( path => 'api/products', );

has sizing_data => ( is => 'rw', isa => 'HashRef' );

=head1 NAME

XT::DC::Controller::Product - Catalyst REST controller for product

=head1 DESCRIPTION

This controller provides a RESTful interface to products in the DC database.

=head1 ACTIONS

=head2 root

=cut

sub root : Chained('/') : PathPrefix : CaptureArgs(0) {
}

=head2 classification

    Updates the classification data for a set of products

=cut

sub classification : Chained('root') : PathPart('classification') :
  ActionClass('REST') : Args(0) {
    my ( $self, $c ) = @_;

    # Checking if this is a first update attempt or a rollback
    my $ref;
    if ( $c->req->data->{previous_classification_data} ) {

        #We have a rollback here
        $c->stash->{is_rollback} = 1;
        $ref = $c->req->data->{previous_classification_data};
    }
    else {
        $ref = $c->req->data;
    }

    # Getting a resultset for all the PID's contained in our PO
    my $products_rs =
      $c->model('DB::Public::Product')->search( { id => [ keys(%$ref) ] } );

    # We found less products that we were expecting, so we cannot continue
    unless ( $products_rs->count() == scalar( keys(%$ref) ) ) {
        $self->status_not_found( $c,
                message => "Expecting to find "
              . scalar( keys(%$ref) )
              . " products but found only "
              . $products_rs->count()
              . " - update not possible" );
        $c->detach;
    }

    # stash current classification data
    while ( my $product = $products_rs->next() ) {
        $c->stash->{existing_classification_data}->{ $product->id } = {
            classification_id => $product->classification_id,
            sub_type_id       => $product->sub_type_id,
            product_type_id   => $product->product_type_id,
            classification => $product->classification->classification,
            sub_type       => $product->sub_type->sub_type,
            product_type   => $product->product_type->product_type,
        };
        push @{ $c->stash->{products} }, $product;
    }
}

sub classification_GET {
    my ( $self, $c ) = @_;

    $c->stash( rest => $c->stash->{existing_classification_data} );
}

sub classification_PUT {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB')->schema;

    my $is_rollback = $c->stash->{is_rollback} || 0;

    try {
        my $guard = $schema->storage->txn_scope_guard;
        foreach my $product ( @{ $c->stash->{products} } ) {
            my $product_args;
            if ($is_rollback) {

# Incoming data is the original rollback data, so we don't need to lookup anything
                $product_args = $c->req->data->{ $product->id };
            }
            else {
                for my $prod_field (qw(classification product_type sub_type)) {
                    $product_args->{"${prod_field}_id"} = eval {
                        $schema->lookup_dictionary_by_name( $prod_field,
                            $c->req->data->{ $product->id }->{$prod_field} );
                    }
                      || $schema->lookup_dictionary_by_name( $prod_field,
                        'Unknown' );
                }
            }
            $product->update($product_args);
        }
        $guard->commit;
    }
    catch {

        # Failed to save classification information
        xt_logger->error($_);
          $self->status_bad_request( $c,
            message =>
              'An error occurred updating a product classification data: '
              . $_, );
      };

      $c->stash(
        rest => {
            previous_classification_data =>
              $c->stash->{existing_classification_data}
        }
      );
}

=head2 sizing

Deals with editing of sizes and quantities, including size scheme changes.

This is called by edit purchase orders in Fulcrum.

The sizing handler sets up the "backup" of the existing state in XT, that will
be returned by either sizing_GET (just to get the state of XT) or by
sizing_PUT (to return the state of XT before the PUT changed things, for
rollback if another DC XT update fails and the whole thing needs to be backed out)

=cut

sub sizing : Chained('root') : PathPart('sizing') : ActionClass('REST') :
  Args(0) {
    my ( $self, $c ) = @_;

    if (not defined $c->request->data) {
        # we've probably sent junkover
        # stepping through the debugger gave this:
        #    'garbage after JSON object, at character offset 8 (before ":
        #    {"purchase_orders"...") at
        #    /opt/xt/xt-perl/lib/site_perl/Catalyst/Action/Deserialize/JSON.pm
        #    line 38, <$fh> line 1.
        $self->status_bad_request( $c, message => 'No data; did you send junk?' );
        $c->detach;
    }

    # TODO: Is this necessary? The rollback data should really be sent in exactly the same
    # format as the editing operation data.
    $self->sizing_data(
        $c->req->data->{previous_sizing_data}
      ? $c->req->data->{previous_sizing_data}
      : $c->req->data
    );

    try {

        my $domain_model = XT::Domain::Product::Sizing->new({
            schema => $c->model('DB')->schema,
            log => xt_logger,
        });

        $c->stash->{product_sizing_domain_model} = $domain_model;

        $c->stash->{existing_sizing_data} = $domain_model->sizing_state( $self->sizing_data );

    }
    catch {
            when (/^Product Not Found/) {
                # Create a 404 error because a product being requested was not found
                # (this is the product API)
                $self->status_not_found( $c, message => $_ );
            }
            when (/^Validation Failed/) {
                # Create a 400 error for general validation failures
                $self->status_bad_request( $c, message => $_ );
            }
            default {
                # Create a 500 error for internal / unexpected failures
                die "Sizing caught unexpected exception: $_";
            }
        $c->detach;
    };
}

=head2 sizing_GET

Return the current state of a product's sizing and quantities in stock orders from
XT.

=cut

sub sizing_GET {
    my ( $self, $c ) = @_;
    # The existing state of the sizing data will be returned to the caller.
    $c->stash( rest => $c->stash->{existing_sizing_data} );
}

=head2 sizing_PUT

Update a product's sizing and stock order quantities in XT.
Returns the PREVIOUS state to allow rollbacks in the case of other DC XT updates failing.

There are two different routes depending on if the size scheme has changed or not.

A variety of checks will be carried out before changes are made, and a transaction will be created and rolled back on error.

Errors with the data in the request will be reported as 404 Not Found (can't find the product), 400Bad Request (other consistency checks).

Internal checks that "shouldn't happen" will be reported as 500 Server Error.

=cut

sub sizing_PUT {
    my ( $self, $c ) = @_;

    my $product_sizing_domain_model = $c->stash->{product_sizing_domain_model};

    my $pids_processed;

    my $schema = $c->model('DB')->schema;
    try {

        my $guard = $schema->storage->txn_scope_guard;

        $pids_processed =
            $product_sizing_domain_model->update_sizing( $self->sizing_data );

        $guard->commit;
        # Size scheme was changed for product, send sizing message to Product Service
        for my $pid ( @{ $pids_processed->{size_scheme_updated} } ) {
            $product_sizing_domain_model
              ->update_product_service_with_sizing_update($pid);
        }
        # Size quantities were updated only, send stockleveldetail message to Product Service
        for my $pid ( @{ $pids_processed->{size_quantities_updated} } ) {
            my $product = $schema->resultset('Public::Product')->find( $pid );

            next unless $product;
            for my $po_number ( keys %{$self->sizing_data->{$pid}->{purchase_orders}} ) {
                my $purchase_order = $schema->resultset('Public::PurchaseOrder')->search(
                    {
                            purchase_order_number => $po_number,
                    }
                )->first;

                next unless $purchase_order;

                $product_sizing_domain_model
                  ->update_product_service_with_stock_detail_level_update(
                    $product->id, $purchase_order->channel_id );
            }
        }

    }
    catch {
        # Error handling

        xt_logger->error( "Error when updating sizing: $_" );

        # Detect errors requiring different status codes
        given ($_) { # this prevents the when/default from leaving the block
            when ( /^Validation Failed/ ) {
                # Creates a 400 response
                $self->status_bad_request(
                    $c,
                    message => "An error occurred updating the sizing: $_",
                );
            }
            default {
                # Creates a 500 'Server Error' response as we did not recognise
                # the error type.
                $c->response->status(500);
                # We are using xt_logger here because $c->log does not seem
                # to log anywhere. Investigate in WHM-3133 and/or PM-2004
                xt_logger->debug( "Server Error: ". $_ ) if $c->debug;
                # Ensure the error is a string before it is passed to be
                # JSONified. Putting it in quotes ensures that a raw string OR
                # object will be stringified in the way it was intended.
                # See PM-1981.
                $self->_set_entity( $c, { error => "$_" } );
            }
        }

        # After encountering any error, stop further processing.
        # If there's ever a recoverable error, it will have to be caught
        # in a different catch block, or somehow skip over this detach.
        $c->detach;
    };
    # Back to normal processing
    $c->stash(
        rest => {
            previous_sizing_data => $c->stash->{existing_sizing_data},
            skipped_pids => [ @{ $pids_processed->{skipped} } ],
        },
    );
}

=head1 SEE ALSO

L<XT::DC>, L<Catalyst::Controller::REST>, L<Catalyst::Controller>

=head1 AUTHOR

Pete Smith,
Minesh Patel,
Nélio Nunes

=cut

