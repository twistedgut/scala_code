package XTracker::Promotion::Pack;

use strict;
use warnings;

use Data::Dump qw/ pp /;
use Carp qw/ confess /;
use XTracker::Logfile qw(xt_logger);
my $logger = xt_logger(__PACKAGE__);

use XTracker::Config::Local qw/ sys_config_var /;
use XTracker::Database qw/ get_schema_and_ro_dbh /;
use XTracker::Database::Order qw/ create_order_promotion /;
use XTracker::Config::Local;
use XTracker::Schema::Result::Public::Orders;

=head1 NAME

XTracker::Schema::Result::Public::Orders

=head1 DESCRIPTION

Methods to check and/or apply relevant promotion packs to orders

=head1 METHODS

=head2 check_promotions

Checks what promotions are currently running and calls the related private
subroutine to see whether the promotion applies to this order.

Returns 1 on success or undef on failure.

Requires a result set object containing an order, else it will die.

=cut

sub check_promotions {
    my ( $self, $schema, $order, $plugin ) = @_;

    confess "No \$order provided" unless $order;

    # get the Customer's Preferred Language
    my $cpl = $order->customer->get_language_preference;

    if ( $order->channel->has_welcome_pack( $cpl->{language}->code ) ) {
        $plugin->call( 'apply_welcome_pack', $order )   if ( defined $plugin );
    }
    my $do_este_lauder
        = sys_config_var($schema, 'Promotions', 'Este Lauder');
    if ( $do_este_lauder and $do_este_lauder eq 'On') {
        $self->_apply_este_lauder_promotion( $schema, $order );
    }

    $plugin->call('promotion_modifier',$order) if (defined $plugin);

}


=head2 _apply_este_lauder_promotion

Apply the Este Lauder promotion if:

- the order is placed from the AM site
- the customer hasn't had the promotion before
- the order does not only contain vouchers

=cut

sub _apply_este_lauder_promotion {
    my ( $self, $schema, $rs_order ) = @_;

    my $customer_id = $rs_order->customer_id;

    # Make sure the order is AM
    return unless config_var('DistributionCentre','name') eq 'DC2';

    # Make sure the order is in NAP
    return unless $rs_order->channel->business->config_section eq "NAP";

    my $promo_type_id = $schema->resultset('Public::PromotionType')
                        ->search( { name => 'Este Lauder Brochure' } )
                        ->first
                        ->id;
    return unless not
        $self->_had_promotion_before( $schema, $promo_type_id, $customer_id );

    return unless not $self->_voucher_only_order( $rs_order );

    $promo_type_id = $schema->resultset('Public::PromotionType')
                        ->search( { name => 'Este Lauder Brochure' } )
                        ->first
                        ->id;

    create_order_promotion(
        $schema->storage->dbh, $rs_order->id, $promo_type_id, 0, 'none'
    );


    return 1;

}

=head2 _had_promotion_before

Check if a customer has ever had a specified promotion
applied to any order before.

Requires a schema object, a Public::PromotionType id and a Public::Customer id.

=cut

sub _had_promotion_before {
    my ( $self, $schema, $promo_type_id, $customer_id ) = @_;

    $logger->debug('Entered _had_promotion_before');
    $logger->debug('Passed in values:');
    $logger->debug('$promo_type_id = ' . $promo_type_id);
    $logger->debug('$customer_id = ' . $customer_id);

    my $orders_rs = $schema->resultset('Public::Orders')
                    ->search( { customer_id => $customer_id } );

    while (my $order = $orders_rs->next) {
        $logger->debug('$order->id = ' . $order->id);
        my $promotion_rs = $order->order_promotions;
        while (my $promotion = $promotion_rs->next) {
            $logger->debug('$promotion->promotion_type_id = '
                . $promotion->promotion_type_id);
            if ( $promotion->promotion_type_id == $promo_type_id ) {
                $logger->debug('Customer has had promotion before');
                return 1;
            }
        }
    }
    return 0;
}

=head2 _voucher_only_order

Check if an order only contains voucher products.

=cut

sub _voucher_only_order {
    my ( $self, $rs_order ) = @_;

    return XTracker::Schema::Result::Public::Orders->voucher_only_order( $rs_order );
}

1;
