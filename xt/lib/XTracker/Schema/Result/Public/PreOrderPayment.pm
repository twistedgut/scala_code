use utf8;
package XTracker::Schema::Result::Public::PreOrderPayment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_payment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_payment_id_seq",
  },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "preauth_ref",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "settle_ref",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "psp_ref",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fulfilled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "valid",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("pre_order_payment_pre_order_id_unique", ["pre_order_id"]);
__PACKAGE__->add_unique_constraint("pre_order_payment_preauth_ref_key", ["preauth_ref"]);
__PACKAGE__->add_unique_constraint("pre_order_payment_psp_ref_key", ["psp_ref"]);
__PACKAGE__->add_unique_constraint("pre_order_payment_settle_ref_key", ["settle_ref"]);
__PACKAGE__->belongs_to(
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eX6EbFVN6zsRipCIRJUInA

=head1 NAME

XTracker::Schema::Result::Public::PreOrderPayment

=head1 DESCRIPTION

Schema file for the public.pre_order_payment table.

=cut

use Carp;

use XTracker::Constants                     qw( :psp_default);

use XTracker::Database::OrderPayment        qw( refund_to_psp );
use XTracker::Logfile                       qw( xt_logger );

=head1 METHODS

=head2 psp_refund_the_amount

    $self->psp_refund_the_amount( $amount_to_refund );

This will call a function to refund an Amount back to the Customer's Card via the PSP.

=cut

sub psp_refund_the_amount {
    my ( $self, $amount )   = @_;

    # nothing to Refund so don't try
    return 0        if ( !$amount );

    if ( $amount <= 0 ) {
        xt_logger->warn("PreOrder Id: ".$self->pre_order->id. " is trying to create refund with invalid amount");
        croak "PreOrder Id: ".$self->pre_order->id. " is trying to create refund with invalid amount";
    }

    my $result  = refund_to_psp( {
                            amount          => $amount,
                            channel         => $self->pre_order->customer->channel,
                            settlement_ref  => $self->settle_ref,
                            id_for_err_msg  => $self->pre_order_id,
                            label_for_id    => 'Pre Order Id',
                        } );

    if ( !$result->{success} ) {
        # Failed to Refund to the PSP so throw
        # an Exception with the Error Message
        croak $result->{error_msg};
    }

    # everything's ok
    return 1;
}

=head2 payment_method_rec

    $orders_payment_method_rec = $self->payment_method_rec();

For Pre-Orders the Payment Method will always be Card.

=cut

sub payment_method_rec {
    my $self    = shift;

    my $schema  = $self->result_source->schema;

    return $schema->resultset('Orders::PaymentMethod')
                            ->find( {
        payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
    } );
}

use Moose;
with 'XTracker::Schema::Role::Result::PaymentService';

1;
