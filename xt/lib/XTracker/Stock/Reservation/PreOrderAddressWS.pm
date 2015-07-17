package XTracker::Stock::Reservation::PreOrderAddressWS;

use strict;
use warnings;

use XTracker::Config::Local             qw(
                                            config_var
                                            get_postcode_required_countries_for_preorder
                                            get_required_address_fields_for_preorder
                                        );
use XTracker::Logfile                   qw( xt_logger );
use XTracker::Constants::Ajax           qw( :ajax_messages );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_address_types );
use XTracker::Constants::Address        qw( :address_ajax_messages :address_types );
use XTracker::Database::Address;

use Try::Tiny;
use Plack::App::FakeApache1::Constants qw(:common HTTP_METHOD_NOT_ALLOWED);
use JSON;

use XTracker::Error;


my $logger = xt_logger(__PACKAGE__);

=head1 NAME

XTracker::Stock::Reservation::PreOrderAddressWS

=head1 METHODS

=head2 handler

This is not a true restful API. Shame on me!

=cut

sub handler {
    my $handler = XTracker::Handler->new(@_);
    my $ajax = __PACKAGE__->new($handler);

    my $result = $ajax->process();


    if ($result == OK) {
        $handler->{r}->print(
            encode_json($handler->{data}{output})
        );
    }

    return $result;
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler,
    };

    return bless($self, $class);
}

=head2 process

Process the correct http method.

Returns a Hash of values

=cut

sub process {
    my $self = shift(@_);

    if ($self->{handler}{r}->method eq 'GET') {
        $self->{handler}{data}{output} = $self->order_address_GET($self);
        return OK;
    }
    elsif ($self->{handler}{r}->method eq 'POST') {
        $self->{handler}{data}{output} = $self->order_address_POST($self);
        return OK,
    }
    else {
        return HTTP_METHOD_NOT_ALLOWED;
    }
}

=head2 order_address_GET

This returns address data when a 'address_id' parameter is present.

Returns a Hash of values

=cut

sub order_address_GET {
    my ($self) = @_;

    my $handler = $self->{handler};
    my $output = {};

    if ($handler->{param_of}{address_id}) {
        $logger->debug('An address_id was provided so lets use that');

        try {
            my $address = $handler->schema->resultset('Public::OrderAddress')->find($handler->{param_of}{address_id});

            $output = {
                address_id     => $address->id,
                first_name     => $address->first_name,
                last_name      => $address->last_name,
                address_line_1 => $address->address_line_1,
                address_line_2 => $address->address_line_2,
                address_line_3 => $address->address_line_3,
                towncity       => $address->towncity,
                postcode       => $address->postcode // '',
                county         => $address->county,
                country        => $address->country,
            }
        }
        catch {
            $handler->{data}{output} = $self->_generate_error($ADDRESS_AJAX_MESSAGE__CANT_FIND_ADDRESS_ID);
        };
    }

    return $self->_generate_ok($output);
}

=head2 order_address_POST

This will create a new Address and, optionally, attach it to an Order or PreOrder.

TODO: Attach address to an Order.

=cut

sub order_address_POST {
    my ($self) = @_;

    my $handler = $self->{handler};
    my $order;
    my $customer;
    my $channel;
    my $address;

    my $output = {};

    if ($handler->{param_of}{address_id}) {
        $logger->debug('Address id provided so lets use that');
        my $err;
        try {
            $address = $handler->schema->resultset('Public::OrderAddress')->find($handler->{param_of}{address_id});
            $err = 0;
        }
        catch {
            $err = $self->_generate_error($ADDRESS_AJAX_MESSAGE__CANT_FIND_ADDRESS_ID);
        };
        return $err if $err;
    }
    else {
        $logger->debug('Creating new address in database');

        my @missing_fields = _check_fields( $handler );
        return $self->_generate_error( "The following are required:\n\n" . join( "\n", @missing_fields ) )
            if @missing_fields;

        my %address_data = (
            first_name     => $handler->{param_of}{'first_name'},
            last_name      => $handler->{param_of}{'last_name'},
            address_line_1 => $handler->{param_of}{'address_line_1'},
            address_line_2 => $handler->{param_of}{'address_line_2'} || '',
            address_line_3 => $handler->{param_of}{'address_line_3'} || '',
            towncity       => $handler->{param_of}{'towncity'},
            postcode       => $handler->{param_of}{'postcode'} // '',
            county         => $handler->{param_of}{'county'} || '',
            country        => $handler->{param_of}{'country'},
        );

        my $err;
        try {
            $address = $handler->schema->resultset('Public::OrderAddress')->create({
                %address_data,
                address_hash => hash_address($handler->dbh, {%address_data}),
            });
            $err = 0;
        }
        catch {
            $logger->warn($_);
            $err = $self->_generate_error($ADDRESS_AJAX_MESSAGE__CANT_CREATE_ADDRESS);
        };
        return $err if $err;
    }

    _check_for_valid_county_in_shipping_address( $handler->{param_of}, $address );

    $output->{used_for_both} = $handler->{param_of}{use_for_both};
    $output->{address} = {
        address_id     => $address->id,
        first_name     => $address->first_name,
        last_name      => $address->last_name,
        address_line_1 => $address->address_line_1,
        address_line_2 => $address->address_line_2,
        address_line_3 => $address->address_line_3,
        towncity       => $address->towncity,
        postcode       => $address->postcode,
        county         => $address->county,
        country        => $address->country,
    };

    if ($handler->{param_of}{pre_order_id}) {
        $logger->debug('A pre_order_id was provided so lets use that');

        my $pre_order;
        my $err;
        try {
            $pre_order = $handler->schema->resultset('Public::PreOrder')->find($handler->{param_of}{pre_order_id});
            $err = 0;
        }
        catch {
            $logger->warn($_);
            $err = $self->_generate_error($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
        };
        return $err if $err;

        $handler->{data}{sales_channel} = $pre_order->customer->channel->name;
        $handler->{data}{customer}      = $pre_order->customer;
        $customer                       = $pre_order->customer;

        unless ($handler->{param_of}{address_type}) {
            $logger->debug('Nothing to update');
            return $self->_generate_error($ADDRESS_AJAX_MESSAGE__NO_ADDRESS_TYPE_PROVIDED);
        }

        unless ((uc($handler->{param_of}{address_type}) eq uc($ADDRESS_TYPE__SHIPMENT)) || uc($handler->{param_of}{address_type}) eq uc($ADDRESS_TYPE__INVOICE)) {
            return $self->_generate_error($ADDRESS_AJAX_MESSAGE__UNKNOWN_ADDRESS_TYPE_PROVIDED);
        }

        if ((uc($handler->{param_of}{address_type}) eq uc($ADDRESS_TYPE__SHIPMENT)) || $handler->{param_of}{use_for_both}) {
            $logger->debug('Updating shipment address');
            try {
                $pre_order->update({
                    shipment_address_id => $address->id,
                });
                $err = 0;
            }
            catch {
                $logger->warn($_);
                $err = $self->_generate_error($ADDRESS_AJAX_MESSAGE__CANT_UPDATE_ORDER_ADDRESS);
            };
            return $err if $err;
        }

        if ((uc($handler->{param_of}{address_type}) eq uc($ADDRESS_TYPE__INVOICE)) || $handler->{param_of}{use_for_both}) {
            $logger->debug('Updating invoice address');
            try {

                $pre_order->update({
                    invoice_address_id => $address->id,
                });
                $err = 0;
            }
            catch {
                $logger->warn($_);
                $err = $self->_generate_error($ADDRESS_AJAX_MESSAGE__CANT_UPDATE_ORDER_ADDRESS);
            };
            return $err if $err;
        }

        $output->{pre_order_id} = $pre_order->id;
    }
    else {
        $logger->debug('Neither order_id nor pre_order_id was provided.');
    }

    return $self->_generate_ok($output);
}


sub _generate_error {
    my ($self, $error, $data) = @_;
    $data = {} unless ($data);
    my $output = {
        %{$data},
        ok     => 0,
        errmsg => $error,
    };
    return $output;
}

sub _generate_ok {
    my ($self, $data) = @_;
    return {
        %{$data},
        ok     => 1,
    }
}


# This function checks to see (for Shipping Addresses only) that the 'county/state' used
# in the Address is one of the Sub-Divisions that are linked to the Country. If not a
# warning will be given to the Operator but they can still continue with the Pre-Order.
#
# This was done to cope with Hong Kong Premier Addresess where the 'county' is used
# ultimately by Route Monkey to route the Premier Vans and it's mainly here so that if a
# historic Address is used which didn't have the 'county' filled in properly to match the
# Hong Kong Sub-Divisions which were added for the HKP Project then a message can be shown
# to the Operator so that they can correct it which will then allow the Premier Shipping
# Options to be shown on the Pre-Order Basket page which they can then select for the Order.
sub _check_for_valid_county_in_shipping_address {
    my ( $params, $address ) = @_;

    # don't care so much about Invoice Addresses
    return      unless( uc( $params->{address_type} // '' ) eq uc( $ADDRESS_TYPE__SHIPMENT ) || $params->{use_for_both} );

    # this failing should not stop the whole process
    eval {
        my $countries_to_check = config_var('countries_with_districts_for_ui', 'country' ) // [];
        $countries_to_check    = ( ref( $countries_to_check ) ? $countries_to_check : [ $countries_to_check ] );

        # check if the Country is one that we expect to have Sub-Divisions for
        if ( grep { lc( $_ ) eq lc( $address->country ) } @{ $countries_to_check } ) {
            # check that if there are any Sub-Divisions for the Country that the
            # 'county' is one of them, if not use 'xt_warn' to show a message
            my $county = $address->county // '';
            my $country_sub_divisions_rs = $address->country_ignore_case
                                                    ->country_subdivisions;
            my $count = $country_sub_divisions_rs->search(
                {
                    -or => [
                        { iso  => $county },
                        { name => $county },
                    ],
                }
            )->count;

            if ( !$count ) {
                xt_warn(
                    "WARNING: The 'State/County' of the Shipment Address is not one of the options for '" . $address->country . "' "
                  . "you might want to re-check the Address because some Shipping Options might be unavailable "
                  . "(this will not prevent you from continuing)."
                );
            }
        }
    };

    return;
}

sub _check_fields {
    my ( $handler ) = @_;

    my @required_fields     = @{ get_required_address_fields_for_preorder() };
    my @postcode_countries  = @{ get_postcode_required_countries_for_preorder() };
    my $country             = $handler->{param_of}{'country'};

    if( grep { /^$country$/ } @postcode_countries ) {
        push(@required_fields, 'postcode');
    }

    my %field_map = (
        first_name      => 'First Name',
        last_name       => 'Last Name',
        address_line_1  => 'Address Line 1',
        address_line_2  => 'Address Line 2',
        towncity        => 'City',
        postcode        => 'Postcode',
        county          => 'County',
        country         => 'Country',
    );

    return
        map     { $field_map{ $_ } }
        grep    { ! $handler->{param_of}{$_} }
        @required_fields;

}

1;
