package XT::DC::Controller::API::Customer;
use NAP::policy qw( tt class );

BEGIN { extends 'NAP::Catalyst::Controller::REST'; }

__PACKAGE__->config( path => 'api/customer', );

=head1 NAME

XT::DC::Controller::API::Customer - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use XTracker::Logfile       qw( xt_logger );

use XTracker::Database::Utilities       qw( is_valid_database_id );


=head1 METHODS

=head2 customer

    /api/customer/[customerId]

This is the start of the chain and will take the Customer Id
out of the URL and get the Customer Record to be used further
down the chain.

=cut

sub customer : Chained('/') : PathPrefix : CaptureArgs(1) {
    my ( $self, $c, $customer_id ) = @_;

    unless ( $c->check_access( 'Customer Care', 'Order Search' ) ) {
        $self->status_unauthorized( $c );
        $c->detach;
    }

    if ( !is_valid_database_id( $customer_id ) ) {
        $self->status_bad_request( $c, message => "Not a valid ID: ${customer_id}" );
        $c->detach;
    }

    my $detach = 0;

    try {
        if ( my $customer = $c->model('DB::Public::Customer')->find( $customer_id ) ) {
            $c->stash(
                customer => $customer,
            );
        }
        else {
            $self->status_not_found( $c, message => "Couldn't find ID: ${customer_id}" );
            $detach = 1;
        }
    } catch {
        xt_logger->warn( "With Id: '" . ( $customer_id // 'undef' ) . "', couldn't get Customer: " . $_ );
        $self->status_internal_server_error( $c, { message => "Error using ID: '" . ( $customer_id // 'undef' ) . "'" } );
        $detach = 1;
    };

    $c->detach      if ( $detach );
}

=head2 address_list

    /api/customer/[customerId]/address_list

Return a JSON Hash of the Customer's Addresses. This will communicate
with Seaview to get the list of Addresses, if that fails or the Customer
doesn't have a Seaview account then the local 'order_address' table will
be used.

The Hash will be keyed on either the Address 'guid' if from Seaview or the
'urn' if from the 'order_address' table.

=cut

sub address_list : Chained('customer') : PathPart('address_list') : ActionClass('REST') { }

sub address_list_GET {
    my ( $self, $c ) = @_;

    my $customer = $c->stash->{customer};

    try {
        # get the Customer's Addresses
        my $addresses = $customer->get_seaview_or_local_addresses( { stringify_objects => 1 } );
        if ( $addresses ) {
            $self->status_ok( $c, entity => $addresses );
        }
        else {
            $self->status_not_found( $c, message => "Couldn't find any Addresses for Customer ID: " . $customer->id );
        }
    } catch {
        xt_logger->warn( "Customer Id: '" . $customer->id . "', Couldn't get Addresses: " . $_ );
        $self->status_internal_server_error( $c, { message => "Error Getting Customer's Addresses"  } );
    };
}


=encoding utf8

=head1 AUTHOR

Andrew Beech

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

