use utf8;
package XTracker::Schema::Result::Public::Customer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_id_seq",
  },
  "is_customer_number",
  { data_type => "integer", is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "first_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "last_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "modified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "telephone_1",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "telephone_2",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "telephone_3",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "group_id",
  { data_type => "smallint", default_value => 1, is_nullable => 0 },
  "ddu_terms_accepted",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "legacy_comment",
  { data_type => "text", is_nullable => 1 },
  "credit_check",
  { data_type => "timestamp", is_nullable => 1 },
  "no_marketing_contact",
  { data_type => "timestamp", is_nullable => 1 },
  "no_signature_required",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "prev_order_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "correspondence_default_preference",
  { data_type => "boolean", is_nullable => 1 },
  "account_urn",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_idx_is_customer_number__channel_id",
  ["is_customer_number", "channel_id"],
);
__PACKAGE__->belongs_to(
  "category",
  "XTracker::Schema::Result::Public::CustomerCategory",
  { id => "category_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "customer_actions",
  "XTracker::Schema::Result::Public::CustomerAction",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "customer_attribute",
  "XTracker::Schema::Result::Public::CustomerAttribute",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_correspondence_method_preferences",
  "XTracker::Schema::Result::Public::CustomerCorrespondenceMethodPreference",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "customer_credit",
  "XTracker::Schema::Result::Public::CustomerCredit",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_credit_logs",
  "XTracker::Schema::Result::Public::CustomerCreditLog",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_csm_preferences",
  "XTracker::Schema::Result::Public::CustomerCsmPreference",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_flags",
  "XTracker::Schema::Result::Public::CustomerFlag",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_notes",
  "XTracker::Schema::Result::Public::CustomerNote",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_service_attribute_logs",
  "XTracker::Schema::Result::Public::CustomerServiceAttributeLog",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_customer_segment__customers",
  "XTracker::Schema::Result::Public::LinkMarketingCustomerSegmentCustomer",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.customer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.customer_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mssPIN3kNQgeZMkRdQ0VXQ

__PACKAGE__->add_unique_constraint(unique_channel_customer_number => [qw(channel_id is_customer_number )]);

use Moose;
with 'XTracker::Schema::Role::CSMPreference',
     'XTracker::Schema::Role::CanUseCSM',
     'XTracker::Schema::Role::Hierarchy';

use Carp qw/ croak /;
use JSON qw/ encode_json /;

use XTracker::Logfile       qw( xt_logger );

use XTracker::SchemaHelper qw(:records);
use XTracker::Constants::FromDB qw(
    :customer_category
    :customer_class
    :flag
    :order_status
    :shipment_status
    :service_attribute_type
);

use XTracker::Constants::Seaview qw( :seaview_failure_messages );
use XTracker::Config::Local qw( config_var sys_config_var );

use XTracker::DBEncode qw(encode_db decode_db);

use XT::Net::Seaview::Client;
use XT::Net::Seaview::Utils;
use XT::Domain::Payment;
use Try::Tiny;
use HTTP::Status qw( :constants );
use Scalar::Util qw( blessed );

use XTracker::Utilities          qw( obscure_card_token );

use XTracker::Database::Customer qw( get_customer_value );
use XTracker::Database::Address  qw( add_addr_key );


__PACKAGE__->has_many(
    'orders' => 'Public::Orders',
    { 'foreign.customer_id' => 'self.id' },
);
__PACKAGE__->many_to_many(
    'reserved_variants', reservations => 'variant',
);

__PACKAGE__->load_components('FilterColumn');
foreach(qw/title first_name last_name email/) {
    __PACKAGE__->filter_column( $_ => {
        filter_from_storage => sub { decode_db($_[1]) },
        filter_to_storage => sub { encode_db($_[1]) },
    });
}

=head1 METHODS

=cut

sub pws_customer_id {
  # This is perhaps one of the most stupidly named columns of all time:
  #   "is" means "internet side" or some such apparently, not an indication of
  #   a predicate
  $_[0]->is_customer_number;
}

sub display_name {
  join(' ', $_[0]->first_name, $_[0]->last_name );
}

# to tell if a Customer is an EIP it's probably safest
# to use the 'is_an_eip' method which looks at the
# Category Class which contains many EIP Categories
sub is_category_eip_premium {
    return $_[0]->category_id == $CUSTOMER_CATEGORY__EIP_PREMIUM;
}

# to tell if a Customer is an EIP it's probably safest
# to use the 'is_an_eip' method which looks at the
# Category Class which contains many EIP Categories
sub is_category_eip {
    return $_[0]->category_id == $CUSTOMER_CATEGORY__EIP;
}

=head2 is_an_eip

    $boolean    = $customer->is_an_eip;

This returns TRUE if the Customer's Category has a Customer Class of EIP and so
covers many EIP Customer Categories.

=cut

sub is_an_eip {
    my $self    = shift;
    return ( $self->customer_class_id == $CUSTOMER_CLASS__EIP ? 1 : 0 );
}

sub is_category_ip {
    return $_[0]->category_id == $CUSTOMER_CATEGORY__IP;
}

sub is_category_hot_contact {
    return $_[0]->category_id == $CUSTOMER_CATEGORY__HOT_CONTACT;
}

sub is_category_staff {
    return $_[0]->category_id == $CUSTOMER_CATEGORY__STAFF;
}

=head2 customer_class_id

    $customer_class_id = $self->customer_class_id;

Returns the Customer's Category Class Id.

=cut

sub customer_class_id {
    my $self    = shift;
    return $self->category->customer_class_id;
}

=head2 customers_with_same_email

Find customer records that have same email ignoring case

=cut

sub customers_with_same_email {
    my($self) = @_;
    my $schema = $self->result_source->schema;
    # taken from
    # http://search.cpan.org/~arodland/DBIx-Class-0.08196/lib/DBIx/Class/Manual/Cookbook.pod#Using_SQL_functions_on_the_left_hand_side_of_a_comparison
    # I don't know if there's a better syntax for this:
    my $set = $schema->resultset('Public::Customer')->search({
        -and => [
            id => { '!=' => $self->id },
            \[ 'LOWER(email) = LOWER(?)', [ plain_value => $self->email ] ],
        ],
    });
    return $set;
}

=head2 has_finance_watch_flag

Customer has a Finance Watch Flag associated

=cut

sub has_finance_watch_flag :Export(:DEFAULT) {
    my($self) = @_;
    my $flags = $self->customer_flags->search({
        flag_id => $FLAG__FINANCE_WATCH,
    });

    if (!defined $flags || $flags->count == 0) {
        return 0;
    }

    return 1;
}

=head2 reservations_by_variant_id ($variant_id)

Returns customers reservations for supplied $variant_id

=cut

sub reservations_by_variant_id {
    my $self = shift;
    my $variant_id = shift;

    return $self->reservations->uploaded->by_variant( $variant_id );
}

=head2 related_orders_in_status

Search related orders for a particular status

=cut

sub related_orders_in_status {
    my($self,$status_id) = @_;

    return $self->search_related('orders',{
        order_status_id => $status_id,
    });
}

=head2 credit_check_orders

Credit Check orders associated with the customer

=cut

sub credit_check_orders {
    my($self) = @_;

    return $self->related_orders_in_status( $ORDER_STATUS__CREDIT_CHECK );
}

=head2 credit_hold_orders

Credit Hold orders associated with the customer

=cut

sub credit_hold_orders {
    my($self) = @_;

    return $self->related_orders_in_status( $ORDER_STATUS__CREDIT_HOLD );
}

=head2 orders_aged( '1 day' )

Search related orders for a given age based on order.date. Defaults to no age
constraints

=cut

sub orders_aged {
    my($self,$age) = @_;
    my $constr;

    if (defined $age) {
        $constr = {
            'age(me.date)' => { '<' => $age },
        };
    }

    return $self->search_related('orders', $constr);
}

=head2 add_order

    my $order = $customer->add_order( $order )

Pass an L<XT::Data::Order> object to a customer row to create a new order
for that customer.

Returns the new order row.

=cut

sub add_order {
    my ( $self, $order ) = @_;

    croak 'Order object required'
        unless $order and ref( $order ) eq 'XT::Data::Order';

    my $order_rs = $self->result_source->schema->resultset('Public::Orders');

    my $language_rs
        = ($order->language_preference ? $self->result_source->schema->resultset('Public::Language')->get_language_from_code($order->language_preference) : undef);

    # FIXME it is absolutely horrid that some columns are NOT NULL even
    # though all we enter is ''. They REALLY should be changed.
    my $order_row = $order_rs->create({
        order_nr                => $order->order_number,
        basket_nr               => $order->order_number,
        invoice_nr              => '',
        session_id              => '',
        cookie_id               => '',
        date                    => $order->order_date,
        total_value             => $order->gross_total->value,
        gift_credit             => $order->extract_money( 'gift_credit' ),
        store_credit            => $order->extract_money( 'store_credit' ),
        customer_id             => $self->id,
        credit_rating           => 1,
        card_issuer             => '-',
        card_scheme             => '-',
        card_country            => '-',
        card_hash               => '-',
        cv2_response            => '-',
        order_status_id         => 0,
        email                   => $order->billing_email,
        telephone               => $order->primary_phone,
        mobile_telephone        => $order->mobile_phone,
        comment                 => '',
        currency_id             => $order->currency_id,
        channel_id              => $order->channel->id,
        use_external_tax_rate   => $order->use_external_salestax_rate,
        used_stored_card        => $order->used_stored_credit_card,
        ip_address              => $order->customer_ip,
        placed_by               => $order->placed_by,
        sticker                 => $order->sticker,
        order_status_id         => $ORDER_STATUS__ACCEPTED,

        customer_language_preference_id
            => ($language_rs ? $language_rs->id : undef),

        invoice_address => {
            first_name      => $order->billing_name->first_name,
            last_name       => $order->billing_name->last_name,
            address_line_1  => $order->billing_address->line_1,
            address_line_2  => $order->billing_address->line_2,
            address_line_3  => $order->billing_address->line_3,
            towncity        => $order->billing_address->town,
            county          => $order->billing_address->county,
            country         => $order->billing_address->country->country,
            postcode        => $order->billing_address->postcode,
            address_hash    => $order->address_hash( 'billing' ),
            urn             => $order->billing_address->urn,
            last_modified   => $order->billing_address->last_modified,
        },

        ( $order->source_app_name || $order->source_app_version )
            # If we have at least one of app_name or app_version, create
            # an associated order_attribute entry.
            ? (
                order_attribute => {
                    source_app_name     => $order->source_app_name,
                    source_app_version  => $order->source_app_version,
                }
            )
            # Otherwise, do nothing.
            : ( ),

    });

    foreach my $tender ( $order->all_tenders ) {
        my $voucher_code_id;
        if ( $tender->voucher_code ) {
            my $vi = $self->result_source->schema->resultset('Voucher::Code')->search({code => $tender->voucher_code})->first;
            die "couldn't find voucher with code '".$tender->voucher_code."' on the system"
                unless defined $vi;
            $voucher_code_id = $vi->id;
        }
        $order_row->create_related( 'tenders', {
            order_id        => $order_row->id,
            voucher_code_id => $voucher_code_id || undef,
            rank            => $tender->rank,
            value           => $tender->value->value,
            type_id         => $tender->type_id,
        });

    }

    return $order_row;
}

=head2 get_first_defined_phone_number

    my $number = $customer->get_first_defined_phone_number

It's not safe to assume that telephone_1 is defined. This will
returned the first defined phone number stored against the customer.
There is no gurantee to what kind of phone number this will be.

Will return undef if none where found.

=cut

sub get_first_defined_phone_number {
    my ( $self ) = @_;

    return $self->telephone_1 if $self->telephone_1;
    return $self->telephone_2 if $self->telephone_2;
    return $self->telephone_3 if $self->telephone_3;

    return;
}

=head2 orders_with_undispatched_shipments

    $resultset  = $self->orders_with_undispatched_shipments;

Returns a Result Set with a Distinct set of Orders for the Customer which have Un-Dispatched Shipments of any Shipment Class.

=cut

sub orders_with_undispatched_shipments {
    my $self    = shift;
    return $self->undispatched_orders_by_shipment_class();
}

=head2 undispatched_orders_by_shipment_class

    $resultset  = $self->undispatched_orders_by_shipment_class( [ $SHIPMENT_CLASS__??? ... ] );

Returns a Result Set with a Distinct set of Orders for the Customer which have Un-Dispatched Shipments for a List of Shipment Classes.
It determins if a Shipment has not been Dispatched by the status of 'Dispatched' being absent from the 'shipment_status_log' table for
the Shipment.

If nothing is passed then All Class of Shipments are included.

Excludes Cancelled Orders & Shipments.

=cut

sub undispatched_orders_by_shipment_class {
    my ( $self, @ship_class )   = @_;

    # set-up the Sub-Query that will be used to NOT get any
    # Shipments that have had a 'Dispatched' status in their Logs
    my $ship_status_log_rs  = $self->result_source
                                    ->schema->resultset('Public::ShipmentStatusLog')
                                        ->search(
                                            { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED },
                                            { alias => 'subquery' }
                                        );

    # In case you're wondering:
    #   the below along with the above Search will use a Correlated Subquery to produce the following SQL:
    #
    #    SELECT  orders.*
    #    FROM    orders
    #                LEFT JOIN link_orders__shipment link_orders__shipments ON link_orders__shipments.orders_id = orders.id
    #                LEFT JOIN shipment shipment ON shipment.id = link_orders__shipments.shipment_id
    #    WHERE   link_orders__shipments.shipment_id NOT IN (
    #                    SELECT  subquery.shipment_id
    #                    FROM    public.shipment_status_log subquery
    #                    WHERE   shipment_id = link_orders__shipments.shipment_id
    #                    AND     shipment_status_id = ?
    #                )
    #    AND order_status_id != ?
    #    AND shipment.shipment_class_id IN ( ? )
    #    AND shipment.shipment_status_id != ?
    #    AND orders.customer_id = ?
    #    GROUP BY orders.*
    #
    #   to exclude Shipments which have a 'Dispatched' status in their 'shipment_status_log' table.

    return $self->search_related( 'orders',
                    {
                        order_status_id                 => { '!=' => $ORDER_STATUS__CANCELLED },
                        ( @ship_class ? ( 'shipment.shipment_class_id' => { 'IN' => \@ship_class } ) : () ),
                        'shipment.shipment_status_id'   => { '!=' => $SHIPMENT_STATUS__CANCELLED },
                        'link_orders__shipments.shipment_id' => {
                                -not_in => $ship_status_log_rs->search( {
                                                    shipment_id => { '=' => { -ident => 'link_orders__shipments.shipment_id' } }
                                                } )->get_column('shipment_id')
                                                    ->as_query
                            },
                    },
                    {
                        join    => { link_orders__shipments => 'shipment' },
                        distinct=> 1,
                    }
                );
}

=head2 csm_default_prefs_allow_method

    $boolean    = $customer->csm_default_prefs_allow_method( $correspondence_method_rec );

This will return the Customer's Default Preference for receiving Correspondence via a particular
Correspondence Method. It will use the 'customer_correspondence_method_preference' table to see
if that Method exists in it for the Customer. If not, it will then check the 'correspondence_default_preference'
field on the 'customer' table which acts as a general default for any type of Correspondence Method. If that field
is NULL 'undef' will be returned.


First done for CANDO-431.

=cut

sub csm_default_prefs_allow_method {
    my ( $self, $method )   = @_;

    if ( !$method || ref( $method ) !~ m/::CorrespondenceMethod$/ ) {
        croak "No Method DBIC Object passed to '" . __PACKAGE__ . "::csm_default_prefs_allow_method'";
    }

    my $default = $self->search_related( 'customer_correspondence_method_preferences', { correspondence_method_id => $method->id } )
                            ->first;
    return ( $default ? $default->can_use : $self->correspondence_default_preference );
}

=head2 get_all_shipping_addresses

Return all shipping addresses used by customer

=cut

sub get_all_shipment_addresses {
    my ($self) = @_;

    my %addresses = ();

    # Get all addresses from Orders
    foreach my $order ($self->orders->all) {
        my $shipment_address    = $order->get_standard_class_shipment->shipment_address;
        $addresses{$shipment_address->id} = $shipment_address;
    }

    # Get all addresses from PreOrders
    foreach my $preorder ($self->pre_orders->all) {
        $addresses{$preorder->shipment_address->id} = $preorder->shipment_address;
    }

    return %addresses;
}

=head2 get_all_shipment_addresses_valid_for_preorder

Return an ArrayRef of all shipping addresses used by the customer, that are
valid for use with a Pre-Order.

Internally, this is just the results of C<get_all_shipment_addresses> filtered
through C<_filter_addresses_valid_for_preorder>

=cut

sub get_all_shipment_addresses_valid_for_preorder {
    my $self = shift;

    return $self->_filter_addresses_valid_for_preorder(
        $self->get_all_shipment_addresses );

}

=head2 get_all_invoice_addresses_valid_for_preorder

Return an ArrayRef of all invoice addresses used by the customer, that are
valid for use with a Pre-Order.

Internally, this is just the results of C<get_all_invoice_addresses> filtered
through C<_filter_addresses_valid_for_preorder>

=cut

sub get_all_invoice_addresses_valid_for_preorder {
    my $self = shift;

    return $self->_filter_addresses_valid_for_preorder(
        $self->get_all_invoice_addresses );

}

=head2 get_all_used_addresses_valid_for_preorder

Return an ArrayRef of all addresses used by the customer, that are valid for
use with a Pre-Order.

Internally, this is just the results of C<get_all_used_addresses> filtered
through C<_filter_addresses_valid_for_preorder>

=cut

sub get_all_used_addresses_valid_for_preorder {
    my $self = shift;

    return $self->_filter_addresses_valid_for_preorder(
        $self->get_all_used_addresses );

}

=head2 get_last_shipping_address

Return last shipping address

=cut

sub get_last_shipment_address {
    my ($self) = @_;

    if (my $order = $self->get_most_recent_order) {
        return $order->get_standard_class_shipment->shipment_address;
    }
    elsif (my $preorder = $self->get_most_recent_pre_order) {
        return $preorder->shipment_address;
    }
    else {
        return;
    }
}

=head2 get_all_invoice_addresses

Return all invoice addresses used by customer

=cut

sub get_all_invoice_addresses {
    my ($self) = @_;

    my %addresses = ();

    # Get all addresses from Orders
    foreach my $order ($self->orders->all) {
        $addresses{$order->invoice_address->id} = $order->invoice_address;
    }

    # Get all addresses from PreOrders
    foreach my $preorder ($self->pre_orders->all) {
        $addresses{$preorder->invoice_address->id} = $preorder->invoice_address;
    }

    return %addresses;
}

=head2 get_last_invoice_address

Return last invoice address used by customer

=cut

sub get_last_invoice_address {
    my ($self) = @_;

    if (my $order = $self->get_most_recent_order) {
        return $order->invoice_address;
    }
    elsif (my $preorder = $self->get_most_recent_pre_order) {
        return $preorder->invoice_address;
    }
    else {
        return;
    }
}

=head2 get_all_used_addresses

=cut

sub get_all_used_addresses {
    my ($self) = @_;
    return ($self->get_all_invoice_addresses(), $self->get_all_shipment_addresses());
}

=head2 get_most_recent_order

    my $orders_obj  = $self->get_most_recent_order;

Returns the most recent Order for the Customer.

=cut

sub get_most_recent_order {
    my $self = shift;

    return $self->orders
                ->search( undef, { order_by => 'id DESC', rows => 1 } )
                ->first;
}

=head2 get_most_recent_pre_order

    my $pre_order_obj  = $self->get_most_recent_pre_order;

Returns the most recent PreOrder for the Customer.

=cut

sub get_most_recent_pre_order {
    my $self = shift;

    return $self->pre_orders
                ->search( undef, { order_by => 'id DESC', rows => 1 } )
                ->first;
}

=head2 set_language_preference

    $customer->set_language_preference('en');

Set the language preference for the customer

=cut

sub set_language_preference {
    my ($self, $lang_code)   = @_;
    my $schema               = $self->result_source->schema;

    return unless $lang_code;

    my $language = $schema->resultset('Public::Language')->get_language_from_code($lang_code);

    if ($language) {
        $schema->resultset('Public::CustomerAttribute')->update_or_create({
            customer_id            => $self->id,
            language_preference_id => $language->id
        });
        $self->discard_changes;
    }

    return $self;
}

=head2 get_language_preference

    my $language_obj = $customer->get_language_preference();

Returns a hashref with a language DBIx object

{
    is_default => boolean
    language   => DBIx Object
}

=cut

sub get_language_preference {
    my $self   = shift;
    my $schema = $self->result_source->schema;

    if ($self->customer_attribute && $self->customer_attribute->language_preference) {
        return {
            is_default => 0,
            language   => $self->customer_attribute->language_preference
        }
    }
    else {
        return {
            is_default => 1,
            language   => $schema->resultset('Public::Language')->get_default_language_preference
        }
    }
}

sub has_language_preference {
    my $self   = shift;
    my $schema = $self->result_source->schema;

    if ($self->customer_attribute && $self->customer_attribute->language_preference) {
        return 1;
    }
    else {
        return 0;
    }
}

=head2 locale

    $string = $customer->locale;

FOR NOW this will just return the Customer's Language Code ('en') given
to it by using '$customer->get_language_preference' until we implement
the Customer's Locale properly, when that happens we will just need to
change this method and then all uses of it should then work passing
the proper Locale ('en_GB').

=cut

sub locale {
    my $self    = shift;

    my $language    = $self->get_language_preference;
    return $language->{language}->code;
}

=head2 search_marketing_customer_segment

    my $array_ref = $customer->search_marketing_customer_segment();

It returns all the marketing_customer_segment records to which the customer
is attached.

Returns arrayref with marketing_customer_segment DBIX object
[
    marketing_customer_segment DBIX object,
    marketing_customer_segment DBIX object,
    .
    .
    .
]

=cut

sub search_marketing_customer_segment {
    my ( $self ) = shift;

    my $data   = [$self->link_marketing_customer_segment__customers->all];
    my $schema = $self->result_source->schema;
    my @return_data;

    my $segment = $schema->resultset('Public::MarketingCustomerSegment');

    if( $data ) {
        foreach my $row ( @{ $data } ) {
            push(@return_data ,$segment->find($row->customer_segment_id) );
        }
    }

    return (\@return_data);

}

=head2 is_trusted

Do we trust this customer. By default customers are untrusted.

=cut

sub is_trusted {
    my $self = shift;

    # This is very verbose to ensure we don't trust people by accident under
    # future modifications

    # Condition values should be a sub ref that returns true if the customer
    # is trusted for this check. Adding a condition here is sufficient to add
    # the check. Customer is only trusted if all conditions are true.
    my %conditions
      = ( credit_check => sub { return $self->credit_check_orders == 0 },
          credit_hold => sub { return $self->credit_hold_orders == 0 },
          finance_watch => sub { return $self->has_finance_watch_flag ? 0 : 1 },
        );

    # Total number of checks
    my $total_conditions = scalar keys %conditions;

    # Check each condition
    my $trusted_conditions = 0;
    foreach my $condition (keys %conditions){
        if($conditions{$condition}->()){
            # Customer is trusted for this check
            $trusted_conditions++;
        }
        else{
            # No trust - no increment
        }
    }

    # Customer is only trusted if all conditions are true
    my $trusted_customer = 0;
    if( $trusted_conditions == $total_conditions ){
        $trusted_customer = 1;
    }

    return $trusted_customer;
}

=head2 has_genuine_order_history

Does this customer have a succesfully processed, dispatched and paid order
history in this DC

=cut

sub has_genuine_order_history {
    my $self = shift;

    my $paid_order_count = 0;
    foreach my $order ($self->orders->all) {
        if($order->original_shipment_is_dispatched){
            $paid_order_count = 1;
            last;
        }
    }

    return $paid_order_count;
}

=head2 is_on_other_channels

    $self->is_on_other_channels;

Returns TRUE if the Customer has an Account on any other Sales Channel.

=cut

sub is_on_other_channels {
    my $self    = shift;

    return $self->on_all_channels->search( {
        channel_id => { '!=' => $self->channel_id },
    } )->count;
}

=head2 on_all_channels

Returns a resultset containing all customer records, across all channels,
which are probably the same customer as this

=cut

sub on_all_channels {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $set = $schema->resultset('Public::Customer')->search(
        \[ 'LOWER(me.email) = LOWER(?)', [ plain_value => $self->email ] ]
    );

    return $set;
}

=head2 is_on_finance_watch_on_any_channel

Returns true if the Finance Watch flag is set for this customer record or
any customer record matched by $self->on_all_channels

=cut

sub is_on_finance_watch_on_any_channel {
    my $self = shift;

    my $flags = $self->on_all_channels->search_related('customer_flags', {
        flag_id => $FLAG__FINANCE_WATCH,
    });

    if (!defined $flags || $flags->count == 0) {
        return 0;
    }
    return 1;
}

=head2 has_orders_on_credit_hold

Returns true if the customer has any orders currently on credit hold.

=cut

sub has_orders_on_credit_hold {
    my ( $self, $args ) = @_;

    my $constraint = {
        order_status_id => $ORDER_STATUS__CREDIT_HOLD,
    };

    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constraint->{id} = { "!=" => $args->{exclude_order_id} };
    }

    my $orders = $self->search_related('orders', $constraint );

    return ($orders && $orders->count > 0) ? 1 : 0;
}

=head2 has_orders_on_credit_hold_on_any_channel

Returns true if the customer has any orders currently on credit hold on
any channel.

=cut

sub has_orders_on_credit_hold_on_any_channel {
    my ($self, $args) = @_;

    my $constraint = {
        order_status_id => $ORDER_STATUS__CREDIT_HOLD,
    };

    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constraint->{'orders.id'} = { "!=" => $args->{exclude_order_id} };
    }

    my $credit_hold_orders = $self->on_all_channels->search_related('orders',
        $constraint
    );

    return $credit_hold_orders->count > 0 ? 1 : 0;
}

=head2 has_order_on_credit_check

Returns true if the customer has any orders in credit check status

=cut

sub has_order_on_credit_check {
    my ($self, $args) = @_;

    my $constraint = {
        order_status_id => $ORDER_STATUS__CREDIT_CHECK,
    };

    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constraint->{id} = { "!=" => $args->{exclude_order_id} };
    }

    my $orders = $self->search_related('orders',
        $constraint
    );

    return $orders->count > 0 ? 1 : 0;
}

=head2 has_order_on_credit_check_on_any_channel

Returns true if the customer has any orders in credit check status on
any channel.

=cut

sub has_order_on_credit_check_on_any_channel {
    my ($self, $args) = @_;

    my $constraint = {
        order_status_id => $ORDER_STATUS__CREDIT_CHECK,
    };

    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constraint->{'orders.id'} = { "!=" => $args->{exclude_order_id} };
    }

    my $orders = $self->on_all_channels->search_related('orders',
        $constraint
    );

    return $orders->count > 0 ? 1 : 0;
}

=head2 is_staff_on_any_channel

Returns true if the customer or any customer with the same email address or
the same name and physical address on any channel is in Staff category.

=cut

sub is_staff_on_any_channel {
    my $self = shift;

    my $is_staff = $self->on_all_channels->search_rs( {
        category_id => $CUSTOMER_CATEGORY__STAFF
    } );

    return ( defined $is_staff && $is_staff->count > 0 ) ? 1 : 0;
}

=head2 orders_aged_on_any_channel

Search related orders for a given age based on order.date. Defaults to no age
constraints

=cut

sub orders_aged_on_any_channel {
    my($self, $args) = @_;

    foreach my $arg ( qw/count period/ ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $constr;
    my $age = $args->{count}." ".$args->{period};

    # we specify orders.date as the source of the contraint for this method
    # as opposed to me.date which is used in orders_aged() because the
    # context of the query generated by DBIC is changed to the customer
    # by virtue of the on_all_channels() call.
    $constr = {
        'age(orders.date)' => { '<' => $age },
        order_status_id => { '!='  => $ORDER_STATUS__CANCELLED },
    };

    # Provide an option to exclude a specific order from the results
    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constr->{id} = { '!=' => $args->{exclude_order_id} };
    }

    return $self->on_all_channels->search_related('orders', $constr);
}

=head2 has_placed_order_in_last_n_periods

    if ( $cust->has_placed_order_in_last_n_periods( {
        count => 2,
        period => 'week',
        on_all_channels => 1
    } ) {
        ...
    }

Returns true if the customer has placed any orders within the specified
period of time.

Parameters:
    count           The number of units of the specified time period
    period          The period of time. Must be one of day, week, month, year
    on_all_channels Specify this if you want results across all channels

count and period are required parameters.

=cut

sub has_placed_order_in_last_n_periods {
    my ($self, $args) = @_;

    foreach my $arg ( qw/count period/ ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $orders = $self->number_of_orders_in_last_n_periods($args);

    return ( $orders && $orders > 0 ) ? 1 : 0;
}

=head2 number_of_orders_in_last_n_periods

Returns the number of orders the customer has placed in the last $count
number of $period time periods

Parameters:
    count           The number of units of the specified time period
    period          The period of time. Must be one of day, week, month, year
    on_all_channels Specify this if you want results across all channels

count and period are required parameters.

=cut

sub number_of_orders_in_last_n_periods {
    my ($self, $args) = @_;

    foreach my $arg ( qw/ count period / ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $orders;
    if ( exists $args->{on_all_channels} && $args->{on_all_channels} ) {
        $orders = $self->orders_aged_on_any_channel( $args );
    }
    else {
        $orders = $self->orders_within_period_not_cancelled( $args );
    }
    return $orders->count;
}

=head2 orders_count

Returns the number of orders the customer has placed which have not been
cancelled

=cut

sub orders_count {
    my ($self, $args) = @_;

    my $orders;
    if (exists $args->{on_all_channels} && defined $args->{on_all_channels}) {
        $orders = $self->on_all_channels->orders->search( {
            order_status_id => { '!='  => $ORDER_STATUS__CANCELLED }
        } );
    }
    else {
        $orders = $self->orders->search( {
            order_status_id => { '!='  => $ORDER_STATUS__CANCELLED }
        } );
    }

    return $orders->count;
}
1;

=head2 has_placed_4_or_more_orders

Returns true if the customer has placed 4 or more orders

=cut

sub has_placed_4_or_more_orders {
    my ( $self, $args ) = shift;

    my $count;
    if ( exists $args->{on_all_channels} && defined $args->{on_all_channels} ) {
        $count = $self->orders_count({ on_all_channels => 1 });
    }
    else {
        $count = $self->orders_count;
    }

    return $count >= 4 ? 1 : 0;
}

=head2 total_spend_in_last_n_period

Returns the total customer spend over the specified time period converted
to the local currency equivelent value.

=cut

sub total_spend_in_last_n_period {
    my ($self, $args) = @_;

    foreach my $arg ( qw/ count period / ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $total = 0;

    my $orders = $self->orders_within_period_not_cancelled( $args );

    while ( my $order = $orders->next ) {
        $total += $order->get_total_value_in_local_currency( {
            want_original_purchase_value    => $args->{want_original_purchase_value} // 0,
        } );
    }
    return $total;
}

=head2 total_spend_in_last_n_period_on_all_channels

Returns the total customer spend over the specified time period converted
to the local currency equivelent value.

=cut

sub total_spend_in_last_n_period_on_all_channels {
    my ($self, $args) = @_;

    foreach my $arg ( qw/ count period / ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $total = 0;

    my $orders = $self->orders_aged_on_any_channel($args);

    while ( my $order = $orders->next ) {
        $total += $order->get_total_value_in_local_currency( {
            want_original_purchase_value    => $args->{want_original_purchase_value} // 0,
        } );
    }
    return $total;
}

=head2 is_credit_checked

Returns true if the customer has ever been credit checked. Operates on all
records matching this customer record across all channels.

=cut

sub is_credit_checked {
    my $self = shift;

    my $checked = $self->on_all_channels->search( {
        credit_check => { '!=' => undef },
    });
    return 1 if $checked && $checked->count > 0;
    return;
}

=head2 orders_within_period_not_cancelled

    my resultset = $customer->orders_within_period_not_cancelled->( {
        count => 1,
        period => 'day'
    } );

Search related orders that have not been cancelled for a given age based on
order.date. Defaults to no age constraints

=cut

sub orders_within_period_not_cancelled {
    my($self,$args) = @_;

    foreach my $arg ( qw/ count period / ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $age = $args->{count}." ".$args->{period};

    my $constr;

    if (defined $age) {
        $constr = {
            'me.date' => { '>=' => \"(now() - interval \'$age\')"},
            order_status_id => { '!='  => $ORDER_STATUS__CANCELLED }
        };
    }

    # Provide an option to exclude a specific order from the results
    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constr->{id} = { '!=' => $args->{exclude_order_id} };
    }

    return $self->search_related('orders', $constr);
}

=head2 orders_older_than_not_cancelled

Returns a resultset of all orders for customer older that given time
period which are not cancelled.

=cut

sub orders_older_than_not_cancelled {
    my ($self, $args) = @_;

    foreach my $arg ( qw/ count period / ) {
        die "$arg parameter required" unless exists $args->{$arg}
            && $args->{$arg};
    }

    die "count must be an integer" unless 0+$args->{count};
    die "period must be one of second minute hour day week month year"
        unless grep { $args->{period} } ( qw/second minute hour day week month year/ );

    my $age = $args->{count}." ".$args->{period};

    my $constr = {
            'me.date' => { '<' => \"(now() - interval \'$age\')" },
            order_status_id => { '!='  => $ORDER_STATUS__CANCELLED }
    };

    # Provide an option to exclude a specific order from the results
    if ( exists $args->{exclude_order_id} && $args->{exclude_order_id} ) {
        $constr->{id} = { '!=' => $args->{exclude_order_id} };
    }

    return $self->search_related('orders', $constr);
}


=head2 has_orders_older_than_not_cancelled

Returns true if customer has orders older than a given time period
which are not cancelled

Time period is specified in a hashref has follows:

{
    count   => $count,
    period  => $period
}

where $count is a positive integer value and $period is one of
( second, minute, hour, day, week, month, year )

=cut

sub has_orders_older_than_not_cancelled {
    my ($self, $args) = @_;

    my $orders = $self->orders_older_than_not_cancelled($args);

    return ( $orders && $orders->count > 0 ) ? 1 : 0;
}

=head2 has_new_high_value_action

Returns a BOOLEAN value indicating whether or not the Customer has
an associated 'New High Value' record in the Public::CustomerAction
table.

    my $has_new_high_value_action = $schema
        ->resultset('Public::Customer')
        ->find( $id )
        ->has_new_high_value_action;

=cut

sub has_new_high_value_action {
    my $self = shift;

    my $new_high_value_count = $self
        ->customer_actions
        ->get_new_high_values
        ->count;

    return $new_high_value_count
        ? 1
        : 0;

}

=head2 set_new_high_value_action( \%args )

Create an associated 'New High Value' record in the Public::CustomerAction
table, if one doesn't already exist, as a customer should only have one
record of this type.

The argument 'operator_id' is required.

    $schema
        ->resultset('Public::Customer')
        ->find( $id )
        ->set_new_high_value_action( {
            operator_id => $operator_id
        } );

=cut

sub set_new_high_value_action {
    my ( $self, $args ) = @_;

    die "operator_id is required for " . __PACKAGE__ . "->set_new_high_value_action"
        unless $args->{operator_id};

    if ( $self->has_new_high_value_action ) {

        die "Customer " . $self->is_customer_number . " already has a 'New High Value' flag";

    } else {

        $self->customer_actions->add_customer_new_high_value( {
            operator_id => $args->{operator_id},
        } );

    }

}

=head2 get_card_token

If the customer has an account_urn, get the customers card token from Seaview
if one exists, otherwise return C<undef>.

    my $customer = $schema->resultset('Public::Customer')->find( $id );
    my $token    = $customer->get_card_token;

=cut

sub get_card_token {
    my $self = shift;
    my $seaview = shift;

    $seaview //= $self->_new_seaview_client;

    if ($self->account_urn && $seaview) {
        my $seaview_card_token = $seaview->get_card_token($self->account_urn);
        return $seaview_card_token->card_token;
    }
    else {
        return undef;
    }
}

=head2 create_card_token

Requests a new card token from the PSP, saves it in Seaview and then returns it.

NOTE: It's easier and better just to call C<get_or_create_card_token>.

=cut

sub create_card_token {
    my $self = shift;

    # get the Customer Number for the Logs
    my $cust_num   = $self->is_customer_number;
    my $log_prefix = "'create_card_token' - For Customer: '${cust_num}'";

    my $seaview = $self->_new_seaview_client;
    my $payment = XT::Domain::Payment->new();
    my $card_token = {};
    try {
        $card_token = $payment->get_new_card_token;
        xt_logger->info( $log_prefix . " - Got from PSP a Card Token: '" . obscure_card_token( $card_token->{customerCardToken} ) . "'" );
    }
    catch {
        xt_logger->warn('Unable to get a new card token from PSP. '.$_);
    };

    if ( my $token = $card_token->{customerCardToken} ) {

        # Save to Seaview - we don't care if it doesn't work
        if ( $self->account_urn && $seaview ) {
            try {
                $seaview->replace_card_token( $self->account_urn, { card_token => $token } );

                $card_token = $self->get_card_token($seaview);
                $token = $card_token if $card_token;
                xt_logger->info( $log_prefix . " - Replaced Seaview Card Token: '" . obscure_card_token( $token ) . "'" );
            }
            catch {
                my $err = $_;
                xt_logger->warn( $log_prefix . " - Couldn't Replace Seaview with Card Token: '" . obscure_card_token( $token ) . "', Error: ${err}" );
            };
        }
        else {
            xt_logger->warn( $log_prefix . " - No Seaview Account to update with Card Token: '" . obscure_card_token( $token ) . "'" );
        }

        # Return the token.
        return $token;

    } else {

        xt_logger->fatal( $log_prefix . " - Problem creating card token" );
        die "Problem creating card token";

    }

    return;

}

=head2 get_or_create_card_token

This is a wrapper around C<get_card_token> and C<create_card_token>, that only calls
C<create_card_token> if C<get_card_token> does not return a token.

=cut

sub get_or_create_card_token {
    my $self = shift;

    # get the Customer Number for the Logs
    my $cust_num   = $self->is_customer_number;
    my $log_prefix = "'get_or_create_card_token' - For Customer: '${cust_num}'";

    my $card_token;

    try {
        $card_token = $self->get_card_token;

        die "'get_or_create_card_token' -  card_token was not present" unless $card_token;
    }
    catch {

        my $error = $_;

        # Because various exceptions could be raised here and some don't
        # have a 'code' attribute, we must check that first.
        if (
            blessed( $error ) && $error->can( 'code' ) &&
            $error->code == HTTP_NOT_FOUND
        ) {
        # The customer does not have a token.

            $card_token = $self->create_card_token;
            xt_logger->info( $log_prefix . " - Got a new Card Token: '" . obscure_card_token( $card_token ) . "'" );

        } else {
            xt_logger->warn( $log_prefix . " - Could not get card token from Seaview: ${error}" );
            $card_token = $self->create_card_token;
        }

    };

    return $card_token;

}

=head2 get_saved_cards

Get all the saved cards for this customer. Returns an ArrayRef of card
details as returned by C<getcustomer_saved_cards> in L<XT::Domain::Payment>.

    $customer->get_saved_cards( {
        cardToken => '12345689',
        operator  => $schema->resultset('Public::Operator')->find($id ),
    } );

=cut

sub get_saved_cards {
    my $self = shift;
    my $args = shift;

    if ($args && $args->{cardToken} && $args->{operator}) {

        my $payment = XT::Domain::Payment->new();

        return $payment->getcustomer_saved_cards({
            site                => lc($self->channel->website_name),
            userId              => $args->{operator}->id,
            customerId          => $self->pws_customer_id,
            customerCardToken   => $args->{cardToken}
        });

    }

    return [];

}

=head2 save_card

Save the card details to this customer. Returns TRUE if it succeeds, FALSE otherwise.

    $customer->save_card( {
        operator        => $schema->resultset('Public::Operator')->find($id ),
        cardToken       =>  '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97',
        cardExpiryDate  => '03/16',
        cardType        => 'AMEX',
        cardLast4Digits => '0006',
        cardNumber      => '343434100000006',
        cardHoldersName => 'Mr O Victor-Smith',
    } );

=cut

sub save_card {
    my $self    = shift;
    my $args    = shift;
    my $payment = XT::Domain::Payment->new();

    return $payment->save_card({
        site       => lc($self->channel->website_name),
        userID     => $args->{operator}->id,
        customerID => $self->pws_customer_id,
        cardToken  =>  $args->{cardToken},
        creditCardReadOnly => {
            cardToken       => $args->{cardToken},
            customerId      => $self->pws_customer_id,
            expiryDate      => $args->{cardExpiryDate},
            cardType        => $args->{cardType},
            last4Digits     => $args->{cardLast4Digits},
            cardNumber      => $args->{cardNumber},
            cardHoldersName => $args->{cardHoldersName},
        }
    });
}

=head2 should_not_have_shipping_costs_recalculated

    $boolean = $self->should_not_have_shipping_costs_recalculated;

Returns TRUE or FALSE depending on whether this Customer should have
any Shipment's Shipping Costs Re-Calculated.

This uses the Customer's Category's Class along with the System Config
'Customer' Section for their Sales Channel to determin what this method
should return.

This method is only about whether a Shipment's Shipping Costs/Charges should
be re-calculated and not whether its 'shipping_charge_id' should be changed
which is to do with their Shipping Option and not how much they've paid
for it.

=cut

sub should_not_have_shipping_costs_recalculated {
    my $self = shift;

    my $result = $self->channel->should_not_recalc_shipping_cost_for_customer_class(
        $self->category->customer_class,
    );

    return ( $result ? 1 : 0 );
}

=head2 calculate_customer_value

=cut

sub calculate_customer_value {
    my $self = shift;

    return get_customer_value(
        $self->result_source->schema->storage->dbh,
        $self );

}

=head2 get_customer_value_from_service

=cut

sub get_customer_value_from_service {
    my $self = shift;

    my $seaview = $self->_new_seaview_client;

    if ( $self->account_urn && $seaview ) {

        my $bosh_key = 'customer_value_'
          . config_var('DistributionCentre', 'name');

        my $result = $seaview->get_bosh_value_for_account(
            $self->account_urn,
            $bosh_key );

        return $result->value;

    }

}

=head2 update_customer_value_in_service( $customer_value )

The parameter C<$customer_value> must be the result of the
C<get_customer_value> method in L<XTracker::Database::Customer>. If it's not
provided (or undef) it will default to the result of C<calculate_customer_value>.

The update will only be pushed to the service if this feature is turned on in
the system config table. The group is 'CustomerValue' and the setting is
'Send To BOSH'. Setting it to 'On' will enable the feature and 'Off' will
disable it.

=cut

sub update_customer_value_in_service {
    my ( $self, $customer_value ) = @_;

    # Only push the update to the service
    # if the feature is turned on.
    return unless
        uc( sys_config_var( $self->result_source->schema,
            SendToBOSH => 'Customer Value' ) // '' ) eq 'ON';

    my $seaview = $self->_new_seaview_client;

    if ( $self->account_urn && $seaview ) {

        $customer_value //= $self->calculate_customer_value;

        # There should only be one key in the HashRef and this will be the
        # Channel ID.
        my ( $channel_id ) =
            ref( $customer_value ) eq 'HASH' &&
            scalar( keys %$customer_value ) == 1
                ? keys %$customer_value
                : 0;

        # If the Channel ID from customer value doesn't match the one for the
        # customer, it's meaningless to send the update.
        die '[update_customer_value_in_service] Channel ID Mismatch' unless
            $channel_id == $self->channel_id;

        # Create a limited customer value data structure to send to the
        # service
        my $value_by_currency = {};
        $value_by_currency->{'channel'} = $self->channel->web_name;
        $value_by_currency->{'total_spend'} = [];
        foreach my $spend ( @{$customer_value->{$self->channel->id}->{spend}} ) {
            # Multiply the spend value by 100 to give us the lowest
            # denomination of coin
            my $coin_amount = $spend->{net}->{value} * 100;

            push @{$value_by_currency->{'total_spend'}},
                 { 'spend_currency' => $spend->{currency},
                   'spend' => $coin_amount };
        }

        # Encode the limited customer value data as JSON
        my $customer_value_json = encode_json $value_by_currency;

        # Add the current DC to the service key
        my $bosh_key = 'customer_value_'
          . config_var('DistributionCentre', 'name');

        # Add the JSON structure into the service
        my $result = $seaview->replace_bosh_value_for_account(
            $self->account_urn,
            $bosh_key,
            $customer_value_json );

        # Create a log entry.
        $self->update_or_create_related( 'customer_service_attribute_logs', {
           service_attribute_type_id    => $SERVICE_ATTRIBUTE_TYPE__CUSTOMER_VALUE,
           last_sent                    => DateTime->now,
        } );

        return $result;

    }

    return;

}

=head2 update_seaview_account

If the customer is linked to a Seaview account and make the same update to
that account in Seaview

=cut

sub update_seaview_account {
    my $self = shift;
    my $category_id = shift;

    my $seaview = $self->_new_seaview_client;
    my $schema = $self->result_source->schema;

    try {
        my $category = $schema->resultset('Public::CustomerCategory')->find($category_id);

        die "category_id $category_id is not known" unless $category;

        if (my $account_urn = $seaview->registered_account($self->id)) {
            # Grab the remote account
            my $remote_account = $seaview->account($account_urn);
            die "${SEAVIEW_FAILURE_MESSAGE__ACCOUNT_NOT_FOUND_FOR_URN}: ${account_urn}\n" unless $remote_account;

            # Update the category
            $remote_account->category($category->category);

            # Propogate the update to Seaview
            $seaview->update_account($account_urn, $remote_account);
        }
        else {
            # No seaview account
        }
    }
    catch {
        my $error = $_;
        xt_logger->warn($error);
        die($error);
    };
}

=head2 get_pre_order_discount_percent

    my $number = $self->get_pre_order_discount_percent();

Will return the Pre-Order Discount percentage that can be applied to the Customer. If the
Customer doesn't have a Discount then 'undef' will be returned and NOT ZERO, if zero is
returned then that Customer does have a Discount applied to them but it is set as zero.

=cut

sub get_pre_order_discount_percent {
    my $self    = shift;

    my $channel = $self->channel;

    # if Discounts are turned Off then just return
    return      if ( !$channel->can_apply_pre_order_discount );

    # get the Discount based on the Customer's Category
    return $channel->get_customer_category_pre_order_discount( $self->category );
}

=head2 get_local_addresses

    $hash_ref = get_local_addresses();

Returns all addresses associated with a Customer (billing and shipping) using the
Local DB - meaning not Seaview but the 'order_address' table.

=cut

sub get_local_addresses {
    my $self = shift;

    my $schema = $self->result_source->schema;

    my $customer_addresses_rs = $schema->resultset('Public::OrderAddress')
        ->search(
        {
            id => {
                'in' => [
                    # shipment addresses
                    $self->orders
                        ->related_resultset('link_orders__shipments')
                        ->related_resultset('shipment')
                        ->get_column('shipment_address_id')
                        ->all,
                    # invoice addresses
                    $self->orders
                        ->get_column('invoice_address_id')
                        ->all,
                ],
            },
        },
    );

    # return hashref of hashes keyed by id as before
    my $data;
    $data->{ $_->id } = {
        $_->get_inflated_columns
    } foreach ( $customer_addresses_rs->all );

    return $data;
}

=head2 get_seaview_or_local_addresses

    $hash_ref = $self->get_seaview_or_local_addresses();
            or
    $hash_ref = $self->get_seaview_or_local_addresses( {
        stringify_objects => 1,
    } );

Gets all of the Customer's Addresses. Will attempt to get them from
Seaview first and then if that fails use XT's 'order_address' table.

Pass the argument 'stringify_objects' to stringify any blessed values in
the Addresses.

=cut

sub get_seaview_or_local_addresses {
    my ( $self, $args ) = @_;

    my $seaview = $self->_new_seaview_client;

    my $addrs;
    try {
        # Pull address list from Seaview
        if ( my $account_urn = $seaview->registered_account( $self->id ) ) {
            # get the Customer URN for the Account
            my $customer_urn = $seaview->find_customer( $account_urn );

            $addrs = {
                map {
                    $_->urn => $_->as_dbi_like_hash,
                } values %{ $seaview->all_addresses( $customer_urn ) }
            };

            unless ( keys %{ $addrs } > 0 ) {
                # No Seaview addresses - Use local XT address list
                $addrs = $self->get_local_addresses();
            }
        }
        else {
            # No linked Seaview account - get addresses from local DB
            $addrs = $self->get_local_addresses();
        }
    }
    catch {
        xt_logger->info( "Cust Id: '" . $self->id . "' - 'get_seaview_or_local_addresses' had problem getting Seaview Addresses: " . $_ );
        # Seaview error - Going local down in Acapulco!
        $addrs = $self->get_local_addresses();
    };

    if ( $addrs ) {
        # add the 'addr_key' to each Address
        foreach my $id ( keys %{ $addrs } ) {
            $addrs->{ $id } = add_addr_key( $addrs->{ $id } );
            $addrs->{ $id } = XT::Net::Seaview::Utils->state_county_switch(
                $addrs->{ $id },
            );
            if ( $args->{stringify_objects} ) {
                # stringify any objects found in the Address
                my $address = $addrs->{ $id };
                foreach my $key ( keys %{ $address } ) {
                    $address->{ $key } = qq/$address->{ $key }/
                            if ( blessed( $address->{ $key } ) );
                }
            }
        }
    }

    return $addrs;
}

=head1 PRIVATE METHODS

=head2 _new_seaview_client

=cut

sub _new_seaview_client {
    my $self = shift;

    return XT::Net::Seaview::Client->new( {
        schema => $self->result_source->schema } );
}

=head2 _filter_addresses_valid_for_preorder

Takes a HashRef of L<Public::OrderAddress> objects keyed by ID (although the
key is not used in this method) and filters all the C<values> in the HashRef
by the L<is_valid_for_pre_order> on each L<Public::OrderAddress> object.

Returns an ArrayRef of L<Public::OrderAddress> objects that have the
L<is_valid_for_pre_order> set to true.

=cut

sub _filter_addresses_valid_for_preorder {
    my ( $self, %addresses ) = @_;

    return [
        grep    { $_->is_valid_for_pre_order }
        values  %addresses
    ];

}

1;
