package XT::DC::Controller::CustomerCare::Customer;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

XT::DC::Controller::CustomerCare::Customer - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

use Try::Tiny;
use XTracker::Logfile                   qw(
                                            xt_logger
                                        );
use XTracker::Database::Customer        qw(
                                            match_customer
                                        );


# Used for the on the Customer View page to
# show the Customer Value to the User
sub customer_value : Local ActionClass('REST') {
    my ($self, $c)  = @_;

    # You should be-able to see Customer Search to use this feature
    $c->check_access('Customer Care', 'Customer Search');

    # see which format the requester wants the data in, default to JSON
    # NOTE: can only support JSON at the moment
    my $data_format     = lc( $c->req->param('format') || 'json' );

    # get a customer record
    my $cust_id = $c->req->param('customer_id');
    my $customer;
    eval {
        $customer = $c->model('DB::Public::Customer')->find( $cust_id )
    };
    if ( !defined $customer ) {
        # Couldn't find a Customer Record so Return
        $c->stash( "$data_format" => {
                            error   => "Couldn't find a Customer Record for Id: " . ( $cust_id || "" ),
                    } );
        $c->detach('/serialize');
    }

    $c->stash(
                data_format => $data_format,
                customer    => $customer,
            );
}

# Make this a POST so IE doesn't cache it
sub customer_value_POST {
    my ($self, $c)  = @_;

    my $data_format = delete $c->stash->{data_format};
    my $customer    = delete $c->stash->{customer};
    my $schema      = $c->model('DB')->schema;
    my $data;

    my %cust_value;

    # get any other customer records that might exist
    # on other Sales Channels for the Customer
    my $other_channels  = match_customer( $schema->storage->dbh, $customer->id );

    # get the Customer Value for the Customer
    my $value   = $customer->calculate_customer_value;
    %cust_value = %{ $value };

    try {
        # Update the customer value in Seaview.
        $customer->update_customer_value_in_service( $value );
    } catch {
        my $error = $_;
        xt_logger->info( "Failed to update customer value in Seaview: $error" );
    };

    # loop through other customer records for other
    # Sales Channels and get their Customer Value also
    foreach my $cust_id ( @{ $other_channels } ) {
        my $other_customer  = $schema->resultset('Public::Customer')->find( $cust_id );
        $value              = $other_customer->calculate_customer_value;

        # copy it into the HASH
        %cust_value = ( %{ cust_value }, %{ $value } );
    }

    $c->stash( $data_format => \%cust_value );
    $c->forward('/serialize');
}


=head1 AUTHOR

Andrew Beech

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
