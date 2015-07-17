package XT::Data::Order;
use NAP::policy "tt", 'class';

use Digest::MD5;

use NAP::Carrier;
use XT::Business;
use XT::Data::Types qw/ TimeStamp DateStamp /;
use XT::Business;
use XTracker::DBEncode qw( encode_it );
use XTracker::Config::Local qw( sys_config_var config_var config_section_slurp is_staff_order_premier_channel shipping_email get_fraud_check_rating_adjustment internal_staff_shipping_sku email_address_for_setting );
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID /;
use XTracker::Constants::Reservations qw( :reservation_pre_order_importer );
use XTracker::Constants::FromDB qw(
    :carrier
    :correspondence_templates
    :customer_category
    :flag
    :note_type
    :shipment_item_status
    :shipment_type
    :shipment_status
    :shipping_charge_class
    :shipment_hold_reason
    :order_status
    :customer_class
    :country
);
use XTracker::Database::PreOrder        qw( :validation :utils );
use XTracker::Database::Reservation     qw( :email );
use XTracker::Database::OrderPayment    qw( create_sales_invoice_for_preorder_shipment );
use XTracker::Database::Shipment        qw( check_shipment_restrictions );
use XTracker::Logfile qw(xt_logger);
use XTracker::Promotion::Pack;
use XT::Data::NominatedDay::Order;
use XT::Data::NominatedDay::Shipment;
use XT::Domain::Fraud::RemoteDCQuery;
use XTracker::EmailFunctions qw( send_internal_email
                                 send_templated_email
                                 send_email
                                 send_ddu_email );
with 'XTracker::Role::WithAMQMessageFactory';

use XT::FraudRules::Engine;
use XT::JQ::DC;
use XTracker::Database::Invoice      qw( update_card_tender_value );


use Benchmark       qw( :hireswallclock );


my $logger           = xt_logger;
my $benchmark_logger = xt_logger('Benchmark');

=head1 NAME

XT::Data::Order - An order for fulfilment

=head1 DESCRIPTION

This class represents an order that is to be inserted into XT's order database.
It also provides some methods for working with orders: processing, saving etc.

=head1 CLASS METHODS

=head2 BUILD

Make sure nominated_dispatch_time is initialized, since it's not a
declared attribute (it's delegated to the nominated_day attribute).

=cut

sub BUILD {
    my ($self,$args) = @_;
    if(defined $args->{nominated_dispatch_time}) {
        $self->nominated_dispatch_time($args->{nominated_dispatch_time});
    }
}

=head1 ATTRIBUTES

=head2 schema

=cut

with 'XTracker::Role::WithSchema';

=head2 order_number

=cut

has order_number => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 order_date

=cut

has order_date => (
    is          => 'rw',
    isa         => TimeStamp,
    coerce      => 1,
    required    => 1,
);

=head2 channel_name

=cut

has channel_name => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 channel

    my $channel = $order->channel;

Returns the channel row for the channel present in the order. It uses
the 'channel_name' attribute to find the Channel.

=cut

has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 customer_number

=cut

has customer_number => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
);

=head2 customer_ip

=cut

has customer_ip => (
    is          => 'rw',
    isa         => 'Str', # could create a subtype based on Regexp::Common::net
    required    => 1,
);

=head2 account_urn

Seaview account that this order was made under

=cut

has account_urn => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 used_stored_credit_card

=cut

has used_stored_credit_card => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

=head2 use_external_salestax_rate

=cut

has use_external_salestax_rate => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

=head2 placed_by

=cut

has placed_by => (
    is  => 'ro',
    isa => 'Str',
);

=head2 tenders

=cut

has tenders => (
    is          => 'ro',
    isa         => 'ArrayRef[XT::Data::Order::Tender]',
    required    => 1,
    traits      => ['Array'],
    default     => sub { [] },
    handles     => {
        add_tender          => 'push',
        all_tenders         => 'elements',
        number_of_tenders   => 'count',
    },
);

=head2 billing_name

Attribute is of class L<XT::Data::CustomerName>.

=cut

has billing_name => (
    is          => 'rw',
    isa         => 'XT::Data::CustomerName',
    required    => 1,
);

=head2 billing_address

Attribute is of class L<XT::Data::Address>.

=cut

has billing_address => (
    is          => 'rw',
    isa         => 'XT::Data::Address',
    required    => 1,
);

=head2 billing_telephone_numbers

Attribute is of class L<XT::Data::Telephone>.

=cut

has billing_telephone_numbers => (
    is          => 'rw',
    isa         => 'ArrayRef[XT::Data::Telephone]',
    required    => 1,
    traits      => ['Array'],
    default     => sub { [] },
    handles     => {
        add_billing_telephone_number           => 'push',
        all_billing_telephone_numbers          => 'elements',
        number_of_billing_telephone_numbers    => 'count',
    },
);

=head2 billing_email

=cut

has billing_email => (
    is          => 'rw',
    isa         => 'Str', # could create a subtype based on email
    required    => 1,
);

=head2 transaction_value

Attribute is of class L<XT::Data::Money>.

=cut

has transaction_value => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 0,
);

=head2 voucher_credit

Attribute is of class L<XT::Data::Money>.

=cut

has voucher_credit => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 store_credit

Attribute is of class L<XT::Data::Money>.

=cut

has store_credit => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 gift_credit

Attribute is of class L<XT::Data::Money>.

=cut

has gift_credit => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 shipping_net_price

Attribute is of class L<XT::Data::Money>.

=cut

has shipping_net_price => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 shipping_tax

Attribute is of class L<XT::Data::Money>.

=cut

has shipping_tax => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 shippping_duties

Attribute is of class L<XT::Data::Money>.

=cut

has shipping_duties => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
);

=head2 customer_name

Attribute is of class L<XT::Data::CustomerName>

=cut

has customer_name => (
    is          => 'rw',
    isa         => 'XT::Data::CustomerName',
    required    => 1,
);

=head2 delivery_name

Attribute is of class L<XT::Data::CustomerName>.

=cut

has delivery_name => (
    is          => 'rw',
    isa         => 'XT::Data::CustomerName',
    required    => 1,
);

=head2 delivery_address

Attribute is of class L<XT::Data::Address>.

=cut

has delivery_address => (
    is          => 'rw',
    isa         => 'XT::Data::Address',
    required    => 1,
);


=head2 delivery_telephone_numbers

Attribute is of class L<XT::Data::Telephone>.
If Delivery contact details are provided it populates them else
defaults to billing details.

=cut

has delivery_telephone_numbers => (
    is          => 'rw',
    isa         => 'ArrayRef[XT::Data::Telephone]',
    traits      => ['Array'],
    lazy        => 1,
    default     => sub {
        return shift->billing_telephone_numbers;
    },
    handles     => {
        add_delivery_telephone_number           => 'push',
        all_delivery_telephone_numbers          => 'elements',
        number_of_delivery_telephone_numbers    => 'count',
    },
);

=head2 delivery_email

Defaults to billing email if not provided.

=cut

has delivery_email => (
    is          => 'rw',
    isa         => 'Str',
    lazy        => 1,
    default => sub {
        return shift->billing_email;
    },

);

=head2 nominated_delivery_date : DateTime | Undef

If there is a Nominated Day (the customer has chosen a specific day to
receive the shipment), this is that Nominated Day date.

=cut

has nominated_delivery_date => (
    is          => 'rw',
    isa         => 'XT::Data::Types::DateStamp | Undef',
    coerce      => 1,
);

=head2 nominated_dispatch_date : DateTime | Undef

If there is a Nominated Day, this is the date when the goods need to
be dispatched, i.e. leave the DC.

=cut

has nominated_dispatch_date => (
    is          => 'rw',
    isa         => 'XT::Data::Types::DateStamp | Undef',
    coerce      => 1,
);

=head2 nominated_day : XT::Data::NominatedDay::Order

Nominated Day calculation, used to determine the dispatch_time and
selection_time from the Nominated Day dates.

=cut

has nominated_day => (
    is      => 'rw',
    isa     => 'XT::Data::NominatedDay::Order',
    lazy    => 1,
    default => sub {
        my $self = shift;
        XT::Data::NominatedDay::Order->new({
            schema           => $self->schema,
            delivery_date    => $self->nominated_delivery_date,
            dispatch_date    => $self->nominated_dispatch_date,
            shipping_charge  => $self->shipping_charge,
            shipping_account => $self->shipping_account,
            order_number     => $self->order_number,
            timezone         => $self->channel->timezone,
        });
    },
    handles => {
        nominated_dispatch_time => "dispatch_time",
    },
);

=head2 customer_category_id

=cut

has customer_category_id => (
    is          => 'rw',
    isa         => 'Int',
    required    => 0,
);

=head2 preorder

=cut

has preorder => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::PreOrder',
    required    => 0,
);

=head2 preorder_number

=cut

has preorder_number => (
    is          => 'rw',
    isa         => 'Str | Undef',
    required    => 0,
);

=head2 language_preference
=cut

has language_preference => (
    is          => 'rw',
    isa         => 'Str | Undef',
    required    => 0
);


=head2 tender_sum

   Sum of all tenders values

=cut

has tender_sum => (
    is          => 'rw',
    isa         => 'Num',
    lazy_build  => 1,
);

=head2 nominated_dispatch_time : DateTime | Undef

If there is a Nominated Day, this is the datetime when the goods need
to be dispatched, i.e. leave the DC. This is based on the
nominated_dispatch_date.

=cut

=head2 nominated_earliest_selection_time : XT::Data::Types::TimeStamp | Undef

If there is a Nominated Day, this is the earliest datetime when the
goods are ready for Selection. If they are Selected before this time,
they might be dispatched too early by mistake and reach the Customer a
day early.

This is the (all in localtime) carrier.last_pickup_daytime on the date
before the nominated_dispatch_time.

=cut

sub nominated_earliest_selection_time {
    my ($self, $dc_time_zone) = @_;
    $self->nominated_day->earliest_selection_time;
}

=head2 line_items

=cut

has line_items => (
    is          => 'ro',
    isa         => 'ArrayRef[XT::Data::Order::LineItem]',
    required    => 1,
    traits      => ['Array'],
    default     => sub { [] },
    handles     => {
        add_line_item           => 'push',
        all_line_items          => 'elements',
        number_of_line_items    => 'count',
        remove_line_items       => 'splice',
    },
);

=head2 is_free_shipping

=cut

has is_free_shipping => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

=head2 free_shipping

=cut

has free_shipping => (
    is          => 'rw',
    isa         => 'XT::Data::Order::CostReduction|Undef',
);

=head2 is_gift_order

=cut

has is_gift_order => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

=head2 shipping_sku

=cut

has shipping_sku => (
    is          => 'rw',
    isa         => 'Str',
);

=head2 gift_message

=cut

has gift_message => (
    is          => 'rw',
    isa         => 'Str|Undef',
);

=head2 sticker

=cut

has sticker => (
    is          => 'rw',
    isa         => 'Str|Undef',
);

=head2 packing_instructions

=cut

has packing_instruction => (
    is          => 'rw',
    isa         => 'Str',
);

=head2 shipping_charge

=cut

has shipping_charge => (
    is  => 'rw',
    isa => 'XTracker::Schema::Result::Public::ShippingCharge',
);

=head2 gross_total

Attribute is of class L<XT::Data::Money>.

=cut

# FIXME: can we remove this as it is only used in the test?
has gross_total => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

=head2 order_premier_routing_id : Int|Undef

=cut

has order_premier_routing_id => (
    is          => 'rw',
    isa         => 'Int|Undef',
    required    => 0,
);

=head2 premier_routing_id : Int|Undef

=cut

sub premier_routing_id {
    my $self = shift;

    # this is to help transition - if the website sends over a
    # premier_routing_id then this takes precedence over what is provided
    # by the shipping_charge
    if ($self->order_premier_routing_id) {
        return $self->order_premier_routing_id;
    }

    my $shipping_charge = $self->shipping_charge or return undef;
    return $shipping_charge->premier_routing_id;
}

=head2 shipment_status_id

=cut

has shipment_status_id => (
    is          => 'rw',
    isa         => 'Str',
    default     => $SHIPMENT_STATUS__PROCESSING,
);

=head2 signature_required

Used to set the Shipment record's 'signature_required' flag, default is TRUE the Customer must Sign
for their package at the point of Delivery. So far only used in DC2 for US Domestic Shipments, so
DC1 should always be TRUE.

=cut

has signature_required  => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 1,
);

=head2 _hotlist_cache

=cut

has _hotlist_cache => (
    is          => 'rw',
);

=head2 _is_staff_shipping_sku

This is a boolean helper accessor, default is FALSE. If we modify the shipping
type for an order to a internal/staff shipping SKU we set this so we can add a
note to the order saying this has happened.

This makes it more obvious when some magic has occurred in the depths of the
order importer.

=cut

has _is_staff_shipping_sku => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

=head2 gift_line_items

CANDO-326: This holds the contents of the <GIFT_LINE> tags in the Order XML file.

=cut

has gift_line_items => (
    is          => 'ro',
    isa         => 'ArrayRef[XT::Data::Order::GiftLineItem]',
    required    => 1,
    traits      => ['Array'],
    default     => sub { [] },
    handles     => {
        add_gift_line_item           => 'push',
        all_gift_line_items          => 'elements',
        number_of_gift_line_items    => 'count',
        remove_gift_line_items       => 'splice',
    },
);

=head2 _fraud_exception

CANDO-491: This holds all the values we need to check for credit hold exception rule

=cut

has _fraud_exception => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub  { {} },
);

=head2 _credit_hold_exception_channel_list

CANDO-491: This holds list of key/value pair ($chanel_id => $channel_rs ) read
from database table system_config.config_group_setting for setting "_include_channel"

=cut

has _credit_hold_exception_channel_list => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

=head2 _credit_hold_exception_customer_list

CANDO-491: this holds list of key/value pair ($customer_id => $customer_rs )


=cut

has _credit_hold_exception_customer_list => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

=head2 _customer_rs

=cut

has _customer_rs => (
    is      => 'rw',
    isa     => 'XTracker::Schema::ResultSet::Public::Customer',
);


=head2 _fraud_check_rating_adjustment

=cut
has _fraud_check_rating_adjustment  => (
    is            => 'rw',
    isa           => 'HashRef',
    lazy_build    => 1,
);
=head2 _order_total_value

=cut

has _order_total_value => (
    is          => 'rw',
    isa         => 'Num',
);

=head2 _payment_card

=cut

has _payment_card => (
    is          => 'rw',
    isa         => 'XT::Data::Order::Tender',
);

=head2 _run_fraud_rules_in_parallel

A Boolean Flag to indicate the a Job should be placed on
the Job Queue to process the Fraud Rules for the Order
in Parallel, this will be done Post Commit.

=cut

has _run_fraud_rules_in_parallel => (
    is          => 'rw',
    isa         => 'Bool',
    init_arg    => undef,
    default     => 0,
);

=head2 _fraud_rules_outcome

This will hold the Fraud Rules Outcome object that
is populated by the Fraud Rules Engine then applying
the Fraud Rules to the Order.

This is used to send a Job to the Job Queue to update
the Fraud Rule Metrics that will need to be updated
after the Fraud Rules have been Applied.

=cut

has _fraud_rules_outcome => (
    is       => 'rw',
    isa      => 'Object|Undef',
    init_arg => undef,
    default  => undef,
);

=head2 source_app_name

An optional value passed from the front end specifying the name of the
app the order came from.

=cut

has source_app_name => (
    is          => 'ro',
    isa         => 'Str|Undef',
);

=head2 source_app_version

An optional value passed from the front end signifying the version of the
app the order came from.

=cut

has source_app_version => (
    is          => 'ro',
    isa         => 'Str|Undef',
);


=head2 _shipping_restrictions

Contains information about all the restricted products in an order

=cut

has _shipping_restrictions => (
    is          => 'rw',
    isa         => 'HashRef',
    default     => sub  { {} },
    predicate   => 'has_shipping_restrictions',
);

# Builds the 'channel' attribute.
sub _build_channel {
    my $self = shift;

    return $self->schema->resultset('Public::Channel')->find_by_web_name(
        $self->channel_name
    );
}

=head1 PUBLIC METHODS

=head2 add_tender ($tender)

Add a tender to this order. $tender should be of class
L<XT::Data::Order::Tender>.

=head2 tenders

Returns all tenders for this order

=head2 number_of_tenders

Returns number of tenders for this order

=head2 add_line_item ($line_item)

Add a line item to this order. $line_item should be of class
L<XT::Data::Order::LineItem>.

=head2 line_items

Returns all line items for this order

=head2 number_of_line_items

Returns number of line items for this order

=head2 premier_routing

    my $premier_routing = $order->premier_routing;

Returns the premier_routing row for the premier_routing_id present in the order.

=cut

sub premier_routing {
    my ( $self ) = @_;

    if ( defined $self->premier_routing_id ) {
        return $self->schema->resultset('Public::PremierRouting')->find(
            $self->premier_routing_id
        );
    }
    return;
}

=head2 shipment_charge

    my $shipment_charge = $order->shipment_charge;

Returns the shipment_charge row for the shipment_charge_id present in the order.

=cut

sub shipment_charge {
    my ( $self ) = @_;

    my $shipment_charge_rs = $self->schema->resultset('Public::ShipmentCharge');
    return $shipment_charge_rs->find({ id => $self->shipment_charge_id })->charge;
}

=head2 currency_id

    my $currency_id = $order->currency_id;

Returns the currency id for the first tender in the order.

=cut

sub currency_id {
    my ( $self ) = @_;

    my @tenders = $self->all_tenders;

    if ( $tenders[0] && $tenders[0]->value->currency) {
        return $tenders[0]->value->currency_id;
    }
    return undef;
}

=head2 psp_ref

    my $psp_ref = $order->psp_ref;

Return the PSP reference for the card tender (or undef).

=cut

sub psp_ref {
    my ( $self ) = @_;

    my $card_tender = $self->get_card_tender;

    return unless $card_tender;

    return $card_tender->provider_reference;

}

=head2 preauth_ref

    my $preauth_ref = $order->payment_pre_auth_ref;

Returns the payment pre auth ref, for the card tender, returned from the PSP
(or undef).

=cut

sub preauth_ref {
    my ( $self ) = @_;

    my $card_tender = $self->get_card_tender;

    return unless $card_tender;

    return $card_tender->payment_pre_auth_ref;
}

=head2 payment_method_rec

    my $orders_payment_method_rec = $order->payment_method_rec;

Returns the 'orders.payment_method' record that represents the
Payment Method used to pay for the order that is returned from
the PSP (or undef).

=cut

sub payment_method_rec {
    my $self    = shift;

    my $card_tender = $self->get_card_tender;

    return unless $card_tender;

    return $card_tender->payment_method;
}

=head2 get_card_tender

    my $card_tender = $order->get_card_tender;

Returns a tender of type 'Card Debit' or undef.

=cut

sub get_card_tender {
    my ( $self ) = @_;
    my @tenders = $self->all_tenders;

    foreach ( @tenders ) {
        return $_ if $_->type eq 'Card Debit';
    }

    return;
}

=head2 has_card_tender

    if ( $order->has_card_tender ) { ... }

Returns true if the order has any 'Card Debit' tender lines.

=cut

sub has_card_tender {
    my ( $self ) = @_;

    return $self->get_card_tender;
}

=head2 extract_money

    my $value = $order->extract_money( $money_attribute );

Returns the value attribute of the L<XT::Data::Money> attribute specified.

=cut

sub extract_money {
    my ( $self, $attribute ) = @_;

    croak "$attribute is not a valid attribute"
        unless $attribute and $self->meta->has_attribute( $attribute );

    if ( $self->$attribute ) {
        return $self->$attribute->value;
    }

    return 0;
}

=head2 primary_phone

    my $phone = $order->primary_phone;

Returns the first non-blank phone number that is not a mobile telephone number.

=cut

sub primary_phone {
    my ( $self ) = @_;

    foreach ($self->all_billing_telephone_numbers) {
        next if $_->type eq 'mobile_telephone'; # Has to be either home or work
        if ( $_->number && $_->number ne '' ) {
            return $_->number;
        }
    }
    return '';
}

=head2 mobile_phone

    my $mobile_phone = $order->mobile_phone

Return the mobile phone number (or an empty string).

=cut

sub mobile_phone {
    my ( $self ) = @_;

    foreach ($self->all_billing_telephone_numbers) {
        return $_->number if $_->type eq 'mobile_telephone' and $_->number;
    }

    # FIXME EWWWWW see XTracker::Schema::ResultSet::Public::Orders
    return '';
}

=head2 address hash

Returns MD5 sum of address

=cut

sub address_hash {
    my ( $self, $type ) = @_;

    croak 'Address type required' unless $type;

    my $address = $type . '_address';
    my $name    = $type . '_name';

    my $data;

    $data->{first_name}     = $self->$name->first_name;
    $data->{last_name}      = $self->$name->last_name;
    $data->{address_line_1} = $self->$address->line_1;
    $data->{address_line_2} = $self->$address->line_2;
    $data->{address_line_3} = $self->$address->line_3;
    $data->{towncity}       = $self->$address->town;
    $data->{postcode}       = $self->$address->postcode;
    $data->{country}        = $self->$address->country->country;
    $data->{county}         = $self->$address->county;

    my $md5 = Digest::MD5->new;

    foreach my $addressline ( sort keys %{$data} ) {
        $md5->add( encode_it($data->{$addressline}) );
    }

    my $address_hash = $md5->b64digest;

    return $address_hash;

}

=head2 shipping_account

Return correct shipping account for this order

=cut

sub shipping_account {
    my $self = shift;

    if ($self->_virtual_voucher_only_order) {
        return $self->channel->shipping_accounts->find_no_shipment();
    }

    if ($self->_is_premier_shipment) {
        return $self->channel->shipping_accounts->find_premier();
    }

    my $account_country = $self->channel->shipping_account__countries->find_by_country(
        $self->delivery_address->country->country,
    )->first;
    return $account_country->shipping_account if $account_country;

    # there is a shipping_account__countries table, but apparently it
    # doesn't make sense to use it atm.

    return $self->channel->shipping_accounts
        ->by_default_carrier( $self->shipping_charge->is_ground )
        ->by_name( $self->_shipping_account_name() )
        ->slice(0,0)
        ->single;
}

=head2 digest

Digest the XT::Data::Order object, store it as rows in the relevant tables,
do as much preprocess processing as possible without human intervention, and update
the website on the status of the order.

=cut

sub digest {
    my($self, $args) = @_;

    my $result = $self->schema->resultset('Public::Orders')->find({
        order_nr   => $self->order_number,
        channel_id => $self->channel()->id,
    });

    if ($result) {
        $logger->warn('DUPLICATE: Order '.$self->order_number.' rejected for '.$self->channel_name);
        $args->{duplicate}  = 1     if ( exists( $args->{duplicate} ) );
        return $result;
    }
    else {
        return $self->_attempt_with_deadlock_recovery(
            config_section_slurp( 'ParallelOrderImporterTunableParameters' ),
            sub {
                my $self = shift;

                my $guard = $self->schema->txn_scope_guard();

                $self->_preprocess;

                my $order = $self->_save;

                $self->_post_save( $order );

                $guard->commit unless $args->{skip};

                $self->_post_commit_processing( $order );

                $self->_post_save_voucher_processing( $order );

                return $order;
            }
        );
    }
}

=head2 get_customer_category

    my $category = $order->get_customer_category;

Looks up the customer category by looking at the customers billing email address.

=cut

sub get_customer_category {
    my ( $self ) = @_;

    # find an Existing Customer and return the Category
    my $customer = $self->channel->search_related( 'customers', {
        is_customer_number => $self->customer_number,
    }, { order_by => 'id' } )->first;   # order by Id and take the first in case of dupes
    if ( $customer ) {
        return $customer->category;
    }

    my ($name, $domain) = split /@/, $self->billing_email;

    my $category_rs = $self->schema->resultset('Public::CustomerCategoryDefault');

    my $default = $self->schema->resultset('Public::CustomerCategory')->find(
        $CUSTOMER_CATEGORY__NONE
    );

    $domain //= '';
    $domain =~ s/ //g;
    my $category = $category_rs->search({
        'TRIM(LOWER(email_domain))' => lc( $domain ),
    }, { order_by => 'id' } )->slice(0,0)->single;

    return $default unless $category;

    return $category->category;
}

=head1 PRIVATE METHODS
=cut

=head2 _preprocess

Read (not write) data to populate the XT::Data::Order object completely
in preparation for saving it

=cut

sub _preprocess {
    my $self = shift;

    $self->_preprocess_fix_exporter_issues;
    $self->_preprocess_customer;
    $self->_preprocess_sku;
    $self->_preprocess_tender;
    $self->_preprocess_shipment;
    $self->_preprocess_cost_reduction;
    $self->_check_integrity;
}

=head2 _save

    $order->_save;

Save the order object to the database.

=cut

sub _save {
    my ( $self ) = @_;

    my $order;
    my $customer = $self->_create_or_update_customer;
    $order = $self->_create_order( $customer );
    $self->_create_payment( $order );
    my $shipment = $self->_create_shipment( $order );

    if ($shipment->nominated_dispatch_time) {
        XT::Data::NominatedDay::Shipment->new()->check_daily_cap(
            $shipment->nominated_dispatch_time,
        );
    }

    return $order; # The DBIC row representing the order
}

=head2 _create_or_update_customer

    $order->_create_or_update_customer

Creates the customer for the order.

=cut

sub _create_or_update_customer {
    my $self = shift;

    my @telephones = $self->all_billing_telephone_numbers;

    my $channel = $self->channel;

    die "Cannot find channel for '". $self->channel_name ."'"
        if (!defined $channel);

    # We have a horrible bug where we have duplicate customers with the same
    # customer number. This causes a simpler search like _find_or_new_related to
    # fail if there are one customers returned from find.
    #
    # If we return more than one customer, we're gonna order by id and hope that
    # the original customer is the correct customer.
    my $customer = $channel->search_related( 'customers', {
        is_customer_number => $self->customer_number,
        channel_id         => $channel->id,
    }, { order_by => 'id' })->first;

    if ( $customer ) {
        $customer->set_columns({
            first_name              => $self->billing_name->first_name,
            last_name               => $self->billing_name->last_name,
            email                   => $self->billing_email,
        });
        $customer->set_column( title => $self->billing_name->title )
            if $self->billing_name->title;
        $customer->set_column( telephone_1 => $telephones[0]->number )
            if $telephones[0] && $telephones[0]->number;
        $customer->set_column( telephone_2 => $telephones[1]->number )
            if $telephones[1] && $telephones[1]->number;
        $customer->set_column( telephone_3 => $telephones[2]->number )
            if $telephones[2] && $telephones[2]->number;

        # Add the Seaview account URN *only* if it's not already there
        if( $self->account_urn
              && !defined $customer->account_urn ){
            $customer->set_column( account_urn => $self->account_urn )
        }

        $customer->update;
    }
    else {
        $customer = $channel->create_related( 'customers', {
            is_customer_number      => $self->customer_number,
            title                   => $self->billing_name->title,
            first_name              => $self->billing_name->first_name,
            last_name               => $self->billing_name->last_name,
            email                   => $self->billing_email,
            telephone_1             => ( $telephones[0] && $telephones[0]->number ),
            telephone_2             => ( $telephones[1] && $telephones[1]->number ),
            telephone_3             => ( $telephones[2] && $telephones[2]->number ),
            ddu_terms_accepted      => 0,
            credit_check            => undef,
            group_id                => 1,
            legacy_comment          => undef,
            no_marketing_contact    => undef,
            no_signature_required   => 0,
            category_id             => $self->customer_category_id,
            account_urn             => $self->account_urn,
        })
    }

    # CANDO-1386: Set language preference for customer
    if ($self->language_preference && !$customer->has_language_preference) {
        $logger->debug('No language preference found. Updating table');
        $customer->set_language_preference($self->language_preference);
    }

    # CANDO-7833: Update customer language for JC customers on every order
    #             if a language has been passed in and that language is
    #             supported for that channel (if the language is not supported
    #             we use the default language).
    if ( defined $self->language_preference && $channel->update_customer_language_on_every_order ) {

        my $language =  $channel->supports_language( $self->language_preference ) ?
                                                       $self->language_preference :
                                                       $self->schema->resultset('Public::Language')->get_default_language_preference->code;

        $customer->set_language_preference($language);

    }

    return $customer;
}

=head2 _create_order

    $order->create_order( $customer );

Add the order associated with the customer.

=cut

sub _create_order {
    my ( $self, $customer ) = @_;

    my $order = $customer->add_order( $self );

    if ($self->preorder_number) {
        $self->preorder(get_pre_order_by_number($self->schema, $self->preorder_number));
        $order->link_with_preorder($self->preorder_number);
    }

    return $order;
}

=head2 _create_payment

    $order->create_payment( $order) ;

Add the payments associated with the order.

=cut

sub _create_payment {
    my ( $self, $order ) = @_;

    $order->add_order_payment( $self ) if $self->has_card_tender;
}

=head2 _create_shipment

    $order->_create_shipment( $order );

Create the shipments associated with the order.

=cut

sub _create_shipment {
    my ( $self, $order ) = @_;

    my $shipment = $order->add_shipment( $self );

    if ($self->_is_staff_shipping_sku) {
        $order->create_related( 'order_notes', {
            note            => q{Shipment method was automatically changed to 'internal staff'},
            note_type_id    => $NOTE_TYPE__SHIPPING,
            operator_id     => $APPLICATION_OPERATOR_ID,
            date            => DateTime->now( time_zone => 'local' ),
        } );
    }

    # Let's broadcast stock levels, as they've now changed
    $shipment->broadcast_stock_levels();

    return $shipment;
}

=head2 _create_sales_invoice_for_preorder

    $order->_create_sale_invoice_for_preorder( $order );

Creates a Sales Invoice for a Pre-Order. This is ahead of Packing.

=cut

sub _create_sales_invoice_for_preorder {
    my ( $self, $order )    = @_;

    create_sales_invoice_for_preorder_shipment( $self->schema, $order->get_standard_class_shipment );

    return;
}


=head2 _check_restrictions_and_validate_address($shipment) :

Checks the shipment for shipping restrictions and validates its address.

=cut

sub _check_restrictions_and_validate_address {
    my ( $self, $shipment, $operator_id ) = @_;

    # check for restricted items in shipment
    $self->_shipping_restrictions(
        check_shipment_restrictions( $self->schema,
            { shipment_id => $shipment->id, send_email  => 1, }
        )
    );

    $shipment->validate_address({operator_id => $operator_id});

    return;
}

=head3 _preprocess_fix_exporter_issues

This fixes any Issues that should really be fixed in the Exporter but
can't be. This is called within the '_preprocess' method.

=cut

sub _preprocess_fix_exporter_issues {
    my $self = shift;

    if ( is_valid_pre_order_number( $self->preorder_number ) ) {
        # if the Order is from a Pre-Order then sort out the Address
        # I know there is some code elsewhere that deals with Pre-Orders
        # but I don't want to re-do the logic of the importer as really
        # this section shouldn't even be here and if the Exporter gets
        # fixed then we could remove this section altogether
        my $pre_order = get_pre_order_by_number( $self->schema, $self->preorder_number );

        # fix the missing County issues with Pre-Order Orders but only
        # do so if the Pre-Order addresses have a county themselves &
        # the Order's Addresses don't have a county
        my $pre_order_billing_address  = $pre_order->invoice_address;
        my $pre_order_delivery_address = $pre_order->shipment_address;

        if ( my $county = $pre_order_billing_address->county ) {
            $self->billing_address->county( $county )   unless ( $self->billing_address->county );
        }
        if ( my $county = $pre_order_delivery_address->county ) {
            $self->delivery_address->county( $county )  unless ( $self->delivery_address->county );
        }
    }
}

=head3 _preprocess_customer

Prepare customer data and change to staff shipping sku if staff

=cut

sub _preprocess_customer {
    my $self = shift;

    # its still worth deducing what category we think the customer should be
    # in even if we might have an existing customer..
    my $category = $self->get_customer_category;
    $self->customer_category_id($category->id);

    # ..because we might want to do early short circuits like making all
    # staff order be under a different shipping_sku - a different staff
    # shipping sku per channel
    if ($self->customer_category_id == $CUSTOMER_CATEGORY__STAFF) {
        my $staff_sku = internal_staff_shipping_sku(
            $self->schema,$self->channel->id);

        if ($staff_sku) {
            $self->shipping_sku($staff_sku);
            $self->nominated_delivery_date(undef);
            $self->nominated_dispatch_date(undef);
            $self->_is_staff_shipping_sku(1);
        }
    }
}

=head3 _preprocess_sku

Loop through all the line items associated with this order and look up the SKU if
we only have a third party SKU.

=cut

sub _preprocess_sku {
    my $self = shift;

    my @line_items = $self->all_line_items;
    foreach ( @line_items ) {
        if ( !$_->sku && $_->third_party_sku ) {
            my $variant = $self->schema->resultset(
                'Public::ThirdPartySku'
            )->find_variant_by_sku({
                sku         => $_->third_party_sku,
                business_id => $self->channel->business->id,
            });

            $_->sku( $variant->sku );
        }
    }
}

sub _preprocess_tender {
    my $self = shift;

    my @tenders = $self->all_tenders;

    # payment info - credit card and store credits
    croak "There are no tenders associated with this order!!" unless scalar @tenders;

    foreach my $tender (@tenders) {
        # credit card
        if ($tender->type eq "Card Debit") {
            $self->transaction_value($tender->get_payment_value_from_psp());
        }
        # store credit
        elsif ($tender->type eq "Store Credit") {
            $self->store_credit ( $tender->value->clone );
            $self->store_credit->multiply_value(-1);
        }
        # FIXME Pending confirmation from Manish - there's no longer such thing.
        # I guess we just need to make sure none of the old ones are still valid.
        ## gift credit
        #elsif ($tender->type eq "Gift Credit") {
            #$self->gift_credit ( $tender->value  );
        #}
        elsif ($tender->type eq "Voucher Credit") {
            $self->voucher_credit ($tender->value );
            croak "Voucher code missing"
                unless defined $tender->voucher_code
                    and length $tender->voucher_code;
        }
        else {
            croak "Invalid tender type: ".$tender->type;
        }

    }
}

=head3 _preprocess_cost_reduction

For each line item in ($self->line_items) populate

    $line_item->cost_reduction (which is a XT::Data::Order::CostReduction)

adding the reduction of unit_price, tax and duties.
This will be stored in link_shipment_item__promotion when saving.

=cut

sub _preprocess_cost_reduction {
    my $self = shift;

    foreach my $line_item ($self->all_line_items) {
        $line_item->preprocess_cost_reduction;
    }

}


=head3 _check_integrity

There following amounts should be equal

1. The sum of the tender lines ($self->tenders)
2. The sum of the order line items
3. The gross total of the order

We should also check that

4. amount verified by psp  =  the card tender line

If any of these fail we should die and email it?

=cut

sub _check_integrity {
    my $self = shift;
    my (@integrity_warnings, @integrity_errors);

    # All variant channels should match the order channel;
    # it's freaky and should never be any other way but that doesn't mean we
    # want to allow it to silently occur
    my $order_channel = $self->channel;
    foreach my $line_item ($self->all_line_items) {
        my $variant = $self->schema
            ->resultset('Any::Variant')
                ->find_by_sku( $line_item->sku );
        ;

        if (not defined $variant) {
            push @integrity_errors, sprintf(
                'variant %s: no matching SKU found in database',
                $line_item->sku
            );
            next;
        }

        my $line_item_channel = $variant->current_channel;

        if ($order_channel->id != $line_item_channel->id) {
            push @integrity_warnings, sprintf(
                'variant %s: variant channel [%s (%d)] does not match order channel [%s (%d)]',
                $line_item->sku,
                $line_item_channel->name,
                $line_item_channel->id,
                $order_channel->name,
                $order_channel->id,
            );
        }
    }

    # The sum of the tender lines
    my $tender_sum = $self->tender_sum;

    # the sum of the order lines
    my $line_item_sum = 0;
    for ($self->all_line_items) {
        $line_item_sum += $_->total;
    }

    # add shipping fees
    $line_item_sum += $self->shipping_total;

    my $line_item_sum_value = $line_item_sum->value;

    # Strange rounding(?) error occuring, so we're forcing to 2 decimal places
    unless ( sprintf("%.2f",$tender_sum) == sprintf("%.2f",$line_item_sum_value) ) {
        my $order_number =  $self->order_number;

        carp "Order: $order_number".
            ": Mismatch between tender_sum ($tender_sum) and line_item_sum ($line_item_sum_value)";

        send_email(
            config_var('Email', 'xtracker_email'),
            config_var('Email', 'xtracker_email'),
            config_var('Email', 'xtracker_email'),
            "Order Import Error",
            qq{
Payment mismatch for Order Nr: $order_number

PAYMENT VALUE:      $tender_sum
CALCULATED VALUE:   $line_item_sum_value

Have a nice day,
xTracker
}
        );
    }

    # amount verified by psp  =  the card tender line
    for ($self->all_tenders) {
        next unless $_->type eq 'Card';
        if (not $_->card_tender_equals_psp_value) {
            push @integrity_errors,
                "Order: ".$self->order_number
                . ': Mismatch between card tender value '.$_->value .' and psp response'
        }
    }

    # deal with any integrity issues we discovered
    if (@integrity_warnings) {
        my $warnings = join(
            qq{\n},
            map { " * $_" } @integrity_warnings
        );

        # for some reason we're sending this to 'xtracker_email' and not
        # someone who might investigate the problem
        my $the_mail_address = config_var('Email', 'xtracker_email');
        send_email(
            $the_mail_address,
            $the_mail_address,
            $the_mail_address,
            "Order Import Warning: order #" . $self->order_number,
            qq{
There were one or more warnings with the order:

$warnings

Despite these, processing of this order continued.}
        );
    }

    if (@integrity_errors) {
        my $errors = join(
            qq{\n},
            map { " * $_" } @integrity_errors
        );

        # for some reason we're sending this to 'xtracker_email' and not
        # someone who might investigate the problem
        my $the_mail_address = config_var('Email', 'xtracker_email');
        send_email(
            $the_mail_address,
            $the_mail_address,
            $the_mail_address,
            "Order Import Error: order #" . $self->order_number,
            qq{
There were one or more problems with the order:

$errors

Processing of this order has been aborted.}
        );

        # raise an exception
        die $errors;
    }

    return 1;
}


=head3 _preprocess_shipment

Prepare a hashref in

    shipment_data

for sending to

    XTracker::Database::Shipment::create_shipment


=cut

sub _preprocess_shipment {
    my $self = shift;

    my $zero = XT::Data::Money->new({
        schema      => $self->schema,
        currency    => $self->line_items->[0]->unit_net_price->currency,
        value       => 0,
    });

    # extract shipping items from line items
    my @line_items = $self->all_line_items;
    my @indexes_to_remove;

    my $is_gift_order = $self->is_gift_order;

    while (my($index, $line_item) = each @line_items) {

        # triple check whether this is a gift order or not
        if ( !($is_gift_order) && $line_item->is_physical ) {
            if ( $line_item->is_gift ) {
                $self->is_gift_order( 1 );
            }
            else {
                $self->is_gift_order( 0 );
            }
        }

        # there should almost be a check to ensure we only have 1 of these
        if (my $shipping_charge = $line_item->shipping_charge) {

            $self->shipping_charge( $shipping_charge );
            $self->shipping_net_price( $line_item->unit_net_price );
            $self->shipping_tax( $line_item->tax );
            $self->shipping_duties( $line_item->duties );

            push@indexes_to_remove, $index;
        }
        if (my $packing_instruction = $line_item->packing_instruction) {
            $self->packing_instruction( $line_item->description );

            push@indexes_to_remove, $index;
        }
    }

     # remove this item
     $self->remove_line_items($_, 1) for reverse sort { $a <=> $b } @indexes_to_remove;

    # copy billing address > shipping_address if this is a virtual voucher only order
    if ($self->_virtual_voucher_only_order) {
        $self->delivery_address( $self->billing_address->clone );
        $self->shipping_charge(
            $self->schema->resultset('Public::ShippingCharge')->find_unknown
        ); # No shipping charge for virtual vouchers

        $self->shipping_net_price( $zero );
        $self->shipping_tax( $zero );
        $self->shipping_duties( $zero );
    }

    if (defined $self->shipping_sku) {
        my $charge = $self->schema->resultset('Public::ShippingCharge')
            ->find_by_sku( $self->shipping_sku );

        if (defined $charge) {
            $self->shipping_charge( $charge );
        } else {
            warn "shipping charge: UNSET";
        }
    }

    # if its still not set then make it have a zero money for less suffering
    if (!defined $self->shipping_charge) {

        $self->shipping_net_price( $zero );
        $self->shipping_tax( $zero );
        $self->shipping_duties( $zero );
    }

   # APS-1713 UPS-API Automation failure for Jimmy Choo
   # UPS automation failure because Jimmy Choo orders comming through with mixed case county code eg 'Ca'
   # Force all county codes to be uppercase if their two characters and country is United States
   $self->delivery_address->county(uc($self->delivery_address->county)) if
       ($self->delivery_address->country->id == $COUNTRY__UNITED_STATES) && (length($self->delivery_address->county) == 2);

}

=head2 _virtual_voucher_only_order

Returns true if this order is for virtual vouchers only

=cut

sub _virtual_voucher_only_order {
    my $self = shift;

    my @virtual_vouchers = $self->_all_virtual_vouchers;
    return @virtual_vouchers == $self->number_of_line_items;
}

=head2 _is_premier_shipment

Returns true if this order is a premier shipment.

=cut

sub _is_premier_shipment {
    my $self = shift;
    return $self->shipment_type->id == $SHIPMENT_TYPE__PREMIER;
}

=head _shipping_account_name() : $name

Translate the shipment_type of this Order into a Shipping Acount name.

(This is a missing db relationship, implemented in code)

=cut

sub _shipping_account_name {
    my $self = shift;

    my $account_name = $self->shipment_type->type;

    # International DDU doesn't map to anything and has to be
    # changed to International
    $account_name = 'International'
        if $account_name eq 'International DDU';

    # If shipment class is Ground and shipment type is International
    # it should be International Road
    #
    # This should only happen in DC1, because all Ground shipments in
    # the US (DC2) are Domestic. If this assumption doesn't hold for
    # e.g. DC3, consider rewriting the caller of this method to
    # correctly identify the shipping_account (possibly by adding more
    # metadata to the shipping tables) instead of relying on the
    # names.
    $account_name = 'International Road'
        if $account_name eq 'International' && $self->shipping_charge->is_ground;

    return $account_name;
}

=head2 _post_save


=cut

sub _post_save {
    my($self,$order) = @_;

    $self->_check_staff_order($order);
    $self->_process_reservations($order);

    my $operator_id = $APPLICATION_OPERATOR_ID;
    $self->_check_restrictions_and_validate_address(
        $order->shipments->first, $operator_id
    );
    $self->_check_ddu_acceptance($order,$operator_id);

    # Use the Original Fraud Rules if the Fraud Rules Engine
    # switch is 'Off' or switched to 'Parallel'
    if ( $self->channel->is_fraud_rules_engine_off
      || $self->channel->is_fraud_rules_engine_in_parallel ) {
        my $t0  = Benchmark->new;
        $self->_apply_credit_rating($order,$operator_id);
        my $t1  = Benchmark->new;
        my $td  = timediff( $t1, $t0 );
        my $order_info = $self->channel->name . ", Order Nr: " . $order->order_nr;
        $benchmark_logger->info( "OI, Fraud Rules - ${order_info} - BENCHMARK - Existing, Total Time = '" . timestr( $td, 'all' ) . "'" );
    }

    # Use the Fraud Rules Engine if the Fraud Rules Engine
    # switch is 'On' or switched to 'Parallel'
    if ( $self->channel->is_fraud_rules_engine_in_parallel
      || $self->channel->is_fraud_rules_engine_on ) {
        $self->_apply_fraud_rules( $order );
    }

    # CANDO-1706 : If order has any virtual voucher, add flag
    if( $self->_has_virtual_vouchers ) {
        $order->add_flag_once( $FLAG__VIRTUAL_VOUCHER );
    }

    if ($self->preorder_number) {
        $self->_check_valid_preorder($order,$operator_id);
        $self->_create_sales_invoice_for_preorder( $order );

        #check if there is any shipping restrictions
        $self->_send_email_alert_for_preorder($order );
    }
    else {
        $self->_check_valid_order($order,$operator_id);
    }

    $self->_apply_channel_specifics($order);

    $self->_apply_third_party_payment_status( $order );

    #apply 1p difference
    #due to rounding issues in frontend we get tender values 1p less than the total order value.
    $self->_apply_1p_difference( $order );

    $self->_fix_telephone_numbers_for_pre_orders( $order );
}

=head2 _apply_1p_difference

    Find difference between total order value and sum of all tenders.
    If the total tender sum is 1p less than order total and there is a
    card tender then it adds 1p to card tender. For all other cases it
    skips.

=cut

sub _apply_1p_difference {
    my $self    = shift;
    my $order   = shift;

    my $diff = sprintf("%.2f",$order->total_value) - sprintf("%.2f",$self->tender_sum);
    $diff    = sprintf("%.2f", $diff);

    # just to catch rounding off errors
    if( $diff > 0 && $diff <= .014 ) {
        my @tenders = $self->all_tenders;
        if ( grep{ $_->type eq 'Card Debit' } @tenders ) {
            $logger->error( "1P DIFF : Adjusting Card tender by 1p for Order Number ". $self->order_number. " as it has difference of: ".$diff);
            update_card_tender_value($order, $diff);
        }
    }
}

=head2 _apply_fraud_rules

    $self->_apply_fraud_rules( $dbic_order_object );

Will use the Fraud Rules Engine to apply the Fraud Rules in
either 'Parallel' or 'Live' mode.

=cut

sub _apply_fraud_rules {
    my ( $self, $order )    = @_;

    if ( $self->channel->is_fraud_rules_engine_on ) {
        eval {
            my $t0  = Benchmark->new;
            my $engine = XT::FraudRules::Engine->new( {
                order   => $order,
                mode    => 'live',
            } );
            my $t1  = Benchmark->new;
            $engine->apply_finance_flags;
            my $t2  = Benchmark->new;
            # apply Rules except for a Pre-Order Order
            if ( !$self->preorder_number ) {
                $engine->apply_rules;
                # store the Outcome to be used later
                # for sending the Update Metrics Job
                $self->_fraud_rules_outcome( $engine->outcome );
            }
            else {
                $logger->info( 'Order: ' . $order->order_nr . ' is a preorder. Not applying Fraud Rules' );
                $order->accept_or_hold_order_after_fraud_check( $ORDER_STATUS__ACCEPTED );
            }
            my $t3  = Benchmark->new;
            my $log_prefix  = 'OI, Fraud Rules - ' .
                              $self->channel->name . ', Order Nr: ' . $order->order_nr .
                              ' - BENCHMARK - CONRAD';
            $benchmark_logger->info( "${log_prefix}, to Instantiate - '" . timestr( timediff( $t1, $t0 ), 'all' ) . "'" );
            $benchmark_logger->info( "${log_prefix}, to Apply Flags - '" . timestr( timediff( $t2, $t1 ), 'all' ) . "'" );
            $benchmark_logger->info( "${log_prefix}, to Apply Rules - '" . timestr( timediff( $t3, $t2 ), 'all' ) . "'" );
            $benchmark_logger->info( "${log_prefix}, Total Time     = '" . timestr( timediff( $t3, $t0 ), 'all' ) . "'" );
        };
        if ( my $err = $@ ) {
            $logger->error( "Sales Channel: '" . $self->channel_name . "', Order Number: '" . $order->order_nr . "'"
                            . " - Fraud Rules Engine COULDN'T RUN, will NOW use Fallback: ${err}" );

            #
            # use the long standing way as a Fallback
            #

            # remove any Flags the Rules Engine might have created
            $order->discard_changes->order_flags->delete;
            # remove any Order Status Logs
            $order->order_status_logs->delete;

            # apply the old Rules
            $self->_apply_credit_rating( $order, $APPLICATION_OPERATOR_ID );
        }
    }
    else {
        # Flag the Fraud Rules to be run in Parallel in the
        # '_post_commit_processing' method providing the Order
        # isn't for a Pre-Order
        if ( !$self->preorder_number ) {
            $self->_run_fraud_rules_in_parallel( 1 );
        }
        else {
            $logger->debug( 'Order: ' . $order->order_nr . ' is a preorder. Not Running Fraud Rules in Parallel' );
        }
    }

    return;
}

=head2 _check_staff_order

=cut

sub _check_staff_order {
    my($self,$order) = @_;

    # If the Customer is 'Staff' then change shipment type to being 'PREMIER'
    # if Order's Sales Channel Matches
    if ($order->customer->category->id == $CUSTOMER_CATEGORY__STAFF) {
        if ( is_staff_order_premier_channel( $order->order_channel->business->config_section ) ) {
            for my $shipment ($order->shipments) {
                my $shipping_account = $self->channel->shipping_accounts->find_premier;
                $shipment->update({
                    shipment_type_id    => $SHIPMENT_TYPE__PREMIER,
                    shipping_account_id => defined $shipping_account ? $shipping_account->id : 0,
                });
            }
        }
    }
}



=head2 _process_reservations

check if the order matched any reservations if so, create the link between
shipment_item and reservation

=cut

sub _process_reservations {
    my $self = shift;
    my $order_dbix = shift;

    my $reservation;

    for my $shipment ($order_dbix->shipments) {
        for my $item ($shipment->shipment_items) {
            $item->check_for_and_assign_reservation;
        }
    }
}

=head2 _post_save_voucher_processing

After the order has been processed, we check if there were any virtual vouchers
being ordered, and if so, send a message to Fulcrum to update the shipment with
voucher codes.

=cut

sub _post_save_voucher_processing {
    my ( $self, $order ) = @_;

    return if !$self->_has_virtual_vouchers;

    my $amq = $self->msg_factory;

    my $shipment = $order->shipments->first;

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Order::VirtualVoucherCode', $shipment );

    return;
}

sub _check_ddu_acceptance {
    my( $self, $order, $operator_id ) = @_;

    return if $self->_virtual_voucher_only_order;

    foreach my $shipment ( $order->shipments ) {
        my $auto_ddu = $self->schema()->resultset('Public::Country')->find( { country => $shipment->shipment_address()->country() } )->country_shipment_types()->find( { channel_id => $self->channel()->id() } )->auto_ddu() // 0;
        if ( ( $shipment->shipment_type_id == $SHIPMENT_TYPE__INTERNATIONAL_DDU ) && ( $auto_ddu == 0 ) && ( ! $order->customer->ddu_terms_accepted ) ) {

            # flag it
            $shipment->shipment_flags->create( { shipment_id => $shipment->id(), flag_id => $FLAG__DDU_PENDING } );

            # Put it on ddu hold
            $shipment->update_status($SHIPMENT_STATUS__DDU_HOLD, $operator_id);

            # Send the ddu email
            send_ddu_email(
                $self->schema,
                $shipment,
                {
                    shipping_email => XTracker::Config::Local::shipping_email( ( split /-/, $order->channel()->web_name() )[0] ) // 'orders@net-a-porter.com',
                    email_to       => $order->email(),
                    country        => $shipment->shipment_address()->country(),
                    channel        => { business => $self->channel()->business()->name(), url => $self->channel()->business()->url() },
                    first_name     => $shipment->shipment_address()->first_name(),
                    operator_id    => $operator_id,
                },
                'notify'
            );
        }
    }
}

sub _check_valid_order {
    my($self,$order,$operator_id) = @_;

    my $shipment = $order->shipments->first;
    return if $shipment->is_on_hold;

    $shipment->hold_if_invalid({ operator_id => $operator_id });
}

sub _check_valid_preorder {
    my($self,$order,$operator_id) = @_;
    my $shipment = $order->shipments->first;

    if ( is_valid_pre_order_number($self->preorder_number) ) {
        $shipment->hold_for_prepaid_reason({
            comment     => 'preorder_number: '.$self->preorder_number,
            operator_id => $operator_id,
        });
    }
}

=head2 allocate()

Attempt to allocate each shipment in the order. We attempt to call this outside
of a transaction, so we don't have a race-condition with the PRL replying before
we've written to the DB (DCA-1286).

Traditionally we call allocate() on shipments without checking the PRL rollout
phase. As doing this requires us to set up a msg factory, in this instance we
check explicitly if we need to allocate before doing so.

=cut

sub allocate {
    my ( $self, $operator_id ) = @_;
    return unless config_var('PRL', 'rollout_phase');

    my $factory = $self->msg_factory();
    $_->allocate({ factory => $factory, operator_id=> $operator_id }) for $self->shipments;
}

sub _apply_credit_rating {
    my($self,$order,$operator_id) = @_;

    if ($self->preorder_number) {
        $logger->debug('This is a preorder. Not applying credit ratings');

        $order->set_status_accepted($operator_id);

        my $shipment_rs = $order->shipments;
        while (my $shipment = $shipment_rs->next) {
            $shipment->set_status_processing($operator_id,1)
        }

        return;
    }

    my $shipment = $order->shipments->first;
    my $rating = 0; # don't know if this is where its suppose to start
    # previously it defaulted to this - assume it means invoice vs shipment addr
    my $addr_match = 1;

    if ($self->_is_shipping_address_dodgy($shipment)) {
        $order->add_flag( $FLAG__ADDRESS );
        $rating--;
        $addr_match = 0;
    }

    my $customer = $order->customer;
    if ( $customer->is_an_eip ) {
        $rating += 200;
        $logger->debug("EIP order, +200 points");
        $logger->debug("credit_rating = " . $rating);
    }

    $rating = $self->_do_hotlist_checks($order,$rating);
    $rating = $self->_do_customer_order_card_checks($order,$rating,$addr_match);

    # Check Fraud Exceptions
    $rating  = $self->_process_fraud_exception($rating, $order, $shipment);

    # check if Signature not Required should it go on Hold
    if ( !$shipment->is_signature_required
         && $order->should_put_onhold_for_signature_optout( $shipment ) ) {
        # no change '$rating' to be less than zero
        # and add an appropriate flag to the Order
        $rating = -1;
        $order->add_flag_once( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
    }

    # CANDO-850
    # Order is not for EIP and has atleast one virtual voucher
    # put the order on credit hold

    if ( !$customer->is_an_eip &&
         $self->_has_virtual_vouchers )
    {
        $rating = -1;
    }

    # customer failed credit checks - place order on hold
    if ($rating < 0) {

        # PUT ORDER ON CREDIT HOLD
        $order->set_status_credit_hold($operator_id);

        # PUT SHIPMENTS ON FINANCE HOLD
        my $shipment_rs = $order->shipments;
        while (my $shipment = $shipment_rs->next) {
            # Clear all orphaned shipment_hold records
            $shipment->delete_related('shipment_holds');
            $shipment->set_status_finance_hold($operator_id);
        }

    } else {
        $order->set_status_accepted($operator_id);

        my $shipment_rs = $order->shipments;
        while (my $shipment = $shipment_rs->next) {
            # set status without logging
            $shipment->set_status_processing($operator_id,1)
                unless $shipment->is_on_ddu_hold || $shipment->is_held;
        }
    }

}

sub _find_card_payment {
    my($self,$order) = @_;

    my @tenders = $self->all_tenders;
    foreach my $tender ( @tenders ) {
        return $tender if $tender->type eq 'Card Debit';
    }

    return;
}





sub _is_shipping_address_dodgy {
    my($self,$shipment) = @_;


    # its good that:
    # shipping and billing address match or has been used before
    if ($shipment->has_same_address_as_billing_address
        || $shipment->count_address_in_uncancelled > 1) {
        return 0;
    }

    return 1;
}

sub _do_hotlist_checks {
    my($self,$order,$rating) = @_;
    my $schema = $self->schema;

    my $fields = $self->_fields_to_fraud_check($order);
    my $hotlist = $schema->resultset('Public::HotlistValue')->search(
        {},
        {
            '+select' => [qw( hotlist_field.field hotlist_type.type )],
            '+as' => [qw( field type )],
            join => { 'hotlist_field' => 'hotlist_type' }
        }
    );

    my $hotlist_cache = $self->_hotlist_cache;

    # if we've not see this channel before load it into memory
    if (!defined $hotlist_cache) {
        while (my $check = $hotlist->next) {
            my $stuff = {
                value => $check->get_column('value'),
                field => $check->get_column('field'),
                type  => $check->get_column('type'),
            };
            push @{$hotlist_cache}, $stuff;
        }
        $self->_hotlist_cache($hotlist_cache);
    }


    # FIXME: this shouldn't be needed - could just set them up in the db
    # hotlist flag mapping
    my %hotlist_flag = (
        "Card Number"      => $FLAG__FRAUD_CREDIT_CARD,
        "Street Address"   => $FLAG__FRAUD_ADDRESS,
        "Town/City"        => $FLAG__FRAUD_ADDRESS,
        "County/State"     => $FLAG__FRAUD_ADDRESS,
        "Postcode/Zipcode" => $FLAG__FRAUD_POSTCODE,
        "Country"          => $FLAG__FRAUD_COUNTRY,
        "Email"            => $FLAG__FRAUD_EMAIL,
        "Telephone"        => $FLAG__FRAUD_TELEPHONE,
    );

    # populate _fraud_exception hash
    $self->_fraud_exception->{'credit_hold_exception'}->{'hotlist_flag'} = 0;
    foreach my $check (@{$hotlist_cache}) {
        my $value = $check->{value};
        my $field = $check->{field};
        my $type  = $check->{type};

        ### check against corresponding field from order
        if ($fields->{$type}->{$field} =~ m/\b\Q$value\E/i) {
            # set order flag
            $order->add_flag( $hotlist_flag{$field} );

            # decrement fraud score
            $rating -= 500;
            $logger->debug("Fraud hotlist! [$field: $value], -500 points");
            $logger->debug("credit_rating = " . $rating);
        }
    }

    $rating;
}

sub _do_customer_order_card_checks {
    my($self,$order,$rating,$addr_match) = @_;
    my $schema = $self->schema;

    my $customer = $order->customer;
    my $similar_customers = $customer->customers_with_same_email;
    my @cust_ids = $similar_customers->get_column('id')->all;
    unshift(@cust_ids,$customer->id);

    my $cust_rs = $schema->resultset('Public::Customer')->search({
        'me.id' => { 'in' => \@cust_ids },
    });

    $self->_customer_rs( $cust_rs );

    # customer has shopped across channels - info only flag
    if ($self->_count_customer_channels( $cust_rs ) > 1) {
        $order->add_flag( $FLAG__MULTI_CHANNEL_CUSTOMER );
        $logger->info("- Multi Channel Customer");
    }

    $self->_fraud_exception->{'credit_hold_exception'}->{'financewatch_flag'} = 0;

    ## if on financial watch decrement credit score
    $cust_rs->reset;
    while (my $cust = $cust_rs->next) {
        if ($cust->has_finance_watch_flag) {
            $rating -= 500;
            $logger->debug("Customer on financial watch list -50 points");
            $logger->debug("credit_rating = " . $rating);

            $order->add_flag( $FLAG__FINANCE_WATCH );
            $self->_fraud_exception->{'credit_hold_exception'}->{'financewatch_flag'} = 1;
        }
    }

   # Populate _credit_hold_exception_customer_list and channel_list HashRef
   if( $self->_fraud_exception->{'credit_hold_exception'}->{'financewatch_flag'} == 0 ||
       $self->_fraud_exception->{'credit_hold_exception'}->{'hotlist_flag'}      == 0 )
    {
        # populate _credit_hold_exception_channel_list Hash ref
        $self->_set_credit_hold_exception_channel_list($order);

        #populate _credit_hold_exception_customer_list HashRef
        $self->_set_credit_hold_exception_customer_list($order,\@cust_ids);
    }
    $rating = $self->_do_order_checks($cust_rs,$order,$rating);
    $rating = $self->_do_card_checks($order,$rating,$cust_rs,$addr_match);

    return $rating;
}

sub _count_customer_channels {
    my($self,$cust_rs) = @_;
    my @channels = $cust_rs->get_column('channel_id')->all;
    my %seen;

    foreach ( @channels ) {
        $seen{$_}++;
    }

    return scalar keys %seen;
}


# IN PROGRESS
sub _do_card_checks {
    my($self,$order,$rating,$cust_rs,$addr_match) = @_;

    ### allow orders through matching following criteria
    ## card number begins with a 3,4 or 6
    ## AND CV2 response is ALL MATCH
    ## AND billing and shipping address are the same
    my $card = $self->_find_card_payment($order);

    # all the following checks are card related - nothing to do if its stored
    # credit.. like our tests
    return $rating if (!defined $card);

    $self->_payment_card( $card );

    if (defined $card->card_number
        && $card->card_number =~ m/\b[3,4,6].+/
        && $card->cv2avs_status eq "ALL MATCH"
        && $addr_match == 1
        ) {
        $rating  += $self->_fraud_check_rating_adjustment->{card_check_rating};
        $logger->debug("CV2 ALL MATCH order, +150 points");
        $logger->debug("credit_rating = " . $rating);
    }


    ## EN-1162
    ## Allow orders through with:
    ## Card number begins with 3,4,5, or 6
    ## Matching billing and shipping address
    ## Order from 'low risk' country
    ## Order value <= country's low risk max order amount
    my $ship_country = $order->shipments->first->shipment_address->country;
    if (defined $card->card_number
        && $card->card_number =~ m/\b[3,4,5,6].+/
        && $addr_match == 1
        && $ship_country
        && $self->_shipping_country_risk(
            $ship_country) eq 'Low'
        && $self->_low_risk_shipping_total(
            $ship_country,
            $order->total_value
                * $self->_local_conversion_rate($order->currency_id),
            $order->channel)
    ) {
        $rating += 100;
        $logger->debug("Low risk order, +100 points");
        $logger->debug("credit_rating = " . $rating);
    }


    # Check if customer has used this credit card before
    # DCS-1135 - Ignore FTBC transactions
    my $card_count = scalar grep {
            $_ && $_->{orderNumber}     # paranoia
                &&
            # exclude Current Order (required for legacy PSP 'payment-info' request)
            $_->{orderNumber} ne $order->order_nr
                &&
            $_->{orderNumber} !~ m{^ftbc-}xmsi
        } @{ $card->card_history };

    # check if only store credit used = EN-282
    # somehow type gets changed to type_id - 1 is store credit but this should
    # be got more dynamically...
    my $non_store_credit = $order->non_store_credit_tenders;
    my($count,$value) = $self->_all_orders($cust_rs);
    my $first_order = ($count == 1) ? 1 : undef;

    if ( $card_count < 1 && $non_store_credit->count ) {
        $order->add_flag( $FLAG__NEW_CARD );
        # EN-2051 - Don't take another -110 points off as we have already for being a new customer
        if (!$first_order) {
            $rating -= 110;
            $logger->debug("New payment card, -110 point");
            $logger->debug("credit_rating = $rating");
            # REL-936
        }
    }


    # CV2 Check Responses
    ## if {cv2avsStatus} isn't defined we don't need to do any of these checks
    if (defined $card->cv2avs_status) {
        if ($card->cv2avs_status eq "DATA NOT CHECKED") {
            $order->add_flag( $FLAG__DATA_NOT_CHECKED );
        }
        if ($card->cv2avs_status eq "SECURITY CODE MATCH ONLY") {
            # Add CV2 - Ok flag
            $order->add_flag( $FLAG__SECURITY_CODE_MATCH );
        }
        if ($card->cv2avs_status eq "ALL MATCH") {
            # Add ALL MATCH flag
            $order->add_flag( $FLAG__ALL_MATCH );
        }
        if  ($card->cv2avs_status eq "NONE") {
            $order->add_flag( $FLAG__DATA_NOT_CHECKED );
        }
    }


    return $rating;
}

sub _do_order_checks {
    my($self,$cust_rs,$order,$rating) = @_;

    # get number of orders and total spend for customer
    # REL-909 - count for total order history, val for period
    my ($o_count_within_period, $customer_order_value)
        = $self->_orders_for_config_period($cust_rs);


    my ($o_count, $total_customer_order_value) = $self->_all_orders($cust_rs);

    # check if customer older than 6 months
    my $established_customer = $self->_has_order_older_than_age_months($cust_rs, 6);

    # check if customer has been credit checked
    my $checked = $self->_is_credit_checked($cust_rs);

    # this is a stored value in along side the customer record for existing
    # customer information has been migrated and we don't want them to be put
    # through the 1st/2nd/3rd Order checks again
    my $prev_order_count = $self->_sum_prev_order_count($cust_rs);

    # flag all First orders
    my $first_order = 0;

    if (($o_count + $prev_order_count ) == 1) {
        $order->add_flag( $FLAG__1ST );
        $rating -= 110;
        $logger->debug("First order, -110 points");
        $logger->debug("credit_rating = " . $rating);
        $first_order = 1;

    }
    # 2nd order if not checked yet
    elsif (($o_count + $prev_order_count ) == 2 && !$checked) {
        $order->add_flag( $FLAG__2ND );
        $rating -= 120;
        $logger->debug("Second order, not checked -120 points");
        $logger->debug("credit_rating = " . $rating);
    }
    # 3rd order if not checked yet
    elsif (($o_count + $prev_order_count ) == 3 && !$checked) {
        $order->add_flag( $FLAG__3RD );
        $rating -= 130;
        $logger->debug("Third order, not checked -130 points");
        $logger->debug("credit_rating = " . $rating);
    }
    # customer not checked and shopping less than 6 months
    elsif (!$checked && !$established_customer) {
        $order->add_flag( $FLAG__NO_CREDIT_CHECK );
        $rating -= 3;
        $logger->debug("Customer not checked and less than 6 month histroy, -3 points");
        $logger->debug("credit_rating = " . $rating);

    }

    # Check for existing CCheck orders
    $self->_fraud_exception->{'credit_hold_exception'}->{'ccheck_flag'} = 0;
    if ($self->_count_credit_check_orders($cust_rs) > 0) {
        $order->add_flag( $FLAG__EXISTING_CCHECK );
        $rating -= 500;
        $logger->debug("Customer has existing orders on credit check, -500 points");
        $logger->debug("credit_rating = " . $rating);
        $self->_fraud_exception->{'credit_hold_exception'}->{'ccheck_flag'} = 1;
    }

    $self->_fraud_exception->{'credit_hold_exception'}->{'chold_flag'} = 0;
    if ($self->_count_credit_hold_orders($cust_rs) > 0) {
        $order->add_flag( $FLAG__EXISTING_CHOLD );
        $rating -= 500;
        $logger->debug("Customer has existing orders on credit hold, -500 points");
        $logger->debug("credit_rating = " . $rating);
        $self->_fraud_exception->{'credit_hold_exception'}->{'chold_flag'} = 1;
    }

    # Check total order value.
    my $order_value = $self->_get_order_total_value($order);
    $self->_order_total_value($order_value); # set global variable as well

    # get order's relevant thresholds
    my $thresholds = $order->channel->credit_hold_thresholds->select_to_hash(
        'Single Order Value',
        'Total Order Value',
        'Weekly Order Value',
        'Weekly Order Count',
        'Daily Order Count',
    );

    if ($order_value > $thresholds->{'Single Order Value'} ) {
        $order->add_flag( $FLAG__HIGH_VALUE );
        $rating -= 75;
        $logger->debug("Total order value higher than threshold, -75 points");
        $logger->debug("credit_rating = " . $rating);

    }

    # Chold when customer has spent more than Total Order Value for the first time in 6 months
    if ( $customer_order_value >= $thresholds->{'Total Order Value'}
      && ($customer_order_value - $order_value) < $thresholds->{'Total Order Value'}
    ) {
        $order->add_flag( $FLAG__TOTAL_ORDER_VALUE_LIMIT );
        --$rating;
        $logger->debug("- Total takes us over  " . $thresholds->{'Total Order Value'} . " for first time in last 6 months, -1 point");
        $logger->debug("credit_rating = $rating");
    }


    # Check Weekly orders
    my ($w_count, $week_order_value) = $self->_weekly_orders($cust_rs);
    if ($w_count) {
        # Customer has just spent more than Weekly Order Value in a week
        if ($week_order_value > $thresholds->{'Weekly Order Value'}) {
            $order->add_flag( $FLAG__WEEKLY_ORDER_VALUE_LIMIT );
            --$rating;
            $logger->debug("- Weekly total takes us over " . $thresholds->{'Weekly Order Value'}.", -1 point");
            $logger->debug("credit_rating = " . $rating);
        }
        # Customer has placed 5 or more orders in the week
        if ($w_count >= $thresholds->{'Weekly Order Count'}) {
            $order->add_flag( $FLAG__WEEKLY_ORDER_COUNT_LIMIT );
            --$rating;
            $logger->debug("Customer placed more orders than the weekly order count thresold, -1 point");
            $logger->debug("credit_rating = " . $rating);

        }
    }

    # Check days orders
    my ($d_count, $day_order_value) = $self->_daily_orders($cust_rs);
    # Customer has placed 3 or more orders today
    if ($d_count >= $thresholds->{'Daily Order Count'}) {
        $order->add_flag( $FLAG__DAILY_ORDER_COUNT_LIMIT );
        --$rating;
        $logger->debug("Customer placed more orders than the daily order count thresold, -1 point");
        $logger->debug("credit_rating = " . $rating);
    }

    return $rating;
}

sub _get_order_total_value {
    my ($self, $order ) = @_;

    # Check total order value.
    my $order_value = $order->total_value
        * $self->_local_conversion_rate($order->currency_id);

    return $order_value;
}

sub _fields_to_fraud_check {
    my($self,$order) = @_;
    my $out;

    my $customer = $order->customer;
    $out->{Customer} = {
        Email => $customer->email,
        Telephone => $customer->get_first_defined_phone_number || '',
    };

    my $shipment = $order->shipments->first;
    my $addr;
    # add in the invoice and shipping address
    foreach my $add ( $order->invoice_address,  $shipment->shipment_address ) {
        $addr->{'Name'}             .= " ". $add->first_name ." ". $add->last_name;
        $addr->{'Street Address'}   .= " ". $add->address_line_1 ." ". $add->address_line_2;
        $addr->{'Town/City'}        .= " ". $add->towncity;
        $addr->{'County/State'}     .= " ". $add->county;
        $addr->{'Postcode/Zipcode'} .= " ". $add->postcode;
        $addr->{'Country'}          .= " ". $add->country;
    }
    $out->{'Address'} = $addr;

    my $card = $self->_find_card_payment($order);
    $out->{'Payment'}->{'Card Number'} = (defined $card)
        ? $card->card_number : '';

    return $out;
}



=head2 _shipping_country_risk

Given a country, check its 'risk level', as definied in the sys_conf_var
database tables. Can return undef if a country hasn't had a risk level
defined, 'Low' if it has and possible 'High' in the future.

=cut

sub _shipping_country_risk {
    my($self,$country) = @_;

    my $origin_risk = sys_config_var($self->schema, 'OrderOriginRisk', $country);

    $origin_risk ? $logger->debug("\$origin_risk = $origin_risk\n")
                 : $logger->debug("No origin risk found");

    # stop it warning about comparison against uninitialised value
    $origin_risk = '' if (!defined $origin_risk);
    return $origin_risk;
}

=head2 _low_risk_shipping_total

Returns the low risk shipping order threshold value,
for a given country, for a given channel. So if an order
is worth less than the threshold value it is 'low risk'.

=cut

sub _low_risk_shipping_total {
    my ($self,$country,$total,$channel) = @_;

    my $schema = $self->schema;
    my $code = $schema->resultset('Public::Country')
        ->find_by_name($country)->code;

    my $conf_var = $code . 'OrderRiskAttributes';

=pod

    ## Dynamically generate a little lookup table from channel -> conf var
    ## e.g. 1 => NAP-INTL_Order_Threshold
    my @channels = $schema->resultset('Public::Channel')->all;

    my $setting_channel_lookup = { };
    foreach my $channel (@channels) {
        $setting_channel_lookup->{$channel->id} = $channel->web_name . '_Order_Threshold';
    }

=cut
    my $low_risk_total = sys_config_var($schema, $conf_var, $channel->web_name . '_Order_Threshold');
    # TODO: get a sane default
    $low_risk_total //= 0; # prevent q{Use of uninitialized value $low_risk_total in concatenation}

    $logger->debug("\$total = $total\n");
    $logger->debug("\$low_risk_total = $low_risk_total\n");

    if ( $total <= $low_risk_total ) {
        $logger->debug("$total <= $low_risk_total\n");
        return 1;
    }

    $logger->debug("$total > $low_risk_total\n");
    return 0;
}


sub _has_order_older_than_age_months {
    my $self        = shift;
    my $cust_rs     = shift;
    my $age         = shift; # in months
    my $args        = shift || {};


    my %exclude_order=();
    my %include_order=();
    my $orders_rs;
    my $operator = $args->{'include_age'} ? "<=" : "<";

    # Exclude cancelled orders if $cancel flag is set else search all orders
    if ($args->{'exclude_cancelled'} ) {
        %exclude_order = (
            order_status_id => {
                '!='  => $ORDER_STATUS__CANCELLED,
            },
        );
    }

    #include order from  given channel list
    if(defined $args->{include_channels}) {
        %include_order = (
            'orders.channel_id' => {
                '-in'  => $args->{include_channels},
            },
        );

    }
    if( defined $age ) {
        $orders_rs= $cust_rs->reset->search_related('orders',{
            date => {
                "$operator" => \"current_timestamp - INTERVAL '$age months'",
            },
            %exclude_order,
            %include_order,
        });
    }

    if ($orders_rs) {
        return ( $orders_rs->count > 0 ? 1 : 0 );
    }

    return 0;
}

sub _is_credit_checked {
    my($self,$cust_rs) = @_;

    my $credit = $cust_rs->search({
        credit_check => { '!=' => undef },
    });

    return 1 if (defined $credit && $credit->count > 0);
    return;
}


sub _sum_prev_order_count {
    my($self,$cust_rs) = @_;
    my $count;

    $cust_rs->reset;
    while (my $cust = $cust_rs->next) {
        $count += $cust->prev_order_count;
    }

    return $count;
}

sub _count_customer_method {
    my($self,$cust_rs,$method) = @_;
    my $count;

    $cust_rs->reset;
    while (my $cust = $cust_rs->next) {
        $count += $cust->$method->count;
    }

    return $count;
}

sub _count_credit_check_orders {
    my($self,$cust_rs) = @_;

    return $self->_count_customer_method($cust_rs,'credit_check_orders');
}

sub _count_credit_hold_orders {
    my($self,$cust_rs) = @_;

    return $self->_count_customer_method($cust_rs,'credit_hold_orders');
}

sub _summarise_order_for_period {
    my($self,$cust_rs,$age) = @_;
    my $count = 0;
    my $value = 0;

    $cust_rs->reset;
    while (my $cust = $cust_rs->next) {
        my $orders_rs = $cust->orders_aged($age);
        while (my $order = $orders_rs->next) {
            $count++;
            $value += ($order->total_value
                * $self->_local_conversion_rate($order->currency_id));
        }

    }

    return($count,$value);
}

sub _local_conversion_rate {
    my($self,$from_cur_id) = @_;
    my $schema = $self->schema;

    my $to = config_var('Currency', 'local_currency_code');
    my $to_cur = $schema->resultset('Public::Currency')->find_by_name($to);
    if (!defined $to_cur) {
        croak "Unknown currency code - $to";
    }

    my $rate = $schema->resultset('Public::SalesConversionRate')
        ->conversion_rate($from_cur_id, $to_cur->id);

    return $rate;
}

sub _weekly_orders {
    my($self,$cust_rs) = @_;
    return $self->_summarise_order_for_period($cust_rs,'8 days');
}


sub _daily_orders {
    my($self,$cust_rs) = @_;
    return $self->_summarise_order_for_period($cust_rs,'1 day');
}

sub _all_orders {
    my($self,$cust_rs) = @_;
    return $self->_summarise_order_for_period($cust_rs);
}

sub _orders_for_config_period {
    my($self,$cust_rs) = @_;
    return $self->_summarise_order_for_period(
        $cust_rs,
        sys_config_var(
            $self->schema,
            'Order_Credit_Check',
            'total_order_period'
        )
    );
}


=head3 _apply_channel_specifics($order)

Call the channel specific logic and deal with promotions

=cut

sub _apply_channel_specifics {
    my($self,$order) = @_;
    my $schema = $self->schema;

    # business logic encapsulated using module pluggable
    my $business_logic = XT::Business->new({ });
    my $plugin = $business_logic->find_plugin(
        $order->channel,'OrderImporter');


    if (!defined $plugin) {
        $logger->info( __PACKAGE__ .": No plugin found for channel_id "
            .$order->channel_id ." - this isn't fatal as it "
            ."may not have its business logic seperated");
    }

    my $shipment = $order->shipments->first;
    if (defined $plugin) {
        $plugin->call('shipment_modifier',$shipment);
    }

    # Add a promotion pack if relevant
    # SECTION: PROMOTION PACK
    XTracker::Promotion::Pack->check_promotions($schema,$order,$plugin);

    # CANDO-326: Add Gift Line Promotional Items to the Order if there are any
    if ( $self->number_of_gift_line_items ) {
        foreach my $gift ( $self->all_gift_line_items ) {
            $gift->apply_to_order( $order );
        }
    }
}

=head3 _apply_third_party_payment_status

If the Order was paid (or part paid) using a Third Party PSP (PayPal) then
check to see what it's current Status is and change the Shipment's Status
if required.

=cut

sub _apply_third_party_payment_status {
    my ( $self, $order ) = @_;

    eval {
        $order->get_standard_class_shipment
                ->update_status_based_on_third_party_psp_payment_status;
    };
    if ( my $err = $@ ) {
        $logger->error( "Error Checking Third Party PSP Status for Order Nr '" . $self->order_number . "': ${err}" );
    }

    return;
}


=head2 _all_vouchers

Returns vouchers in this order

=cut

sub _all_vouchers {
    my $self = shift;

    return grep { $_->is_voucher } $self->all_line_items;
}


=head2 _all_virtual_vouchers

Returns virtual vouchers in this order

=cut

sub _all_virtual_vouchers {
    my $self = shift;

    return grep { !$_->is_physical_voucher } $self->_all_vouchers;
}

=head2 _has_virtual_vouchers

Returns a boolean indictating whether this order has any virtual vouchers as
any of the line items in the order.

=cut

sub _has_virtual_vouchers {
    my $self = shift;

    my @list = $self->_all_virtual_vouchers;

    if ( scalar @list >= 1 ) {
        return 1;
    }
    else {
        return 0;
    }

}

=head2 shipment_type

Returns shipment type for this country

=cut

sub shipment_type {
    my $self =shift;

    if (defined $self->shipping_charge) {
        if ($self->shipping_charge->shipping_charge_class->id eq $SHIPPING_CHARGE_CLASS__SAME_DAY) {
            return $self->schema->resultset('Public::ShipmentType')->get_premier;
        }

        my $shipment_type
            = $self->delivery_address->country->country_shipment_types->search(
                { channel_id => $self->channel->id }
            )->first;

        return $shipment_type->shipment_type if $shipment_type;

        return $self->schema->resultset('Public::ShipmentType')->get_international_ddu;
    } else {
        warn "No shipping charge extracted";
    }
}

=head2 shipping_total

Returns full value of shipment as L<XT::Data::Money> object

=cut

sub shipping_total {
    my $self = shift;

    my $total = $self->shipping_tax
        + $self->shipping_duties
        + $self->shipping_net_price;

    return $total;
}


=head2 _get_credit_hold_exception_params

CANDO-491:

=cut

sub _get_credit_hold_exception_params {
    my($self, $setting, $channel_id) = @_;

    my $result = sys_config_var($self->schema, 'CreditHoldExceptionParams', $setting, $channel_id);

    $result = undef if (!defined $result);

    return $result;

}


=head2 _process_fraud_exception

CANDO-491: If the order statisfies following rule for configured channels then
           Order is not placed on Credit Hold If
    1) customer has x months old order (which are not cancelled) history across configured channel
    2) order value < y amount
    3) shipping address is not new across configured channels only
    4) payment card is not ne across configured channels only
    5) customer is not on Finance Watch or on Hotlist
    6) and any other orders are not on Credit Check or Credit hold

=cut
sub _process_fraud_exception {
    my ( $self, $rating, $order, $shipment ) = @_;


    my @cust_ids = keys %{$self->_credit_hold_exception_customer_list};

    # Exception Rule: ignore if on hotlist or finance watch or credit hold or credit hold
    if(  !$self->_fraud_exception->{'credit_hold_exception'}->{'hotlist_flag'}      &&
         !$self->_fraud_exception->{'credit_hold_exception'}->{'financewatch_flag'} &&
         !$self->_fraud_exception->{'credit_hold_exception'}->{'ccheck_flag'}       &&
         !$self->_fraud_exception->{'credit_hold_exception'}->{'chold_flag'}        &&
         !$self->_is_payment_card_new($order)                                       &&
         $self->_has_order_check_rule_passed($order)                                &&
         # Shipment Address is used more than Once - This Shipment's Address counts as 1
         $shipment->count_address_in_uncancelled_for_customer({ customer_list => \@cust_ids} ) >= 2 )
    {
           $rating = 1;
    }

    return $rating;
}

=head2 _set_credit_hold_exception_channel_list

CANDO-491: populate _credit_hold_exception_channel_list HashRef

=cut

sub _set_credit_hold_exception_channel_list {
    my ( $self, $order ) = @_;

    # Get value from system_config.config_group_setting for setting = "include_channel"
    my $exception_channels = $self->_get_credit_hold_exception_params('include_channel',$order->channel_id);

    my %channel_list;
    if ( defined $exception_channels ) {
        # Get channel ids from given business.config_section value
        %channel_list   = map { $_->id => $_ }
                                   $self->schema->resultset('Public::Channel')
                                           ->search( {
                                                    'business.config_section' => { 'IN' => $exception_channels },
                                                 },
                                                 {
                                                    join    => 'business',
                                                 } )->all;

    }

    $self->_credit_hold_exception_channel_list( \%channel_list );

    return;

}

=head2 _set_credit_hold_exception_customer_list

CANDO-491: populate _credit_hold_exception_customer_list HashRef

=cut

sub _set_credit_hold_exception_customer_list {
    my( $self, $order, $cust_ids ) = @_;

    # Get record set of customer for specific channels
    my @channel_list = keys %{$self->_credit_hold_exception_channel_list};
    my $exception_cust_rs = $self->schema->resultset('Public::Customer')
                                        ->search({
                                            'me.id'         => { 'in' => $cust_ids },
                                            'me.channel_id' => { 'in' => \@channel_list },
                                        });

    #populate _credit_hold_exception_customer_list
    while( my $exception_cust = $exception_cust_rs->next) {
        if(!exists  $self->_credit_hold_exception_customer_list->{$exception_cust->id} ) {
            $self->_credit_hold_exception_customer_list->{ $exception_cust->id } = $exception_cust;
        }
    }

}

=head2 _has_order_check_rule_passed

CANDO-491: Test if the customer has x months old order in given channel list
           and order_value < y amount

=cut

sub _has_order_check_rule_passed {
    my( $self, $order) = @_;

    # Exception Rule : check if customer has history more than 9 months and order value < 5000
    my $exception_month = $self->_get_credit_hold_exception_params('month',$order->channel_id);
    my $exception_value = $self->_get_credit_hold_exception_params('order_total',$order->channel_id);

    my @channel_list = keys %{$self->_credit_hold_exception_channel_list};
    if ( defined $exception_month && defined $exception_value ) {
        my $order_history = $self->_has_order_older_than_age_months($self->_customer_rs, $exception_month, {
                                                                                        exclude_cancelled => 1,
                                                                                        include_age       => 1,
                                                                                        include_channels  => \@channel_list
                                                                                        } );
        if($order_history > 0 && $self->_order_total_value < $exception_value){
            return 1;
        }
    }

    return 0;
}

=head2 _is_payment_card_new

CANDO-491: Test if the payment card is used before in given channel list for a customer

=cut

sub _is_payment_card_new {
    my( $self, $order ) = @_;

    my $card = $self->_payment_card;
    return 0        if ( !defined $card );      # store credit then no card used so return FALSE

    # get all the order_nr  and remove the id of current order
    my @order_numbers = grep { $_ ne $order->order_nr } map { $_->{orderNumber} ?  $_->{orderNumber} : ()}  @{$card->card_history};

    my $size = @order_numbers;
    return 1 if $size <= 0;

    my @channel_list = keys %{$self->_credit_hold_exception_channel_list};
    my $card_usage = $self->schema->resultset('Public::Orders')
                                              ->search( {
                                                        order_nr   => { 'IN' => \@order_numbers },
                                                        channel_id => {'IN' => \@channel_list },
                                                        order_status_id => $ORDER_STATUS__ACCEPTED,
                                                      }) || 0;
    # Rule: Check if card is NOT new
    if($card_usage > 0) {
        return 0;
    }

    return 1;
}

sub _build__fraud_check_rating_adjustment {
    my $self    = shift;

    return  get_fraud_check_rating_adjustment($self->schema,$self->channel->id);

}


=head2 work_around_broken_import_data() : 0 | 1 | die

Added 2012-05-09, should be removed ASAP. See also:
http://jira4.nap/browse/FLEX-745

Check that the shipping_charge is for Nominated Day if there is a
dispatch_date.

If not:
* Change the shipping_charge to the Channel's Premier Daytime
* Log an error
* Email Customer Support

Return 0 if everything is fine, or 1 if the data had to be worked
around. Die if the data is very broken.

=cut

sub work_around_broken_import_data {
    my $self = shift;
    my $dispatch_date = $self->nominated_dispatch_date or return 0;
    my $shipping_charge = $self->shipping_charge or die("work_around_broken_import_data: Invalid Order data:
Nominated Day but no Shipping Charge specified.
If in an Order Importer test: has ->digest been called?
");
    my $latest_dispatch_daytime
        = $shipping_charge->latest_nominated_dispatch_daytime;
    if($latest_dispatch_daytime) {
        return 0;
    }

    # Bad, we have a dispatch_date, but no Nominated Day Shipping Charge

    my $new_shipping_charge_description = "Premier Daytime";
    my $shipping_charge_rs = $self->schema->resultset("Public::ShippingCharge");
    my $new_shipping_charge = $shipping_charge_rs->search({
        channel_id  => $self->channel->id,
        description => $new_shipping_charge_description,
    })->first or die("work_around_broken_import_data: Could not find replacement Shipping Charge ($new_shipping_charge_description) for non-Nominated Day Shipping Charge sku (" . $shipping_charge->sku . "), description(" . $shipping_charge->description . ")\n");

    $logger->error("Bad data for ORDER_NUMBER(" . $self->order_number . "). DISPATCH_DATE ($dispatch_date) provided, but for a non-Nominated Day Shipping Charge SKU (" . $shipping_charge->sku . "), description(" . $shipping_charge->description . "). Using replacement Shipping Charge SKU (" . $new_shipping_charge->sku . "), description(" . $new_shipping_charge->description . ")");

    $self->_send_workaround_carrier_email();

    $self->shipping_charge( $new_shipping_charge );

    return 1;
}

sub _send_workaround_carrier_email {
    my $self = shift;

    my $config_section = $self->channel->business->config_section;
    my $premier_carrier_email = config_var(
        "Email_$config_section",
        "premier_email",
    );

    my $order_number = $self->order_number;
    return send_templated_email(
        to        => $premier_carrier_email,
        subject   => "Premier Order ($order_number) received with incorrect shipping information",
        from_file => { path => "email/internal/flex-475_workaround_premier_carrier.tt" },
        stash     => {
            order         => $self,
            template_type => "email",
        },
    );
}

sub _send_email_alert_for_preorder {
    my ($self, $order) = @_;

    $logger->debug('Sending email alert for preorder');
    my %restrictions;

    if( $self->has_shipping_restrictions && $self->_shipping_restrictions->{restrict}) {
        %restrictions = (
            restrictions => $self->_shipping_restrictions->{restricted_products}
        );
    }

    return send_templated_email(
        from_file => {
            path => $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_TEMPLATE
        },
        subject => sprintf(
            $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_SUBJECT,
            $self->preorder_number,
            $order->customer->channel->web_name
        ),
        to => email_address_for_setting(
            $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_ADDRESS_CONFIG_SETTING,
            $order->customer->channel->business->config_section
        ),
        stash => {
            order           => $self,
            shipment        => $order->shipments->first,
            customer        => $order->customer,
            template_type   => "email",
            %restrictions
        }
    );
}

sub _post_commit_processing {
    my ($self, $order_dbix) = @_;

    # push customer_value to seaview( Bosh)
    $self->_send_customer_value_job($order_dbix);

    if ( $self->preorder_number ) {
        $self->_send_preorder_post_commit_amq_message($order_dbix);
    }

    if ( $self->_run_fraud_rules_in_parallel ) {
        $self->_send_fraud_rules_job( $order_dbix );
    }

    if ( $order_dbix->is_on_credit_hold ) {
        $self->_ask_another_dc_to_check_order( $order_dbix );
    }

    if ( $self->_fraud_rules_outcome ) {
        $self->_send_fraud_metrics_update_job( $order_dbix );
    }
}

sub _send_preorder_post_commit_amq_message {
    my ($self, $order_dbix) = @_;

    my $preorder = $order_dbix->get_preorder;

    if ($preorder->is_notifiable()) {
        $preorder->notify_web_app($self->msg_factory());
    }
}

sub _send_fraud_rules_job {
    my ( $self, $order )    = @_;

    eval {
        my $job_rq = XT::JQ::DC->new( { funcname => 'Receive::Order::ApplyFraudRules' } );
        $job_rq->set_payload( {
            order_number    => $order->order_nr,
            channel_id      => $order->channel_id,
            mode            => 'parallel',
        } );
        $job_rq->send_job();
    };
    if ( my $err = $@ ) {
        # if it couldn't be done, log it, but it's not
        # a reason to say the Order Failed to Import
        $logger->error( "Sales Channel: '" . $self->channel_name . "', Order Number: '" . $order->order_nr . "'" .
                        " - Could NOT place a Job on the Job Queue to run the Fraud Rules in 'Parallel': ${err}" );
    }

    return;
}

sub _ask_another_dc_to_check_order {
    my ( $self, $order )    = @_;

    # CANDO-1646: Send remote DC query to determine if the customer has an
    # order history on other DCs. Only do this if the order has been put
    # on hold solely for order count related reasons
    if ( $order->has_only_order_count_order_flags
      && defined $order->customer->account_urn ) {
        # send the request IF the DC is enabled to do so
        my $rdc = XT::Domain::Fraud::RemoteDCQuery->new( { schema => $self->schema } );
        if ( $rdc->query_enabled ) {
            $rdc->ask( 'CustomerHasGenuineOrderHistory?', $order->id );
        }
    }

    return;
}

sub _send_fraud_metrics_update_job {
    my ( $self, $order ) = @_;

    my $log_message_prefix = "Sales Channel: '" . $self->channel_name . "', Order Number: '" . $order->order_nr;

    eval {
        # assign a tag to the Job so it has some context
        my $job_tag = $self->channel_name . ": " . $order->order_nr;

        unless ( $self->_fraud_rules_outcome->send_update_metrics_job( $job_tag ) ) {
            $logger->warn( $log_message_prefix . " - Did NOT place a Job in the Job Queue to Update Fraud Rule Metrics" );
        }
    };
    if ( my $err = $@ ) {
        # if it couldn't be done, log it, but it's not
        # a reason to say the Order Failed to Import
        $logger->error( $log_message_prefix . " - Could NOT place a Job on the Job Queue to run Fraud Rule Metric Updates: ${err}" );
    }

    return;
}

sub _attempt_with_deadlock_recovery {
    my ( $self, $args, $sub ) = @_;

    # default parameters result in a single attempt at processing
    # the order, and no delay on handling failure due to deadlock

    my $max_deadlock_attempts = $args->{max_deadlock_attempts} || 0;
    my $attempt_min_delay     = $args->{min_deadlock_delay}    || 0;
    my $attempt_max_delay     = $args->{max_deadlock_delay}    || 0;

    # we default to '1' separately from capturing the argument, so we can
    # tell whether we were given '1' as the input, or we defaulted it
    #
    # we use that information later in the exception handler
    # to decide if any value was ever passed, and act appropriately
    my $attempts_remaining   = $max_deadlock_attempts || 1;
    my $attempt_rand_range   = $attempt_max_delay - $attempt_min_delay;

    # this is also a bodge to allow the test harness to cope with
    # a $self that isn't a huge object of stuff
    my $order_name = $args->{order_name}
                        || $self->channel->name . '/'. $self->order_number;

    # decrementing at the start of the loop means that the loop
    # executes with the number of attempts that remain, should
    # this attempt fail, which I find easier to think about
    # -- the variable always means what it says

    my $attempts_made = 0;
    my @pauses = ();
    my $pause_total = 0;

    while ( $attempts_remaining-- > 0 ) {
        ++$attempts_made;

        my $result;

        eval {
            # we actually pass in the number of attempts made and
            # remaining and total delay so far to allow the test harness to work :-/
            #
            # better suggestions welcome

            $result=$sub->( $self, { made      => $attempts_made,
                                     remaining => $attempts_remaining,
                                     max       => $max_deadlock_attempts,
                                     delay     => $pause_total,
                                     pauses    => \@pauses } );
        };

        if ( my $e = $@ ) {
            if ( $max_deadlock_attempts && $e =~ m/\bdeadlock\b/i ) {
                # only check for deadlocks if we were configured
                # to check for them
                #
                # otherwise, we need to report a deadlock as a normal error,
                # not a scenario that might support retries

                if ( $attempts_remaining ) {
                    my $pause = $attempt_rand_range > 0
                                  ? rand( $attempt_rand_range ) + $attempt_min_delay
                                  : $attempt_min_delay
                                  ;

                    $logger->info( "Deadlock detected processing order $order_name"
                                   .": retries remaining: $attempts_remaining, will retry "
                                   . ( $pause > 0 ? "in ${pause}s" : 'immediately' )
                                 );

                    # sleep for a short period that is semi-random, to
                    # allow the competing order a chance to get in first
                    #
                    # the randomness is to make it less likely
                    # that two competing orders will repeatedly
                    # continue to recollide, and therefore deadlock,
                    # at the same point

                    if ( $pause > 0 ) {
                        push @pauses, $pause;
                        $pause_total += $pause;

                        sleep( $pause );
                    }
                }
                else {
                    die "Deadlock detected processing order $order_name: retries exhausted\n";
                }
            }
            else {
                chomp $e;
                die "Error while processing order $order_name: $e\n";
            }
        }
        elsif ( $result ) {
            # only log the success if we had to retry
            # -- leave it implicit otherwise to avoid cluttering the log

            if ( $attempts_made > 1 ) {
                $logger->info( "SUCCESS processing order $order_name after $attempts_made attempts, ${pause_total}s delay" );
            }

            return $result;
        }
        else {
            die "FAILED to receive a result, and no error was thrown\n";
        }
    }

    die "FAILED to process order $order_name: ran out of deadlock retries\n";
}

sub _build_tender_sum {
    my $self = shift;

    my $sum = 0;
    for ($self->all_tenders) {
        $sum += $_->value->value;
    }

    return $sum;

}

=head2 delivery_primary_phone

    my $phone = $order->delivery_primary_phone;

Returns the first non-blank phone number that is not a mobile telephone number.

=cut

sub delivery_primary_phone {
    my ( $self ) = @_;

    foreach my $phone ($self->all_delivery_telephone_numbers) {
        next if $phone->type eq 'mobile_telephone';
        if ( $phone->number && $phone->number ne '' ) {
            return $phone->number;
        }
    }
    return '';
}

=head2 delivery_mobile_phone

    my $mobile_phone = $order->delivery_mobile_phone

Return the mobile phone number (or an empty string).

=cut

sub delivery_mobile_phone {
    my ( $self ) = @_;

    foreach my $phone ($self->all_delivery_telephone_numbers) {
        return $phone->number if $phone->type eq 'mobile_telephone' and $phone->number;
    }

    return '';
}

=head2 _send_customer_value_job

    Sends a job request to push Customer Value to Seaview (Bosh)

=cut

sub _send_customer_value_job {
    my ( $self, $order )    = @_;

    eval {
        my $job_rq = XT::JQ::DC->new( { funcname => 'Receive::Customer::CustomerValue' } );
        $job_rq->set_payload( {
            customer_number => $self->customer_number,
            channel_id      => $order->channel_id,
        } );
        $job_rq->send_job();
    };
    if ( my $err = $@ ) {
        $logger->error( "Sales Channel: '" . $self->channel_name . "', Customer Number: '" . $self->customer_number . "'" .
                        " - Could NOT place a Job on the Job Queue to push CustomerValue ': ${err}" );
    }

    return;
}

sub _fix_telephone_numbers_for_pre_orders {
    my ( $self, $order ) = @_;

    return unless $self->preorder_number;

    # If we already have any telephone numbers on the order or shipment
    # do not change anything.

    # telephone numbers may contain empty strings so iterate over all of them
    # and return if any have actual values
    foreach my $number_obj ( $self->all_billing_telephone_numbers, $self->all_delivery_telephone_numbers ) {
        my $number = $number_obj->number // '';
        return if $number ne '';
    }

    my $pre_order = $order->get_preorder;
    return unless $pre_order; # This should never happen

    my $telephone;
    my $mobile_telephone;

    if ( defined $pre_order->telephone_day ) {
        $telephone = $pre_order->telephone_day;

        if ( defined $pre_order->telephone_eve ) {
            $mobile_telephone = $pre_order->telephone_eve;
        }
    }
    else {
        if ( defined $pre_order->telephone_eve ) {
            $telephone = $pre_order->telephone_eve;
        }
    }

    my $note;
    my $shipment = $order->get_standard_class_shipment;
    if ( $telephone ) {
        $shipment->update( { telephone => $telephone } );

        $note = "Telephone Number $telephone added from Pre-Order";
    }

    if ( $mobile_telephone ) {
        $shipment->update( { mobile_telephone => $mobile_telephone } );

        $note .= "\nTelephone number $mobile_telephone added from Pre-Order as Mobile Telephone";
    }

    if ( $note ) {
        $order->create_related( 'order_notes', {
            note_type_id    => $NOTE_TYPE__ORDER,
            operator_id     => $APPLICATION_OPERATOR_ID,,
            date            => DateTime->now( time_zone => 'local' ),
            note            => $note,
        } );
    }

    return;
}

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>
Jason Tang <jason.tang@net-a-porter.com>
Adam Taylor <adam.taylor@net-a-porter.com>
Andrew Solomon <andrew.solomon@net-a-porter.com>
Peter Richmond <peter.richmond@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;
