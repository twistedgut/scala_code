package XTracker::Schema::ResultSet::Public::Orders;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp qw( croak );
use XTracker::Constants::FromDB     qw(
                                        :shipment_class
                                        :shipment_item_status
                                        :order_status
                                        :flag
                                    );

=head1 NAME

XTracker::Schema::ResultSet::Public::Orders

=head1 METHODS

=over

=item B<get_order_billing_details($id)>

TODO

=cut

sub get_order_billing_details {

    my ( $resultset, $id ) = @_;

    return $resultset->find(
        {
                'id'            => $id,
        },
        {
                'join'          => [ qw( currency order_address channel ) ],
                '+select'       => [ qw( currency.currency order_address.first_name order_address.last_name order_address.address_line_1 order_address.address_line_2 order_address.towncity order_address.county order_address.country order_address.postcode channel.name ) ],
                '+as'           => [ qw( currency first_name last_name address_line_1 address_line_2 towncity county country postcode sales_channel ) ],
                'prefetch'      => [ qw( currency order_address channel ) ]
        }
    );
}

=item B<not_cancelled>

Returns a resultset containing orders with an order_status of anything other
than cancelled.

=cut

sub not_cancelled {
    my $self = shift;

    return $self->search( { 'order_status_id' => { '!=' => $ORDER_STATUS__CANCELLED } } );
}

=item B<get_search_results_by_shipment_id_rs>

    $result_set = $self->get_search_results_by_shipment_id_rs( $shipment_id_array_ref );

Given a list of Shipment Ids, this will return a Result Set where 'orders' is the primary
table but also gets the following additional columns that will be available via the
'get_column' method upon each record returned:

    first_order_flag
    order_currency
    first_name
    last_name
    customer_category_id
    customer_category
    customer_class_id
    customer_class
    channel_name
    channel_config_section
    shipment_id
    shipment_class_id
    shipment_class
    shipment_type_id
    shipment_type
    shipment_status_id
    shipment_status

=cut

sub get_search_results_by_shipment_id_rs {
    my ( $self, $shipment_ids ) = @_;

    # get the current alias, most likely to be 'me'
    my $me = $self->current_source_alias;

    # set-up sub-query that looks for the
    # 1st Order Flag if the Order has one
    my $order_flag_rs = $self->result_source->schema->resultset('Public::OrderFlag');
    my $first_order_flag_rs = $order_flag_rs->search(
        {
            'order_flag.orders_id' => { '=' => \"${me}.id" },
            'order_flag.flag_id'   => $FLAG__1ST,
        },
        {
            'select' => [ qw( id ) ],
            'as'     => [ qw( order_flag_id ) ],
            alias    => 'order_flag',
        }
    );

    my $rs = $self->search(
        {
            'shipment.id' => { IN => $shipment_ids },
        },
        {
            '+select' => [
                $first_order_flag_rs->as_query,
                qw(
                    currency.currency
                    customer.first_name
                    customer.last_name
                    customer.category_id
                    category.category
                    customer_class.id
                    customer_class.class
                    channel.name
                    business.config_section
                    shipment.id
                    shipment.shipment_class_id
                    shipment_class.class
                    shipment.shipment_type_id
                    shipment_type.type
                    shipment.shipment_status_id
                    shipment_status.status
                    shipment_address.country
                )
            ],
            '+as'     => [ qw(
                first_order_flag
                order_currency
                first_name
                last_name
                customer_category_id
                customer_category
                customer_class_id
                customer_class
                channel_name
                channel_config_section
                shipment_id
                shipment_class_id
                shipment_class
                shipment_type_id
                shipment_type
                shipment_status_id
                shipment_status
                shipment_country
            ) ],
            join => [
                'currency',
                {
                    channel => 'business',
                },
                {
                    customer => {
                        category => 'customer_class',
                    }
                },
                {
                    link_orders__shipments => {
                        shipment => [ qw(
                            shipment_class
                            shipment_type
                            shipment_status
                            shipment_address
                        ) ],
                    },
                },
            ],
        }
    );

    return $rs
}


=back

=cut

use Moose;
with 'XTracker::Schema::Role::ResultSet::FromText' => { field_name => 'order_nr' };
no Moose;

1;
