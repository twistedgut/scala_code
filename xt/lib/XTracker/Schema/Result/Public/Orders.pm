use utf8;
package XTracker::Schema::Result::Public::Orders;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.orders");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders_id_seq",
  },
  "order_nr",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "basket_nr",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "invoice_nr",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "session_id",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "cookie_id",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "date",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "total_value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "gift_credit",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "store_credit",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "customer_id",
  { data_type => "integer", is_nullable => 0 },
  "invoice_address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "credit_rating",
  { data_type => "integer", is_nullable => 0 },
  "card_issuer",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "card_scheme",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "card_country",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "card_hash",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "cv2_response",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "order_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "telephone",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "mobile_telephone",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "comment",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "currency_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "use_external_tax_rate",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "used_stored_card",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ip_address",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "placed_by",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "sticker",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pre_auth_total_value",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "customer_language_preference_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "order_created_in_xt_date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("unique_order_nr", ["order_nr", "channel_id"]);
__PACKAGE__->has_many(
  "address_change_logs",
  "XTracker::Schema::Result::Public::AddressChangeLog",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "card_payment",
  "XTracker::Schema::Result::Public::CardPayment",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer_language_preference",
  "XTracker::Schema::Result::Public::Language",
  { id => "customer_language_preference_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "invoice_address",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "invoice_address_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_bulk_reimbursement__orders",
  "XTracker::Schema::Result::Public::LinkBulkReimbursementOrder",
  { "foreign.order_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_orders__marketing_promotions",
  "XTracker::Schema::Result::Public::LinkOrdersMarketingPromotion",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_orders__pre_orders",
  "XTracker::Schema::Result::Public::LinkOrdersPreOrder",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_orders__shipments",
  "XTracker::Schema::Result::Public::LinkOrderShipment",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_address_logs",
  "XTracker::Schema::Result::Public::OrderAddressLog",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "order_attribute",
  "XTracker::Schema::Result::Public::OrderAttribute",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_email_logs",
  "XTracker::Schema::Result::Public::OrderEmailLog",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_flags",
  "XTracker::Schema::Result::Public::OrderFlag",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_notes",
  "XTracker::Schema::Result::Public::OrderNote",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_promotions",
  "XTracker::Schema::Result::Public::OrderPromotion",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "order_status",
  "XTracker::Schema::Result::Public::OrderStatus",
  { id => "order_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "order_status_logs",
  "XTracker::Schema::Result::Public::OrderStatusLog",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders_csm_preferences",
  "XTracker::Schema::Result::Public::OrdersCsmPreference",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "orders_rule_outcome",
  "XTracker::Schema::Result::Fraud::OrdersRuleOutcome",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "payment",
  "XTracker::Schema::Result::Orders::Payment",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "remote_dc_queries",
  "XTracker::Schema::Result::Public::RemoteDcQuery",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "replaced_payments",
  "XTracker::Schema::Result::Orders::ReplacedPayment",
  { "foreign.orders_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "tenders",
  "XTracker::Schema::Result::Orders::Tender",
  { "foreign.order_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "shipments",
  "link_orders__shipments",
  "shipment",
  { order_by => "shipment.date" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ElKo7KR5A1+6WapDqC/FeA

use 5.014;
use Moose;
with 'XTracker::Schema::Role::CSMPreference',
     'XTracker::Schema::Role::CanUseCSM',
     'XTracker::Schema::Role::GetTelephoneNumber',
     'XTracker::Schema::Role::Hierarchy';

use XT::Business;
use XTracker::SchemaHelper qw(:records);
use XTracker::Database::Order qw/ check_order_payment /;
use XTracker::Database::PreOrder qw/ :utils /;
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw/
    :customer_class
    :flag
    :note_type
    :renumeration_type
    :shipment_class
    :shipment_status
    :shipment_item_status
    :order_status
    :promotion_class
    :security_list_status
    :shipment_hold_reason
/;
use XTracker::Config::Local     qw( has_delivery_signature_optout
                                    config_var
                                    sys_config_var
                                  );
use XTracker::Utilities         qw( number_in_list );

use XT::Cache::Function         qw( cache_and_call_method :stop );

use XTracker::Logfile           qw( xt_logger );

use List::Util 'sum';
use Carp qw/ croak /;

use Try::Tiny;

use XTracker::Database::Customer qw( get_order_address_customer_name );
use XTracker::Shipment::LateChecker;

__PACKAGE__->belongs_to(
    'order_channel' => 'Public::Channel',
    { 'foreign.id' => 'self.channel_id' },
);

__PACKAGE__->belongs_to(
    'order_address' => 'Public::OrderAddress',
    { 'foreign.id' => 'self.invoice_address_id' },
);

__PACKAGE__->belongs_to(
    'customer' => 'Public::Customer',
    { 'foreign.id' => 'self.customer_id' },
);

__PACKAGE__->has_many(
    'payments' => 'XTracker::Schema::Result::Orders::Payment',
    {'foreign.orders_id' => 'self.id'}
);

__PACKAGE__->has_many(
    'remote_dc_query' => 'Public::RemoteDcQuery',
    {'foreign.orders_id' => 'self.id'}
);
__PACKAGE__->many_to_many(
    'marketing_promotions',
    link_orders__marketing_promotions => 'marketing_promotion'
);

=head1 METHODS

=head2 new

Overriding new method so as to set default value to a row in orders table.

This will set 'pre_auth_value' = 'total_value'  in orders table.

Note: we wanted to save the original order value of order as total_value may get updated, not sure.

'pre_auth_value' field would be populated once when order is inserted and should not be updated thereafter.

If there is better way to do the same feel free to change the code.

=cut

sub new {
    my ( $class, $attrs ) = @_;

    if(defined $attrs->{total_value} ) {
        $attrs->{pre_auth_total_value} = $attrs->{total_value} unless defined $attrs->{pre_auth_total_value};
    }

    my $new = $class->next::method($attrs);

    return $new;
  }

=head2 allocate

Calls C<allocate> on all constituent shipments

=cut

sub allocate {
    my ($self, $operator_id) = @_;
    return map { $_->allocate({ operator_id => $operator_id }) } $self->shipments;
}

=head2 get_standard_class_shipment

Gets the original outgoing shipment (the 'standard' class shipment) for this
order.

=cut

sub get_standard_class_shipment {
    my($self) = @_;

    # get hold of the standard shipment
    my $rs = $self->shipments->search({
        shipment_class_id => $SHIPMENT_CLASS__STANDARD,
    });

    if (not $rs->count == 1) {
        warn ref($self)
           . " - found more than one 'standard' shipment - "
           . "Ben said there should only be one - this is bad data";
    }

    return $rs->first;
}

sub make_order_status_message {
    my($self) = @_;

    # get hold of the standard shipment
    my $shipment = $self->get_standard_class_shipment;
    $shipment->discard_changes;

    my $method = $shipment->shipment_type->type;

    unless ($method eq 'Premier') {
      # One of 'Premier', 'DHL Express (Domestic)',
      # 'DHL Express (International)', 'DHL Express (FTBC)',
      # 'DHL Express (International Road)', 'UPS (Domestic)', or
      # 'UPS (International)'
      #
      # These come from carrier.name and shipping_account.name
      my $account = $shipment->shipping_account;
      $method = $account->carrier->name . " (" . $account->name . ")";
    }

    my $return = {
        # this is for consistency with Fulcrum->Backend, Backend->Fulcrum messages
        # but should be ignored by the Frontend consumers.
        '@type'             => 'order',

        "orderNumber"       => $self->order_nr,
        "status"            => $shipment->shipment_status->status,
        "shippingMethod"    => $method,
        "orderItems" => [ ]
    };
    $return->{trackingUri} = $shipment->tracking_uri
      if $shipment->tracking_uri;

    $return->{trackingNr} = $shipment->outward_airway_bill
      if $shipment->outward_airway_bill;

    # if shipment is dispatched send a return cutoff date
    if ($shipment->shipment_status_id == $SHIPMENT_STATUS__DISPATCHED &&
        $shipment->return_cutoff_date)
    {
        $return->{returnCutoffDate} = $shipment->return_cutoff_date,
    }

    my $out = $return;

    my $rma = $shipment->returns->not_cancelled->first;

    if ($rma) {

        my $renum = $rma->renumerations->first;
        $out->{returnRefundCurrency} = $renum->currency->currency
            if $renum;
        $out->{returnRefundAmount} = $renum->grand_total
            if $renum;
        $renum = !$renum
               ? undef
               : $renum->renumeration_type_id == $RENUMERATION_TYPE__STORE_CREDIT
               ? 'CREDIT'
               : 'CARD';

        $out->{rmaNumber} = $rma->rma_number;

        # Older returns might not have creation dates. Expiry and Cancellation
        # are derived from creation, so only send them if we have a creation
        # date
        if ($rma->creation_date) {
          $out->{returnCreationDate} = $rma->creation_date;
          $out->{returnExpiryDate} = $rma->expiry_date;
          $out->{returnCancellationDate} = $rma->cancellation_date;
        }
        $out->{returnRefundType} = $renum if $renum;
    }


    # add details of the shipment items
    my $items = $shipment->shipment_items->order_by_sku;

    # business logic encapsulated using module pluggable
    my $business_logic = XT::Business->new({ });
    my $plugin = $business_logic->find_plugin(
        $self->channel,'Fulfilment');

    LINE_ITEM:
    while (my $item = $items->next) {
        my $variant = $item->get_true_variant;
        my $hash = {
            sku                 => ( defined $plugin ) ? $plugin->call('get_real_sku',$variant) : $variant->sku,
            xtLineItemId        => $item->id,
            status              => $item->website_status->status,
            unitPrice           => $item->unit_price,
            tax                 => $item->tax,
            duty                => $item->duty,
            returnable          => $item->is_returnable_on_pws ? 'Y' : 'N',
            notPrimaryReturn    => 'N',
        };
        if ( defined $item->pws_ol_id && $item->pws_ol_id > 0 ) {
            # send the OL_ID for the item got from the web if it's set
            $hash->{orderItemNumber}    = $item->pws_ol_id;
        }
        # is the item for a Voucher
        if ( defined $item->voucher_variant_id ) {
            if ( defined $item->voucher_code_id ) {
                # if there is a Voucher Code for the
                # item then put it in the message
                $hash->{voucherCode}    = $item->voucher_code->code;
            }
        }
        push @{$out->{orderItems} }, $hash;

        if ($rma) {
            my $return_item = $shipment->return_item_from_primary_return($item->id);

            if (!$return_item) {
                # this is the case where we can't find the return_item via the
                # primary return because the item is on a non-primary return
                # and we want to flag it as so
                if ($hash->{status} eq 'Return Pending') {
                    $hash->{notPrimaryReturn} = 'Y';
                }
                next LINE_ITEM;
            }
            next LINE_ITEM if $return_item->is_cancelled;

            my $returned = $hash->{status} eq 'Returned';

            if ($return_item->creation_date) {
                $hash->{returnCreationDate} = $return_item->creation_date;
            }
            $hash->{returnReason} = $return_item->customer_issue_type->pws_reason;

            if ($return_item->is_exchange) {
                if ($return_item->exchange_shipment_item) {
                    my $ex_si = $return_item->exchange_shipment_item;
                    $hash->{exchangeSku} = ( defined $plugin ) ? $plugin->call('get_real_sku', $ex_si->variant ) : $ex_si->variant->sku;

                    $hash->{returnCompletedDate} = $return_item->exchange_ship_date
                        if $returned;
                } else {
                    Carp::croak( sprintf
                        "ERROR Should never get here - " .
                        "Return item id '%d' return type is exchange but we have no exchange_shipment_item allocated",
                            $return_item->id
                    );
                }
            } else {
                if ($returned) {
                    $hash->{returnCompletedDate} = $return_item->refund_date;
                }
            }
        }
    }

    return $return;
}


=head2 get_vouchers_by_code_id

Given a code or an arrayref of voucher_code_ids, return a Voucher::Code resultset that
match.

=cut

sub get_vouchers_by_code_id {
    my ( $self, $code_id ) = @_;
    return $self->voucher_tenders
                ->search({ voucher_code_id => $code_id })
                ->related_resultset('voucher_instance');
}

=head2 voucher_value_used

Return the amount spent on a given voucher code against an order.

=cut

sub voucher_value_used {
    my ( $self, $code_id ) = @_;
    return $self->search_related('tenders', {voucher_code_id => $code_id})
                ->get_column('value')
                ->sum;
}

=head2 voucher_tenders

Return a resultset of Result::Orders::Tender that have a 'Voucher Credit'
type.

=cut

sub voucher_tenders {
    return $_[0]->search_related('tenders',
        {type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT});
}

=head2 store_credit_tenders

Return a Result::Orders::Tender object of type store credit used to pay for
this order if one exists. Any more than one and you've got bad data!

=cut

sub store_credit_tender {
    my ( $self ) = @_;
    my @tenders = $self->search_related('tenders',
        { type_id => $RENUMERATION_TYPE__STORE_CREDIT });
    return unless @tenders;
    return $tenders[0];
}

=head2 card_debit_tender

Return a Result::Orders::Tender object of type Card Debit used to pay for
this order if one exists. Any more than one and you've got bad data!

=cut

sub card_debit_tender {
    my ( $self ) = @_;
    my @tenders = $self->search_related('tenders',
        { type_id => $RENUMERATION_TYPE__CARD_DEBIT });
    return unless @tenders;
    return $tenders[0];
}

=head2 paid_by

Return a string describing how the purchase was made.

=cut

sub paid_by {
    my ($self) = @_;

    my @payment;

    if($self->search_related('tenders',
        {type_id => $RENUMERATION_TYPE__STORE_CREDIT})->count) {
        push @payment, "Store Credit";
    }

    if($self->search_related('tenders',
        {type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT})->count) {
        push @payment, "Voucher Credit";
    }

    if($self->search_related('tenders',
        {type_id => $RENUMERATION_TYPE__CARD_DEBIT})->count) {
        if ( my $third_party = $self->get_third_party_payment_method ) {
            push @payment, $third_party->payment_method;
        }
        else {
            # if not using a Third Party then set description
            push @payment, "Card Debit";
        }
    }

   return join (", ", @payment);
}

=head2 was_a_card_used

Returns true if there is something remaining to be refunded to a card

=cut

sub was_a_card_used {
    my ($self) = @_;

    return sum map { $_->remaining_value }
            $self->search_related('tenders',
                {type_id => $RENUMERATION_TYPE__CARD_DEBIT});
}

=head2 renumerations

Returns all renumerations for this order

=cut

sub renumerations {
    return $_[0]->shipments->related_resultset('renumerations');
}

=head2 refund_renumerations

Returns the refund renumerations.

=cut

sub refund_renumerations {
    return $_[0]->renumerations->search_rs({
        renumeration_type_id => {
            -in => [ $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_TYPE__STORE_CREDIT ]
        }
    });
}

=head2 payment_renumerations

Returns the payment renumerations.

=cut

sub payment_renumerations {
    return $_[0]->renumerations->search_rs({
        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
    });
}

=head2 tender_count

Returns the count of renumeration_tenders against this order.

=cut

sub tender_count {
    my($self) = @_;
    my $count = $self->all_tenders->count;
    return $count ? $count : 0;
}

=head2 all_tenders

Returns all the tenders associated with the order

=cut

sub all_tenders {
    #return $_[0]->tenders->related_resultset('renumeration_tenders');
    return $_[0]->tenders->all;
}


=head2 voucher_only_order

Check if an order only contains voucher products.

=cut

sub voucher_only_order {
    my ( $self, $order_rs ) = @_;

    die "Requires order resultset object" if not defined $order_rs;

    my $voucher_order = 0;

    # if an order only has shipment items with 'voucher_variant_id' assigned
    # and 'variant_id' is null on all items then the order only contains gift
    # vouchers
    my $link_order__shipment_rs = $order_rs->link_orders__shipments;#->shipment;
    while (my $order_shipment = $link_order__shipment_rs->next) {
        my $shipment_items_rs = $order_shipment->shipment->shipment_items;
            while (my $shipment_item = $shipment_items_rs->next) {
                if ( defined($shipment_item->voucher_variant_id)
                    && !defined($shipment_item->variant_id) ) {
                    $voucher_order = 1;
                }
                else {
                    $voucher_order = 0;
                    last;
                }
            }
    }
    return $voucher_order;
}

=head2 change_status_to

Change the order status to what is being passed and log it

=cut

sub change_status_to {
    my($self,$status_id,$operator_id) = @_;

    # Refuse to change status if it is currently CANCELLED
    if ( $self->order_status_id == $ORDER_STATUS__CANCELLED ) {
        die "Cannot change the status of order id ".$self->id." with current status of CANCELLED"
    }

    $self->create_related('order_status_logs',{
        order_status_id => $status_id,
        operator_id => $operator_id,
        date => \'current_timestamp',
    });
    $self->update({
        order_status_id => $status_id,
    });
}

=head2 set_status_credit_hold

Set the order status to 'Credit Hold' and log it

=cut

sub set_status_credit_hold {
    my($self,$operator_id) = @_;
    die "Expecting operator_id to log action against" if (!defined $operator_id);

    $self->change_status_to( $ORDER_STATUS__CREDIT_HOLD,$operator_id );
}

=head2 set_status_accepted

Set the order status to 'Accepted' and log it

=cut

sub set_status_accepted {
    my($self,$operator_id) = @_;
    die "Expecting operator_id to log action against" if (!defined $operator_id);

    $self->change_status_to( $ORDER_STATUS__ACCEPTED,$operator_id );
}

=head2 add_flag

For adding flags to orders for various reasons

=cut

sub add_flag :Export(:DEFAULT) {
    my($self,$flag_id) = @_;

    return $self->create_related('order_flags',{
        flag_id => $flag_id,
    });

}

=head2 add_flag_once

For adding Finance Flags but only Once, so it checks to see if the Flag is already present

=cut

sub add_flag_once :Export(:DEFAULT) {
    my ( $self, $flag_id )  = @_;

    if ( $self->order_flags->count( { flag_id => $flag_id } ) ) {
        # already got this flag so don't create it again
        return;
    }

    return $self->add_flag( $flag_id );
}

=head2 has_flag

    $boolean = $self->has_flag('Flag Description');

Will return TRUE or FALSE based on whether the Order has the Order Flag.

=cut

sub has_flag {
    my ( $self, $flag ) = @_;

    my $count = $self->search_related( 'order_flags',
        {
            'flag.description' => $flag,
        },
        {
            join => 'flag',
        }
    )->count;

    return ( $count ? 1 : 0 );
}

=head2 has_psp_reference

    $boolean = $self->has_psp_reference;

Will return TRUE if any part of the Payment was by Card and therefore
has an entry in the 'orders.payment' table with a PSP Reference.

=cut

sub has_psp_reference {
    my $self    = shift;
    return ( $self->payments->count() ? 1 : 0 );
}

=head2 non_store_credit_tenders

Will return all tenders that are not C<$RENUMERATION_TYPE__STORE_CREDIT>

=cut

sub non_store_credit_tenders {
    my($self) = @_;

    return $self->search_related('tenders',{
        type_id => { '!=' => $RENUMERATION_TYPE__STORE_CREDIT },
    });
}

=head2 add_shipment

    my $shipment = $order->add_shipment( $order )

Pass an L<XT::Data::Order> object to an order row to create the associated shipment
for the order.

Returns the new shipment row.

=cut

sub add_shipment {
    my ( $self, $order ) = @_;

    croak "Order object required"
        unless $order and ref $order eq 'XT::Data::Order';

    my $schema = $self->result_source->schema;

    my $shipment = $schema->resultset('Public::Shipment')->create({
        date                        => $order->order_date->datetime,

        shipment_type_id            => $order->shipment_type->id,
        shipment_class_id           => $SHIPMENT_CLASS__STANDARD,
        shipment_status_id          => $order->shipment_status_id,
        shipping_charge_id          => $order->shipping_charge->id,
        shipping_account_id         => ($order->shipping_account ? $order->shipping_account->id : 0),
        premier_routing_id          => ($order->premier_routing ? $order->premier_routing->id : 0),

        gift                        => $order->is_gift_order,
        gift_message                => $order->gift_message || '',
        outward_airway_bill         => 'none',
        return_airway_bill          => 'none',
        email                       => $order->delivery_email,
        telephone                   => $order->delivery_primary_phone,
        mobile_telephone            => $order->delivery_mobile_phone,
        packing_instruction         => $order->packing_instruction || '',
        comment                     => '',
        delivered                   => 0,
        gift_credit                 => $order->extract_money( 'gift_credit' ),
        store_credit                => $order->extract_money( 'store_credit' ),
        legacy_shipment_nr          => '',
        destination_code            => undef,
        shipping_charge             => $order->shipping_total->value,
        real_time_carrier_booking   => 0,
        av_quality_rating           => undef,
        sla_priority                => undef,
        sla_cutoff                  => undef,
        has_packing_started         => undef,
        packing_other_info          => undef,
        signature_required          => $order->signature_required,

        nominated_delivery_date     => $order->nominated_delivery_date,
        nominated_dispatch_time     => $order->nominated_dispatch_time,
        nominated_earliest_selection_time => $order->nominated_earliest_selection_time,

        # We don't call SOS for staff bookings or virtual voucher only orders -
        # so we force manual booking here
        force_manual_booking => (
            $self->is_staff_order || $order->_virtual_voucher_only_order ? 1 : 0
        ),

        shipment_address => {
            first_name      => $order->delivery_name->first_name,
            last_name       => $order->delivery_name->last_name,
            address_line_1  => $order->delivery_address->line_1,
            address_line_2  => $order->delivery_address->line_2,
            address_line_3  => $order->delivery_address->line_3,
            towncity        => $order->delivery_address->town,
            county          => $order->delivery_address->county,
            country         => $order->delivery_address->country->country,
            postcode        => $order->delivery_address->postcode,
            address_hash    => $order->address_hash( 'delivery' ),
            urn             => $order->delivery_address->urn,
            last_modified   => $order->delivery_address->last_modified,
        },
    });

    $shipment->create_related( 'link_orders__shipment', {
        orders_id   => $self->id,
        shipment_id => $shipment->id,
    });

    if ( $order->is_free_shipping ) {
        $shipment->create_related( 'link_shipment__promotion', {
            shipment_id => $shipment->id,
            promotion   => $order->free_shipping->description,
            value       => $order->free_shipping->value,
        });
    }

    my @items = $order->all_line_items;
    foreach ( @items ) {

        my $count = $_->quantity;

        while ( $count > 0 ) {

            my $item = $shipment->new_related( 'shipment_items', {
                unit_price              => $_->unit_net_price->value,
                tax                     => $_->tax->value,
                duty                    => $_->duties->value,
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                special_order_flag      => 0,
                shipment_box_id         => undef,
                returnable_state_id     => $_->get_returnable_state_id,
                pws_ol_id               => $_->id,
                gift_from               => $_->gift_from,
                gift_to                 => $_->gift_to,
                gift_message            => ( defined $_->gift_message ? $_->gift_message : '' ),
                qc_failure_reason       => undef,
                container_id            => undef,
                gift_recipient_email    => (  defined $_->gift_recipient_email ? $_->gift_recipient_email : ''),
                sale_flag_id            => $_->get_on_sale_flag_id // undef,
            });

            if ( $_->is_voucher ) {
                $item->set_columns({
                    voucher_variant_id => $_->variant->id,
                    voucher_code_id    => $_->voucher_code_id,
                });
            }
            else {
                $item->set_columns({
                    variant_id => $_->variant->id
                });
            }
            $item->insert_or_update;

            if ( $_->cost_reduction ) {
                $item->create_related( 'link_shipment_item__promotion', {
                    promotion   => $_->cost_reduction->description,
                    unit_price  => $_->cost_reduction->unit_net_price,
                    tax         => $_->cost_reduction->unit_tax,
                    duty        => $_->cost_reduction->unit_duties,
                });
            }

            if ( !$_->is_voucher && $item->has_price_adjustment ) {
                $item->create_related( 'link_shipment_item__price_adjustment', {
                    shipment_item_id    => $item->id,
                    price_adjustment_id => $item->price_adjustment->id,
                });
            }

            if ( $_->is_physical ) {
                my $log_stock_rs = $schema->resultset('Public::LogPwsStock');
                $log_stock_rs->log_order( $item );
            }

        $count--;
        }
    }

    # Implementation of SLAs at end of creation of order
    try {
        $shipment->apply_SLAs;
    }
    catch {
        my $error = $_;
        xt_logger->error(
            "SLA ERROR: Applying SLAs for Order: '" . $self->order_nr . "' on Channel: '" . $self->channel->name . "'" .
            ", Error: " . ( $error // 'undef' )
        );
        $self->add_note(
            $NOTE_TYPE__SHIPPING,
            "There was a problem when this Order was Imported in applying the Shipment SLAs." .
            " The error returned was: " . ( $error // 'undef' ),
        );
        if ( $shipment->is_processing ) {
            # put the Shipment on Hold because of the SLA failure
            $shipment->put_on_hold( {
                status_id   => $SHIPMENT_STATUS__HOLD,
                operator_id => $APPLICATION_OPERATOR_ID,
                norelease   => 1,
                reason      => $SHIPMENT_HOLD_REASON__OTHER,
                comment     => "Due to a System Error NO SLAs could be applied to this Shipment at the time of Import." .
                               " Please contact Service Desk if you are unable to Release this Shipment",
            } );
            # just make sure everything is up to date
            $shipment->discard_changes;
        }
    };

    # If we already know the shipment will not be able to meet it's delivery promise,
    # then notify interested parties
    try {
        my $late_checker = XTracker::Shipment::LateChecker->new();
        $late_checker->send_late_shipment_notification({ shipment => $shipment })
            if $late_checker->check_address({
                address         => $shipment->shipment_address(),
                shipping_charge => $shipment->shipping_charge_table(),
            });
    } catch {
        my $error = $_;
        xt_logger->error(sprintf('There was an error checking the late status of shipment %s : %s',
            $shipment->id(),
            $error
        ));
    };


    return $shipment;
}

=head2 add_order_payment

    my $payment = $order->add_order_payment( $order )

Pass an L<XT::Data::Order> object to an order row to create the associated order
payment for the order.

Returns the new order payment row.

=cut

sub add_order_payment {
    my ( $self, $order ) = @_;

    croak "Order object required" unless $order and ref $order eq 'XT::Data::Order';

    my $payment_rs = $self->result_source->schema->resultset('Orders::Payment');

    my $data;

    if ($order->preorder) {
        $data = {
            orders_id   => $self->id,
            psp_ref     => $order->preorder->get_payment->psp_ref,
            preauth_ref => $order->preorder->get_payment->preauth_ref,
            settle_ref  => $order->preorder->get_payment->settle_ref,
            fulfilled   => 't',
            payment_method_id => $order->preorder->get_payment->payment_method_rec->id,
        }
    }
    else {
        $data = {
            orders_id   => $self->id,
            psp_ref     => $order->psp_ref,
            preauth_ref => $order->preauth_ref,
            payment_method_id => $order->payment_method_rec->id,
        }
    }

    return $payment_rs->create($data);
}


=head2 cancel_payment_preauth

    $result = $self->cancel_payment_preauth( {
                                    context => $context,
                                    operator_id => $operator_id,
                                } );

If the order has an 'orders.payment' record attached it will try and cancel the preauth through the PSP. The
Context and Operator Id if absent will be defaulted.

It returns the same as 'Orders::Payment::psp_cancel_preauth' if there is a payment to cancel else it returns undef.

It will return 'undef' if the order was paid through Store Credit & or Gift Vouchers which won't have a payment record.

=cut

sub cancel_payment_preauth {
    my ( $self, $args )     = @_;

    my $retval;

    # get the payment record if there is one
    my $payment = $self->payments->first;

    if ( defined $payment ) {
        my $response    = $payment->psp_cancel_preauth( $args );

        if ( exists( $response->{success} )
             || ( exists( $response->{error} ) && $response->{error} == 1 ) ) {
            # create an Order Note to let the users know what happened
            # providing something did happen - level 2 errors mean nothing happened
            $self->add_note(
                $NOTE_TYPE__FINANCE,
                "Cancel Payment Pre-Auth (".$payment->preauth_ref.") in context '$$response{context}': "
                        . ( exists( $response->{success} ) ? 'SUCCESSFUL' : 'FAILED' ),
                $response->{operator_id},
            );
        }

        $retval = $response;
    }

    return $retval;
}

=head2 cancel_payment_preauth_and_invalidate_payment

    $result = $self->cancel_payment_preauth_and_invalidate_payment( {
        context     => $context,
        operator_id => $operator_id,
    } );

This will call '$self->cancel_payment_preauth' which will attempt to Cancel the Pre-Auth
if it does it will then Invalidate the Payment record.

It returns the same as 'cancel_payment_preauth' if there is a payment to cancel else it
returns 'undef'.

It will return 'undef' if the order was paid through Store Credit & or Gift Vouchers
which won't have a payment record.

=cut

sub cancel_payment_preauth_and_invalidate_payment {
    my ( $self, $args ) = @_;

    my $retval = $self->cancel_payment_preauth( $args ) // {};

    if ( $retval->{success} ) {
        $self->payments->invalidate;
    }

    return $retval;
}

=head2 cancel_payment_preauth_and_delete_payment

    undef or $hash_ref = $self->cancel_payment_preauth_and_delete_payment( {
        context     => 'Some Context',
        operator_id => $operator_id,
    } );

This will Cancel a Payment Pre-Auth by making a call the the PSP and then Delete
the 'orders.payment' record. Before it Deletes the Payment record it will copy it
to the 'orders.replaced_payment' table and move all the logs for the Payment
record to their Replaced Payment log equivalents.

Pass the 'context' and 'operator_id' so that they can be used to create notes on the
Order detailing what happened and why and by whom.

It will return 'undef' if there is no Payment for the Order or a Hash Ref. containing
the following keys:

    {
        payment_deleted => 1,
        preauth_successfully_cancelled => 1 or 0,
    }

If the PSP failed to Cancel the PSP then 'preauth_successfully_cancelled' will be FALSE
but the Payment record will still be Deleted because this shouldn't be obstructed by
the PSP failing to Cancel a Pre-Auth which could happen for various reasons and this
shouldn't block anything as the Pre-Auth won't be being Settled anyway.

This method calls the 'cancel_payment_preauth' method to make the request to the PSP.

=cut

sub cancel_payment_preauth_and_delete_payment {
    my ( $self, $args ) = @_;

    my $payment = $self->payments->first;
    return      if ( !$payment );

    foreach my $param ( qw( context operator_id ) ) {
        croak "No '${param}' was passed in the Arguments for 'cancel_payment_preauth_and_delete_payment'"
                if ( !$args->{ $param } );
    }

    # this will Cancel the Pre-auth by contacting the PSP,
    # this could fail (for various reaons) if it does then
    # the Payment should still be Delete as it isn't needed
    # anymore and no attempt to Settle it will be made, failure
    # to Cancel doesn't need to block this functionality
    my $result = $self->cancel_payment_preauth( {
        context     => $args->{context},
        operator_id => $args->{operator_id},
    } );

    my $replaced_payment = $payment->copy_to_replacement_and_move_logs();
    $payment->delete;

    $self->add_note(
        $NOTE_TYPE__FINANCE,
        "Removed '" . $replaced_payment->payment_method->payment_method . "' Payment in context '" . $args->{context} . "'",
        $args->{operator_id},
    );

    # return a status of what happened
    my $retval = { payment_deleted => 1 };
    if ( $result ) {
        $retval->{preauth_successfully_cancelled} = ( exists( $result->{success} ) ? 1 : 0 );
    }

    return $retval;
}

=head2 should_put_onhold_for_signature_optout_for_standard_class_shipment

    $boolean    = $self->should_put_onhold_for_signature_optout_for_standard_class_shipment();

Will return TRUE if the Standard Class Shipment has Opted Out of requiring Signature on Delivery.
This is used by the Order Importer as there will only be a Standard Class Shipment when the Order
is first created.

It wraps around 'should_put_onhold_for_signature_optout_for_standard_class_shipment'.

=cut

sub should_put_onhold_for_signature_optout_for_standard_class_shipment {
    my $self    = shift;

    my $shipment    = $self->get_standard_class_shipment;

    # Return FALSE if the Customer hasn't Opted Out of Signing for Delivery
    return 0        if ( $shipment->is_signature_required );

    return $self->should_put_onhold_for_signature_optout( $shipment );
}

=head2 should_put_onhold_for_signature_optout

    $boolean    = should_put_onhold_for_signature_optout( $shipment || $shipment_id );

This will return TRUE if the Order & Shipment should be put on Hold if the Customer has Opted Out for Delivery Signature.

Currently only meaningful if used in DC2. Checks to see if the Shipment Total is >= a Threshold for the Channel and makes
sure the Customer is not an 'EIP'.

Can pass either a 'Public::Shipment' or a Shipment Id.

=cut

sub should_put_onhold_for_signature_optout {
    my ( $self, $shipment )     = @_;

    if ( !defined $shipment ) {
        croak "'should_put_onhold_for_signature_optout' was passed with no 'Shipment'";
    }

    if ( !ref( $shipment ) ) {
        my $ship_id = $shipment;
        $shipment   = $self->shipments->find( $ship_id );
        if ( !defined $shipment ) {
            croak "'should_put_onhold_for_signature_optout' coulnd't find a Shipment for the Id: $ship_id";
        }
    }
    elsif ( ref( $shipment ) ne 'XTracker::Schema::Result::Public::Shipment' ) {
        croak "'should_put_onhold_for_signature_optout' was not passed a 'Public::Shipment' object but a '" . ref( $shipment ) ."'";
    }

    my $retval  = 0;

    # if the DC does have the abilty to optout of the Signature
    if ( has_delivery_signature_optout() ) {
        # if the Customer's Category Class is NOT 'EIP'
        if ( $self->customer->category->customer_class_id != $CUSTOMER_CLASS__EIP ) {
            # get the Total Amount for the Shipment
            # not interested in taking off Store Credt
            my $total   = $shipment->shipping_charge
                          + $shipment->total_price
                          + $shipment->total_tax
                          + $shipment->total_duty;

            if ( $self->channel->is_above_no_delivery_signature_threshold( $total, $self->currency ) ) {
                $retval = 1;        # it should be put on hold
            }
        }
    }

    return $retval;
}

=head2 put_on_credit_hold_for_signature_optout

    $boolean    = put_on_credit_hold_for_signature_optout( $shipment, $operator_id );

This will put an Order on Credit Hold and the Shipment on Finance Hold if the Shipment's Delivery Signature is FALSE and the rules say that it should be put on hold.

Returns 1 or 0 depending on whether anything was actually updated.

=cut

sub put_on_credit_hold_for_signature_optout {
    my ( $self, $shipment, $operator_id )   = @_;

    if ( !defined $shipment ) {
        croak "'put_on_credit_hold_for_signature_optout' was passed with no 'Shipment'";
    }
    if ( !defined $operator_id) {
        croak "'put_on_credit_hold_for_signature_optout' was passed with no 'Operator Id'";
    }

    if ( !ref( $shipment ) ) {
        my $ship_id = $shipment;
        $shipment   = $self->shipments->find( $ship_id );
        if ( !defined $shipment ) {
            croak "'put_on_credit_hold_for_signature_optout' coulnd't find a Shipment for the Id: $ship_id";
        }
    }
    elsif ( ref( $shipment ) ne 'XTracker::Schema::Result::Public::Shipment' ) {
        croak "'put_on_credit_hold_for_signature_optout' was not passed a 'Public::Shipment' object but a '" . ref( $shipment ) ."'";
    }

    my $retval  = 0;

    # don't put something on Hold if the Signature Required hasn't been Opted Out of
    if ( !$shipment->is_signature_required ) {
        # first check the statuses are ok
        if ( ( $self->order_status_id == $ORDER_STATUS__ACCEPTED )
               && ( number_in_list( $shipment->shipment_status_id,
                                                $SHIPMENT_STATUS__PROCESSING,
                                                $SHIPMENT_STATUS__HOLD,
                                                $SHIPMENT_STATUS__DDU_HOLD ) ) ) {
            # then check to see if the Shipment means the Order Should go on Hold
            if ( $self->should_put_onhold_for_signature_optout( $shipment ) ) {
                $self->add_flag_once( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
                $self->set_status_credit_hold($operator_id);
                $shipment->set_status_finance_hold($operator_id);
                $retval = 1;
            }
        }
    }

    return $retval;
}

=head2 add_note

    $note_record    = $orders->add_note( $note_type_id, $note, $operator_id );

This will add a note to the 'order_note' record, if no '$operator_id' is passed it will default to $APPLICATION_OPERATOR_ID.

=cut

sub add_note {
    my ( $self, $type_id, $note, $operator_id ) = @_;

    $operator_id    ||= $APPLICATION_OPERATOR_ID;

    return $self->create_related( 'order_notes', {
                                    note_type_id    => $type_id,
                                    operator_id     => $operator_id,
                                    date            => \"now()",
                                    note            => $note,
                            } );
}

=head2 branded_salutation

Return the branded salutation for this order.

=cut

sub branded_salutation {
    my $self = shift;

    return $self->channel->business->branded_salutation( get_order_address_customer_name( $self->invoice_address, $self->customer ));
}

=head2  invalidate_order_payment

sets the invalid flag to TRUE of orders.payment if order payments changes
beyond the threshold.

=cut

sub invalidate_order_payment {
    my $self = shift;

    if ($self->discard_changes()->is_beyond_valid_payments_threshold) {
       $self->payments->invalidate();
    }
    return;
}

=head2 validate_order_payment

=cut

sub validate_order_payment {
    my $self = shift;

    $self->discard_changes->payments->validate();
    return;
}


=head2 is_beyond_valid_payments_threshold

   $boolean    = is_beyond_valid_payments_threshold();


Returns 1 or 0 depending on whether order_total value flututated above maximum threshold.

note: we are not checking for minimum threshold.

=cut

sub is_beyond_valid_payments_threshold {
    my( $self) = shift;

    if ( my $payment = $self->payments->first ) {
        # use the PSP to check if the threshold has been reached,
        # if 'undef' came back then something went wrong so don't
        # return anything and use the config as a fallback
        my $result = $payment->amount_exceeds_threshold( $self->get_total_value_less_credit_used );
        return $result      if ( defined $result );
    }

    # get config_var for invalid_payments_threshold -
    # calculating the percentage
    my $percentage = config_var('Valid_Payments', 'valid_payments_threshold') * 0.01;
    my $threshold  = abs( $self->pre_auth_total_value) * $percentage;

    my $max = abs( $self->pre_auth_total_value + $threshold );

    # CANDO-853
    if( abs($self->get_total_value) > $max ) {
        return 1;
    }

    return 0;

}

=head2 get_total_value

    $decimal    = $self->get_total_value;
            or
    $decimal    = $self->get_total_value( { want_original_purchase_value => 1 } );

This will return the Total Value for the Order taking into account Cancelled Shipment
Items and any Changes to the Value after any Address Changes, by getting the Values
from the Shipment Items.

If you want the Original Purchase Value then pass the argument 'want_original_purchase_value'
and this will give you back the value in the 'total_value' field on the 'orders' record.

=cut

sub get_total_value {
    my ( $self, $args ) = @_;

    if ( $args->{want_original_purchase_value} ) {
        return $self->total_value;
    }

    my $total_order_value;

    my @shipments = $self->shipments->not_cancelled->all;

    foreach my $shipment ( @shipments ) {
        # CANDO: Yes, this is essentially converting the order currency to the
        # order currency (a no-op), but for now, due to time constraints, we're
        # not going to change this.
        $total_order_value += $shipment->total_price( $self->currency->currency)
                           + $shipment->total_tax( $self->currency->currency)
                           + $shipment->total_duty( $self->currency->currency)
                           + $shipment->shipping_charge;
    }

   return $total_order_value // 0;
}

=head2 get_total_value_less_credit_used

    $decimal = $self->get_total_value_less_credit_used();

This gets the Total Value of the Order (uses 'get_total_value' which excludes
Cancelled Items) less any Store or Gift Voucher Credit that was used to pay
for the Order. This then gives the amount that should be taken from a Card
or Third Party Payment (PayPal).

If (because of Cancelled Items) the Store & Gift Voucher Credit used is now
greater than the Total Value ZERO will be returned and NOT a negative number.

=cut

sub get_total_value_less_credit_used {
    my $self = shift;

    my $total_value = $self->get_total_value;

    my $total_credit_value = 0;
    if ( my $store_credit_tender = $self->store_credit_tender ) {
        $total_credit_value += $store_credit_tender->value;
    }

    my $voucher_tenders_rs = $self->voucher_tenders;
    $total_credit_value   += $voucher_tenders_rs->get_column('value')->sum() // 0;

    # amount that will be taken from either a Card or Third Party Payment
    my $payment_total = ( $total_value - $total_credit_value );
    # if Store & Voucher Credit now more than Total then make Value ZERO
    $payment_total    = 0       if ( $payment_total < 0 );

    return $payment_total;
}

=head2 is_in_credit_check

Returns a true value if the order's status is 'Credit Check'

=cut

sub is_in_credit_check {
    return $_[0]->status_id == $ORDER_STATUS__CREDIT_CHECK;
}

=head2 is_on_credit_hold

Returns true if the order's status is B<Credit Hold>.

=cut

sub is_on_credit_hold {
    return shift->order_status_id == $ORDER_STATUS__CREDIT_HOLD;
}

=head2 is_accepted

Returns true if the order's status is B<Accepted>.

=cut

sub is_accepted {
    return shift->order_status_id == $ORDER_STATUS__ACCEPTED;
}

=head2 link_with_preorder

Create link between Order and PreOrder

=cut

sub link_with_preorder {
    my($self, $preorder_number) = @_;

    # be safe and assume either an ID or Number was passed
    my $preorder_id = get_pre_order_id_from_number_or_id($preorder_number);

    $self->create_related('link_orders__pre_orders',{
        pre_order_id => $preorder_id
    });
}

=head2 get_preorder

Return PreOrder DBIx object

=cut

sub get_preorder {
    my $self = shift;
    if ($self->link_orders__pre_orders->count) {
        return $self->link_orders__pre_orders->first->pre_order;
    }
    else {
        return;
    }
}

=head2 has_preorder

Return true or false if this order has an associated preorder

=cut

sub has_preorder {
    my ($self) = @_;
    if ($self->link_orders__pre_orders->count) {
        return 1;
    }
    else {
        return 0;
    }
}

=head2 order_check_payment

    $boolean    = $self->order_check_payment();

This will call the existing function 'Database::Order::check_order_payment' and is used by many
features such as Cancelling Orders, Editing Shipments to determin if the Payment has been Fulfilled
yet so as to know whether it is safe to proceed. If an Order is paid entirely by Store Credit ot Gift
Vouchers then it will always return FALSE.

This will take into account a Pre-Order and return FALSE if the Order has NOT started Packing otherwise
it will then call the existing 'check_order_payment' function and return whatever that does.

Returns:
    1 - Order Payment found and is Fulfilled
    0 - No Order Payment found or is NOT Fulfilled - This will also be returned for Pre-Order Orders prior to Packing

=cut

sub order_check_payment {
    my ( $self, $args ) = @_;

    my $retval;

    my $dbh = $self->result_source->schema->storage->dbh;

    if ( $self->has_preorder ) {
        # find if any Shipments that have started Packing
        my $num_packed  = $self->shipments
                                ->search( { has_packing_started => 1 } )
                                    ->count;
        if ( $num_packed ) {
            $retval = check_order_payment( $dbh, $self->id );
        }
        else {
            # ok to change things at this stage for Pre-Orders
            $retval = 0;
        }
    }
    else {
        $retval = check_order_payment( $dbh, $self->id );
    }

    return $retval;
}

=head2 has_marketing_promotion

Return 1 or 0 if this order has given marketing promotion associated with it

=cut

sub has_marketing_promotion {
    my $self      = shift;
    my $promotion = shift;

    my $result = $self->search_related('link_orders__marketing_promotions', {
        marketing_promotion_id => $promotion->id,
    })->count;

    return $result;

}


=head2 get_all_marketing_promotions

=cut

sub get_all_marketing_promotions {
    my $self = shift;

    return  [ $self->link_orders__marketing_promotions
                     ->search_related('marketing_promotion',
                        {}, { order_by => 'marketing_promotion.title' } )->all
            ];

}

=head2 has_marketing_promotion

Return 1 or 0 if this order has given order promotion associated with it

=cut

sub has_order_promotion {
    my $self      = shift;
    my $promotion = shift;

    my $result = $self->search_related('order_promotions', {
        _id => $promotion->id,
    })->count;

    return $result;

}

=head2 has_welcome_pack

Return true if this order has a welcome pack associated with it

=cut

sub has_welcome_pack {
    my($self) = @_;
    my $schema = $self->result_source->schema;

    # do we have the promo in the db?
    my $packs = $schema->resultset('Public::PromotionType')
                       ->search_by_ilike_name( 'Welcome Pack%' );

    return if (!$packs || $packs->count == 0);

    my @ids = $packs->get_column('id')->all;
    my $wp_promo = $self->search_related('order_promotions',{
        promotion_type_id => { in => \@ids },
    });

    if ($wp_promo && $wp_promo->count >= 1) {
        return 1;
    }

    return 0;
}

=head2 has_only_order_count_order_flags

Return true if this order has *ONLY* order flags associated with order counts
(1st order etc.). This only takes into account flags in the order_flag
table. It doesn't take into account other types of flags.

=cut

sub has_only_order_count_order_flags {
    my($self) = @_;
    my $schema = $self->result_source->schema;

    my $order_count_flags = [$FLAG__1ST,
                             $FLAG__2ND,
                             $FLAG__3RD,
                             $FLAG__NO_CREDIT_CHECK
                            ];

    my $other_flags
      = $self->search_related( 'order_flags',
                               { 'flag_id' => { -not_in => $order_count_flags }});

    my $has_only_order_count_flags = $other_flags->count ? 0 : 1;

    return $has_only_order_count_flags;
}

=head2 original_shipment_is_dispatched

=cut

sub original_shipment_is_dispatched {
    my $self = shift;

    my $shipment_is_dispatched = 0;
    foreach my $shipment ($self->shipments->all) {
        if($shipment->is_standard_class){
            if($shipment->is_dispatched){
                $shipment_is_dispatched = 1;
            }
        }
    }

    return $shipment_is_dispatched;
}

=head2 get_in_the_box_marketing_promotions

Returns an ordered (by title) ResultSet of all associated Marketing Promotions that have
a Promotion Type that is of a Promotion Class of 'In The Box'.

    my $in_the_box = $schema
        ->resultset('Public::Orders')
        ->get_in_the_box_marketing_promotions;

=cut

sub get_in_the_box_marketing_promotions {
    my $self = shift;

    return $self->marketing_promotions->search(
        {
            'promotion_type.promotion_class_id' => $PROMOTION_CLASS__IN_THE_BOX,
        },
        {
            join => 'promotion_type',
        }
    );

}

=head2 get_free_gift_promotions

Returns a ResultSet of C<Public::OrderPromotion> that have a C<Public::PromotionType>
that is of a C<Public::PromotionClass> of 'Free Gift'.

    my $promotions = $schema
        ->resultset('Public::Orders')
        ->get_free_gift_promotions;

=cut

sub get_free_gift_promotions {
    my $self = shift;

    return $self->order_promotions->search(
        {
            'promotion_type.promotion_class_id' => $PROMOTION_CLASS__FREE_GIFT,
        },
        {
            join => 'promotion_type',
        }
    );
}

=head2 get_total_value_in_local_currency

    $decimal    = $self->get_total_value_in_local_currency;
            or
    $decimal    = $self->get_total_value_in_local_currency( {
        # list of arguments that will be
        # passed through to 'get_total_value'
    } );

Returns the total value of the order converted to the local currency value.

Any arguments will be passed through to 'get_total_value'.

=cut

sub get_total_value_in_local_currency {
    my ( $self, $args ) = @_;

    my $currency            = $self->currency;
    my $local_currency_code = config_var('Currency', 'local_currency_code');

    return $self->get_total_value( $args )
                if ( $currency->currency eq $local_currency_code );

    my $conversion_rate = cache_and_call_method( $currency, 'conversion_rate_to', $local_currency_code );
    return $self->get_total_value( $args ) * $conversion_rate;
}

=head2 get_original_total_value_in_local_currency

    $decimal    = $self->get_original_total_value_in_local_currency;

Gets the Original Purchase Value of the Order in the DC's Local Currency.

This is a wrapper around 'get_total_value_in_local_currency' with the
argument '{ want_original_purchase_value => 1 }' passed.

=cut

sub get_original_total_value_in_local_currency {
    my $self    = shift;

    return $self->get_total_value_in_local_currency( { want_original_purchase_value => 1 } );
}

=head2 order_sequence_for_customer

Returns the seqeuence count number of this order in the customer's order
history - ie 10th order, 35th order, etc.

    my $count = $orders->order_sequence_for_customer();

=cut

sub order_sequence_for_customer {
    my ($self, $args) = @_;

    my $schema = $self->result_source->schema;
    my $dtf    = $schema->storage->datetime_parser;

    # Get the count of all the customers orders, including this one,
    # that where made on or before the date/time of this order.
    #
    # This tells us how many orders where placed up to and including
    # this order.

    my $customer = $self->customer;
    if ( exists $args->{on_all_channels} && $args->{on_all_channels} ) {
        $customer = $customer->on_all_channels;
    }

    return $customer->search_related( 'orders', {
        date => { '<=' => $dtf->format_datetime( $self->date ) },
    } )->count;
}

=head2 is_customers_nth_order

Returns a boolean value identifying whether this order is the customers
n'th order (i.e. first order, second order, third order, etc), based on
the date/time the order was placed.

For example, if the customer has the following orders:

 ID  | DATE
-----+--------------------
 1   | 01/01/2001 00:00:00
 2   | 02/02/2002 00:00:00

This method would return the following:

    my $order1 = $schema->resultset('Public::Orders')->find( 1 );
    my $order2 = $schema->resultset('Public::Orders')->find( 2 );

    $order1->is_customers_nth_order( 1 );
    # True

    $order1->is_customers_nth_order( 2 );
    # False

    $order2->is_customers_nth_order( 1 );
    # False

    $order2->is_customers_nth_order( 2 );
    # True

=cut

sub is_customers_nth_order {
    my ( $self, $nth_order ) = @_;

    my $count = cache_and_call_method( $self, 'order_sequence_for_customer',
        { on_all_channels => 1 }
    );

    return $nth_order == $count;
}

=head2 get_standard_class_shipment_address_country

Returns the country name of the Orders standard class shipment.

    my $order = $schema
        ->resultset('Public::Orders')
        ->find( $id );

    my $country_name = $order
        ->get_standard_class_shipment_address_country;

=cut

sub get_standard_class_shipment_address_country {
    my $self = shift;

    return $self
        ->get_standard_class_shipment
        ->shipment_address
        ->country;

}

=head2 get_psp_info

Will get the PSP Information for the Card used to pay for the Order.

=cut

sub get_psp_info {
    my $self    = shift;

    my $payment = $self->payments->first;
    return      if ( !$payment );       # NO Card Payment

    return cache_and_call_method( $payment, 'get_pspinfo' );
}


=head2 payment_card_type

Returns Card Type from PSP.
    my $card_type = $self->payment_card_type;

    would return 'Master/Visa/Amex' etc.

=cut

sub payment_card_type {
    my $self = shift;

    my $psp_info = $self->get_psp_info;

    return $psp_info->{cardInfo}{cardType} // '';
}

=head2 payment_card_avs_response

    Returns cv2avsStatus code from PSP
    my $cvs_response = $self->payment_card_avs_respone();

    would return status code: ALL MATCH/DATA NOT CHECKED/
    SECURITY CODE MATCH ONLY/NONE etc

=cut

sub payment_card_avs_response {
    my $self = shift;

    my $psp_info = $self->get_psp_info;

    return $psp_info->{cv2avsStatus} // '';

}

=head2 payment_card_currency

Returns Currency from psp

    my $card_currency = $self->payment_card_currency();

would return  currency code: EUR/GBP/HKD etc.

=cut

sub payment_card_currency {
    my $self = shift;

    my $psp_info = $self->get_psp_info;

    return $psp_info->{currency} // '';
}

=head2 get_third_party_invoice_url

Returns the URL of the third party payment invoice from PSP.
    my $invoice_url = $self->get_third_party_invoice_url();

    would return 'https://online.klarna.com/invoices/<invoice_id>.pdf' etc.

=cut

sub get_third_party_invoice_url {
    my $self = shift;

    my $psp_info = $self->get_psp_info;

    my $url;

    my $settlements = $psp_info->{settlements};

    my $payment = $self->payments->first;

    my ($settlement_ref) = grep { $_->{settleReference} eq $payment->settle_ref } @{$settlements};

    $url = $settlement_ref->{invoiceLink} if $settlement_ref->{invoiceLink};

    return $url;
}

=head2 has_payment_card_been_used_before

    Returns Boolean (0 or 1) if the payment card is used before by any customer
    my $boolean = $order->has_payment_card_been_used_before();

=cut

sub has_payment_card_been_used_before {
    my $self = shift;

    my $result  = $self->is_payment_card_new;
    return      if ( !defined $result );
    return ( ! $result );
}

=head2 is_payment_card_new_for_customer

    Returns Boolean (0 or 1) if the payment card is used before for a customer
    my $boolean = $order->is_payment_card_new_for_customer();

=cut

sub is_payment_card_new_for_customer {
    my $self = shift;

    return $self->is_payment_card_new({ include_customer => 1});
}

sub is_payment_card_new {
    my $self = shift;
   my $args = shift || {};

    my $psp_info = $self->get_psp_info;
    return          if ( !$psp_info );

    if ( defined( $psp_info->{paymentHistory} ) ) {

        #  get all the order_nr and remove the id of current order
        #  and exclude pre_orders
        my @order_numbers =
        map { $_->{'orderNumber'} ?  $_->{'orderNumber'} : ()}
        grep {
            $_ &&
            $_->{orderNumber} &&
            $_->{orderNumber} !~ /pre_order/i &&
            $_->{orderNumber} ne $self->order_nr
        }
        @{ $psp_info->{paymentHistory} };

        my $size = @order_numbers;
        # no history
        return 1 if $size <= 0;

        # check if returned order array has any order of this customer
        my %include_customer = ();
        if ( exists $args->{include_customer} && $args->{include_customer} ) {
            %include_customer = (
                'customer_id' => $self->customer_id,
            );

            my $card_usage = $self->result_source->schema->resultset('Public::Orders')
                ->search( {
                    order_nr        => { 'IN' => \@order_numbers },
                    order_status_id => $ORDER_STATUS__ACCEPTED,
                    %include_customer,
                });

            if( $card_usage->count > 0 ) {
                return 0;
            }

        } else {
            return 0;
        }
    }

    return 1;
}

=head2 shipping_address_used_before

=cut

sub shipping_address_used_before {
    my $self = shift;

    my $shipment = $self->get_standard_class_shipment;
    return $shipment->count_address_in_uncancelled > 1 ? 1 : 0;
}

=head2 shipping_address_used_before_for_customer

=cut

sub shipping_address_used_before_for_customer {
    my $self = shift;

    my $shipment = $self->get_standard_class_shipment;
    return $shipment->count_address_in_uncancelled_for_customer > 1 ? 1 : 0;
}

=head2 get_standard_class_shipment_type_id

    $integer = $self->get_standard_class_shipment_type_id;

Returns the Id of the Order's Standard Class Shipment.

=cut

sub get_standard_class_shipment_type_id {
    my $self    = shift;

    return $self->get_standard_class_shipment->shipment_type_id;
}

=head2 shipping_country_risk

Returns true if the country of the first shipment on the order

=cut

sub low_risk_shipping_country {
    my $self = shift;

    my $country = $self->get_standard_class_shipment->shipment_address->country;

    my $schema = $self->result_source->schema;

    my $risk = sys_config_var($schema, 'OrderOriginRisk', $country);

     return $risk ? 1 : 0;
}

=head2 contains_a_voucher

    Returns boolean (1 or 0) if order contains  a voucher

=cut

sub contains_a_voucher {
    my $self = shift;

    my $shipment    = $self->get_standard_class_shipment;
    for my $item ( $shipment->shipment_items->not_cancelled->not_cancel_pending->all ) {
        if( $item->is_voucher) {
            return 1;
        }
    }
    return 0;
}

=head2 contains_a_virtual_voucher

    Returns boolean (1 or 0) if order contains Virtual Voucher

=cut

sub contains_a_virtual_voucher {
    my $self = shift;

    my $shipment    = $self->get_standard_class_shipment;
    for my $item ( $shipment->shipment_items->not_cancelled->not_cancel_pending->all ) {
        if( $item->is_virtual_voucher) {
            return 1;
        }
    }

    return 0;
}

=head2 is_ip_address_in_whitelist

Returns true if the IP Address on the order is listed in the Fraud IP Address
List as whitelisted

=cut

sub is_ip_address_in_whitelist {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $listed = $schema->resultset('Fraud::IpAddressList')->search( {
        ip_address => $self->ip_address,
        status_id => $SECURITY_LIST_STATUS__WHITELIST,
    });

    return ( $listed && $listed->count > 0 ) ? 1 : 0;
}

=head2 is_ip_address_in_blacklist

Returns true if the IP Address on the order is listed in the Fraud IP Address
List as whitelisted

=cut

sub is_ip_address_in_blacklist {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $listed = $schema->resultset('Fraud::IpAddressList')->search( {
        ip_address => $self->ip_address,
        status_id => $SECURITY_LIST_STATUS__BLACKLIST,
    });

    return ( $listed && $listed->count > 0 ) ? 1 : 0;
}

=head2 is_ip_address_internal

Returns true if the IP Address on the order is listed in the Fraud IP Address
List as internal

=cut

sub is_ip_address_internal {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $listed = $schema->resultset('Fraud::IpAddressList')->search( {
        ip_address => $self->ip_address,
        status_id => $SECURITY_LIST_STATUS__INTERNAL,
    });

    return ( $listed && $listed->count > 0 ) ? 1 : 0;
}

sub _build_shipping_address {
    my $self = shift;

    my $shipment = $self->shipments->first;

    my $addr;
    my $address = $shipment->shipment_address;
    $addr->{'Name'}             = $address->first_name ." ". $address->last_name;
    $addr->{'Street Address'}   = $address->address_line_1 ." ". $address->address_line_2;
    $addr->{'Town/City'}        = $address->towncity;
    $addr->{'County/State'}     = $address->county;
    $addr->{'Postcode/Zipcode'} = $address->postcode;
    $addr->{'Country'}          = $address->country;

    return $addr;
}


sub _build_invoice_address {
    my $self = shift;

    my $addr;
    my $address =  $self->invoice_address;
    $addr->{'Name'}             = $address->first_name ." ". $address->last_name;
    $addr->{'Street Address'}   = $address->address_line_1 ." ". $address->address_line_2;
    $addr->{'Town/City'}        = $address->towncity;
    $addr->{'County/State'}     = $address->county;
    $addr->{'Postcode/Zipcode'} = $address->postcode;
    $addr->{'Country'}          = $address->country;

    return  $addr;

}

sub _build_hotlist_hash {
    my $self = shift;

    my $hotlist_hash;

    $hotlist_hash->{Customer} = {
        Email     => $self->customer->email,
        Telephone => $self->customer->get_first_defined_phone_number || '',
    };

    $hotlist_hash->{Payment}->{'Card Number'} = $self->payment_card_type;

    my $invoice_address = $self->_build_invoice_address();
    my $shipment_address = $self->_build_shipping_address();

    $hotlist_hash->{Address} = {
        'Name'              => $invoice_address->{Name}               . " " . $shipment_address->{Name},
        'Street Address'    => $invoice_address->{'Street Address'}   . " " . $shipment_address->{'Street Address'},
        'Town/City'         => $invoice_address->{'Town/City'}        . " " . $shipment_address->{'Town/City'},
        'County/State'      => $invoice_address->{'County/State'}     . " " . $shipment_address->{'County/State'},
        'Postcode/Zipcode'  => $invoice_address->{'Postcode/Zipcode'} . " " . $shipment_address->{'Postcode/Zipcode'},
        'Country'           => $invoice_address->{'Country'}          . " " . $shipment_address->{'Country'},
    };

    return $hotlist_hash;

}

=head2 is_in_hotlist

Returns True if in the Hotlist

=cut

sub is_in_hotlist {
    my ( $self, @check_for_fields ) = @_;

    my $hotlist_rs  = $self->result_source->schema->resultset('Public::HotlistValue');
    my $hotlist     = cache_and_call_method( $hotlist_rs, 'get_for_fraud_checking' );

    my $hotlist_hash = cache_and_call_method( $self, '_build_hotlist_hash' );

    foreach my $check ( @{ $hotlist } ) {
        my $value = $check->{'value'};
        my $field = $check->{'field'};
        my $type  = $check->{'type'};

        if ( $hotlist_hash->{$type}->{$field} =~ m/\b\Q$value\E/i ) {
            return 1        if ( !@check_for_fields || grep { $_ eq $field } @check_for_fields );
        }
    }

    return 0;
}

=head2 standard_shipment_address_matches_invoice_address

Returns True or False depending on whether the orders standard class shipment
address exactly matches the orders invoice address.

    my $addresses_match = $order
        ->standard_shipment_address_matches_invoice_address;

    print $addresses_match
        ? 'Addresses Match'
        : 'Addresses Do Not Match';

This is just a wrapper around has_same_address_as_billing_address on the
standard class shipment.

=cut

sub standard_shipment_address_matches_invoice_address {
    my $self = shift;

    return $self
        ->get_standard_class_shipment
        ->has_same_address_as_billing_address

}

=head2 clear_method_cache

This clears out all Methods that may have been cached so the next time
they are called they will get fresh data - which will then be cached.

=cut

sub clear_method_cache {
    stop_all_caching();
    return;
}

=head2 accept_or_hold_order_after_fraud_check

    $self->accept_or_hold_order_after_fraud_check( $ORDER_STATUS__CREDIT_HOLD or $ORDER_STATUS__ACCEPTED );

Will update the Order's Status to what was passed in, allowable Statuses are 'Credit Hold' or 'Accepted'
any other Status will throw an exception.

Will also Update all NON-Cancelled Shipments for the Order at the same time to reflect the Order Status.

This should ONLY be called when an Order has been Fraud Checked such as when it is Imported.

=cut

sub accept_or_hold_order_after_fraud_check {
    my ( $self, $status_id )    = @_;

    my @shipments           = $self->shipments->not_cancelled->all;
    my $operator_id         = $APPLICATION_OPERATOR_ID;
    my $order_isa_pre_order = $self->has_preorder;

    if ( $status_id == $ORDER_STATUS__CREDIT_HOLD ) {

        # Put Order on CREDIT HOLD
        $self->set_status_credit_hold( $operator_id );

        # Put Shipments on FINANCE HOLD
        foreach my $shipment ( @shipments ) {
            $shipment->set_status_finance_hold( $operator_id );
        }

    }
    elsif ( $status_id == $ORDER_STATUS__ACCEPTED ) {

        # ACCEPT Order
        $self->set_status_accepted( $operator_id );

        # Set Shipments to PROCESSING
        foreach my $shipment ( @shipments ) {
            my $set_to_processing;

            # Explicitly writing out conditions for clarity.
            if ( $order_isa_pre_order ) {
                $set_to_processing = 1;
            }
            elsif ( $shipment->is_on_ddu_hold ) {
                $set_to_processing = 0;
            }
            elsif ( $shipment->is_held ) {
                $set_to_processing = 0;
            }
            else {
                $set_to_processing = 1;
            }

            # set status without logging
            $shipment->set_status_processing( $operator_id, 1 ) if $set_to_processing;
        }

    }
    else {
        # shouldn't get here
        croak "Unexpected Order Status Id: '" . $status_id . "', "
              . "Can't Set Status for Order: " . $self->id . "/" . $self->order_nr
              . " found in '" . __PACKAGE__ . "::accept_or_hold_order_after_fraud_check'";
    }

    return;
}

=head2 get_app_source

Returns a hashref showing the order attributes for source_app_name and
source_app_version as follows:

{
    app_source_name => 'Something',
    app_source_version => '1.0'
}

Either value can be an empty string . If there is no name there cannot be a
version

=cut

sub get_app_source {
    my $self = shift;

    unless ( defined $self->order_attribute &&
             defined $self->order_attribute->discard_changes->source_app_name ) {
        return {
            app_source_name => '',
            app_source_version => ''
        };
    }

    # We assume that there will only be a single row containing the source_app
    # details.
    return {
        app_source_name => $self->order_attribute->source_app_name,
        app_source_version => ( $self->order_attribute->source_app_version // 0 )
                                ? $self->order_attribute->source_app_version : ''
    };
}

=head2 ip_address_used_before

    if ( $order->ip_address_used_before( {
        this_customer_only => 1,
        include_cancelled => 1,
        date_condition => 'now',
        count => 3,
        period => 'month'
    } );

Returns the count of any orders with the same IP address as the current
order, subject to any conditions passed in as parameters.

Parameters:

=over 4

=item this_customer_only

If defined will only match on orders for the same customer

=item cancelled_only

Limit the search to cancelled orders only.
You can only specify 1 of cancelled_only or include_cancelled.
If you specify both only the cancelled_only option is considered.

=item include_cancelled

Include cancelled and non-cancelled orders in the search. By default the search
will exclude cancelled orders.

=item include_current_order

If defined the current order will be included in the count of orders.
Otherwise the default is to exclude the current order.

=item date_condition

If defined limits the check to the specified date restrictions.

This can be set to either "now" or "order".

If set to "now" the count will include all matching orders up to the current
time. Optionally 2 further parameters may be specified to restrict the period
covered by the search by setting a maximum age. These are "period" and
"count" which are documented below.

If set to "order" the count will only include matching orders with a date
before the current order and you must pass in the "period" and "count"
parameters.

If neither date_condition option is specified the count will include all
orders matching the IP address prior to the current order with no limit
on the age of included orders.

=item period and count

If you wish to set a maximum age for orders to consider when specifying a
date_condition parameter you should do so by specifying the period and count
parameters. These set the time period to use, which must be one of second,
minute, hour, day, week, month or year. The "count" parameter sets the number
of time units specified in the "period" to use when determining the maximum
age of orders to be considered.

=back

=cut

sub ip_address_used_before {
    my ( $self, $args ) = @_;

    return unless defined $self->ip_address;

    my $schema = $self->result_source->schema;
    my $dtf    = $schema->storage->datetime_parser;

    my $query = {
        -or => [
            ip_address => $self->ip_address,
            ip_address => { like => $self->ip_address . ',%' },
        ],
    };

    if ( defined $args->{this_customer_only} ) {
        $query->{customer_id} = $self->customer_id;
    }

    # Provide a way to search only cancelled orders or to include/exclude
    # cancelled orders in a search of all orders

    if ( defined $args->{cancelled_only} ) {
        $query->{'order_status_id'} = { '=' => $ORDER_STATUS__CANCELLED };
    }
    elsif ( ! defined $args->{include_cancelled} ) {
        $query->{'order_status_id'} = { '!=' => $ORDER_STATUS__CANCELLED };
    }

    unless ( defined $args->{include_current_order} ) {
        $query->{id} = { '!=' => $self->id };
    }

    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $args->{date_condition} // '' ) {
            when ( /\Anow\z/i ) {
                $query->{date} = { '<=' => $dtf->format_datetime(DateTime->now()) };

                if ( defined $args->{count} && defined $args->{period} ) {
                    $query->{'age(date)'} = { '<=' => $args->{count}." ".$args->{period} };
                }
            }
            when ( /\Aorder\z/i ) {
                die "You must pass in count and period parameters" unless
                    defined $args->{count} && defined $args->{period};

                # DBIC differs from SQL - needs an s appended to time units
                my $period = $args->{period}.'s';

                my $start_date = $self->date->clone->subtract( $period => $args->{count} );

                $query->{date} = {
                    -between => [
                        $dtf->format_datetime( $start_date ),
                        $dtf->format_datetime( $self->date )
                    ]
                };
            }
            default {
                $query->{date} = { '<=' => $dtf->format_datetime( $self->date ) };
            }
        }
    }

    return $self->result_source->resultset->search( $query )->count;
}

=head2 is_paid_using_credit_card

    $boolean = $self->is_paid_using_credit_card;

Returns TRUE or FALSE depending on whether the Order was paid in
part or in full using a Credit Card.

=cut

sub is_paid_using_credit_card {
    my $self    = shift;

    my $payment = $self->payments->first;
    return 0    if ( !$payment );

    return ( $payment->method_is_credit_card ? 1 : 0 );
}

=head2 is_paid_using_third_party_psp

    $boolean = $self->test_is_paid_using_the_third_party_psp;

Will return TRUE or FALSE depending on whether all or part of the Order
was paid with using a Third Party PSP Payment Method.

=cut

sub is_paid_using_third_party_psp {
    my $self    = shift;

    my $payment_method = $self->get_third_party_payment_method;
    return ( $payment_method ? 1 : 0 );
}

=head2 is_paid_using_the_third_party_psp

    $boolean = $self->is_paid_using_the_third_party_psp( 'PayPal' );

Will return TRUE or FALSE depending on whether the Third Party
Payment Method used matches the argument passed in. If no Third
Party used then will return FALSE.

=cut

sub is_paid_using_the_third_party_psp {
    my ( $self, $wanted ) = @_;

    $wanted //= '';

    my $payment_method = $self->get_third_party_payment_method;
    return 0            if ( !$payment_method );

    return ( $payment_method->payment_method eq $wanted ? 1 : 0 );
}

=head2 get_third_party_payment_method

    $orders_payment_method_rec = $self->get_third_party_payment_method;

Will return the Third Party Payment Method used to pay for some or
all of the Order. If no Third Party was used then returns 'undef'.

=cut

sub get_third_party_payment_method {
    my $self    = shift;

    my $payment = $self->payments->first;
    return      if ( !$payment );
    return      if ( !$payment->method_is_third_party );

    return $payment->payment_method;
}

=head2 get_payment_status

Will return the current payment status for the order as given by the PSP.

Returns 'undef' if payment was not via a Third Party PSP.

=cut

sub get_current_payment_status {
    my $self = shift;

    return '' unless $self->is_paid_using_third_party_psp;

    my $psp_info = $self->get_psp_info;

    return $psp_info->{current_payment_status};
}

=head2 contains_sale_shipment

Returns true if the standard class shipment for the order contains
any items that were on sale at the time the order was taken.

=cut

sub contains_sale_shipment {
    my $self = shift;

    my $shipment    = $self->get_standard_class_shipment;

    return $shipment->contains_on_sale_items;
}

=head2 order_total_matches_tender_total

Returns TRUE, if the total value of the order (as determined by the
C<get_total_value> method) matches the total value of all the tenders
associated with the order and FALSE otherwise.

=cut

sub order_total_matches_tender_total {
    my $self = shift;

    my $order_total     = $self->get_total_value;
    my $tender_total    = $self->tenders->get_column('value')->sum // 0;

    return $order_total == $tender_total;

}

=head2 order_total_does_not_match_tender_total

Returns TRUE, if the total value of the order (as determined by the
C<get_total_value> method) DOES NOT match the total value of all the tenders
associated with the order and FALSE otherwise.

This is a convenience method for the inverse of the
C<order_total_matches_tender_total> method.

=cut

sub order_total_does_not_match_tender_total {
    my $self = shift;

    return ! $self->order_total_matches_tender_total;

}

=head2 order_currency_matches_psp_currency

Returns TRUE, if the currency of the order matches the currency we get from psp
for the same order and FALSE otherwise.

=cut

sub order_currency_matches_psp_currency {
    my $self = shift;

    my $order_currency     = $self->currency->currency;
    my $psp_currency       = $self->payment_card_currency;

    return lc($order_currency) eq lc($psp_currency);

}

=head2 is_signature_required_for_standard_class_shipment

Returns TRUE, if the 'signature_required' flag  on standard class shipment
is set to TRUE else returns FALSE.

=cut

sub is_signature_required_for_standard_class_shipment {
    my $self = shift;

    my $shipment =  $self->get_standard_class_shipment;

    return $shipment->is_signature_required();
}


=head2 is_signature_not_required_for_standard_class_shipment

Returns TRUE, if the 'signature_required' flag  on standard class shipment
is set to FALSE else returns TRUE

=cut

sub is_signature_not_required_for_standard_class_shipment {
    my $self = shift;

    return  !($self->is_signature_required_for_standard_class_shipment);

}

=head2 payment_method_allows_editing_of_billing_address

    $boolean = $self->payment_method_allows_editing_of_billing_address();

Returns TRUE if the Payment Method used to pay for the Order allows for
the Billing Address to be edited. This will be derived by going to the
'orders.payment' record for the Order and then getting the Method used
and checking against the 'orders.payment_method' table.

If paid using only Store Credit and/or Gift Vouchers then this method
will return TRUE.

=cut

sub payment_method_allows_editing_of_billing_address {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return TRUE
    return 1        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        # use 'billing_and_shipping_address_always_the_same' to infer that you can't
        # edit Billing Address if the Address needs to be the same as Shipping
        $payment_method->billing_and_shipping_address_always_the_same
        ? 0     # can't edit
        : 1     # can edit
    );
}

=head2 payment_method_insists_billing_and_shipping_address_always_the_same

    $boolean = $self->payment_method_insists_billing_and_shipping_address_always_the_same();

Returns TRUE or FLASE based on whether the Method of Payment requires
the Billing & Shipping Addresses to always be the same.

If the Order was paid entirely by Store Credit and/or Gift Vouchers
then this method will return FALSE.

=cut

sub payment_method_insists_billing_and_shipping_address_always_the_same {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return FALSE
    return 0        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->billing_and_shipping_address_always_the_same
        ? 1
        : 0
    );
}

=head2 payment_method_requires_basket_updates

    $boolean = $self->payment_method_requires_basket_updates();

Returns TRUE or FALSE based on whether the Method of Payment requires that
the PSP be kept up to date with Basket changes, such as Cancelling Items.

If the Order was paid entirely by Store Credit and/or Gift Vouchers
then this method will return FALSE.

=cut

sub payment_method_requires_basket_updates {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return FALSE
    return 0        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->notify_psp_of_basket_change
        ? 1
        : 0
    );
}

=head2 payment_method_allows_full_refund_using_only_store_credit

    $boolean = $self->payment_method_allows_full_refund_using_only_store_credit();

Returns TRUE or FALSE based on whether the Method of Payment allows a Full
Refund for the Order to be done using only Store Credit.

Some times Customer Care want to Refund the entire amount of an Order using only
Store Credit, this method will determine whether the Payment Method allows this.

If the Order was paid entirely by Store Credit and/or Gift Vouchers
then this method will return TRUE.

=cut

sub payment_method_allows_full_refund_using_only_store_credit {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return TRUE
    return 1        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->allow_full_refund_using_only_store_credit
        ? 1
        : 0
    );
}

=head2 payment_method_allows_full_refund_using_only_the_payment

    $boolean = $self->payment_method_allows_full_refund_using_only_the_payment();

Returns TRUE or FALSE based on whether the Method of Payment allows a Full
Refund for the Order to be done using only the Payment.

Some times Customer Care want to Refund the entire amount of an Order using only
the Payment used such as to Credit Card, this method will determine whether the
Payment Method allows this.

If the Order was paid entirely by Store Credit and/or Gift Vouchers
then this method will return TRUE.

=cut

sub payment_method_allows_full_refund_using_only_the_payment {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit and/or Gift Vouchers so
    # return TRUE, this might seem odd but this is how it has always
    # been done however odd that might seem
    return 1        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->allow_full_refund_using_only_payment
        ? 1
        : 0
    );
}

=head2 payment_method_allow_editing_of_shipping_address_post_settlement

    $boolean = $self->payment_method_allow_editing_of_shipping_address_post_settlement

Returns TRUE if the Payment Method used to pay for the Order allows for
the Shipping Address to be edited after Settlement. This will be derived by going to the
'orders.payment' record for the Order and then getting the Method used
and checking against the 'orders.payment_method' table.

If paid using only Store Credit and/or Gift Vouchers then this method
will return TRUE

=cut

sub payment_method_allow_editing_of_shipping_address_post_settlement {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return TRUE
    return 1 if (!$payment);

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->allow_editing_of_shipping_address_after_settlement
        ? 1
        : 0
    );
}

=head2 is_staff_order() : Bool

Determine if the order was made by a member of staff.

=cut

sub is_staff_order { return $_[0]->customer->is_category_staff; }

=head2 payment_method_allows_pure_goodwill_refunds

    $boolean = $self->payment_method_allows_pure_goodwill_refunds

Returns TRUE if the Payment Method allows the creation of Refund Invoices
with a pure Goodwill Refund amount. This will be derived by going to the
'orders.payment' record for the Order and then getting the Method used
and checking against the 'orders.payment_method' table.

If paid using only Store Credit and/or Gift Vouchers then this method
will return TRUE

=cut

sub payment_method_allows_pure_goodwill_refunds {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return TRUE
    return 1    if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->allow_goodwill_refund_using_payment
        ? 1
        : 0
    );
}

=head2 payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used

    $boolean = $self->payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used;

Returns TRUE or FALSE based on whether the Method of Payment requires that the
Payment be Cancelled after a Forced Shipping Address change which is done on the
Edit Shipping Address page. This is when the Payment Provider rejects the Address
but the Customer insists and we have to accept the Address.

If the Order was paid entirely by Store Credit and/or Gift Vouchers
then this method will return FALSE.

=cut

sub payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used {
    my $self = shift;

    my $payment = $self->payments->first;
    # no payment then paid by Store Credit
    # and/or Gift Vouchers so return FALSE
    return 0        if ( !$payment );

    my $payment_method = $payment->payment_method;
    return (
        $payment_method->cancel_payment_after_force_address_update
        ? 1
        : 0
    );
}

=head2 get_log_replaced_payment_preauth_cancellation

    my $log_rs = $self->get_log_replaced_payment_preauth_cancellation;

Returns resultset containing rows of 'log_replaced_payment_preauth_cancellation' table
for related 'orders.replaced_payment' record for a given order ordered by ID.

=cut

sub get_log_replaced_payment_preauth_cancellation {
    my $self = shift;

    return $self->replaced_payments
                ->search_related(
                    'log_replaced_payment_preauth_cancellations',
                    { },
                    { order_by => 'id' }
                );

}

1;
