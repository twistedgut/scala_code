package XTracker::Promotion::Marketing;

use NAP::policy "tt", 'class';

# CANDO-880: Marketing Promotion - In the box
# Please note "Marketing promotion" is separate from other promotions and has nothing do to with
#  order_promotions tables. Marketing promotion is attached to order at packing level
#  rather than at order import level.

has 'schema' => (
    is => 'ro',
    required => 1,
);

has 'order' => (
    is => 'ro',
    isa  => 'XTracker::Schema::Result::Public::Orders',
    lazy_build => 1,
);

has 'order_id' => (
    is => 'ro',
    isa => 'Int',
    default => sub{return $_[0]->order->id},
);


sub _build_order {
    my $self    = shift;
    return $self->schema->resultset('Public::Orders')->find($self->order_id);
}

sub apply_to_order {
    my $self  = shift;


    my $promotion_rs = $self->schema->resultset('Public::MarketingPromotion');
    $promotion_rs = $promotion_rs->get_active_promotions_by_channel($self->order->channel_id);

  PROMOTION:
    while ( my $promotion = $promotion_rs->next ) {

        # if order currently has this promotion, then skip
        next PROMOTION if( $self->order->has_marketing_promotion($promotion) );

        # if promotion is once per customer
        if($promotion->is_sent_once ) {
            next PROMOTION if( $self->_count_of_promotion_before( $promotion->id) );
        }

        if ( $self->check_promotion_applicable( $promotion ) ) {
            # attach the promotion to order
            my $link_rs;
            try {
                $link_rs = $self->order->create_related('link_orders__marketing_promotions',{
                    marketing_promotion_id => $promotion->id,
                });
            }
            catch {
                die("error". $_);
            };
        }
    }

    return;

}


sub check_promotion_applicable {
    my ( $self, $promotion )    = @_;

    # list of Options that the Promotion might have and are
    # checked against the Order to see if they are applicable
    my @options_to_check = ( qw(
        designers
        customer_segment
        countries
        languages
        product_types
        gender_titles
        customer_categories
    ) );

    foreach my $option ( @options_to_check ) {
        my $has_option_assigned             = "has_${option}_assigned";
        my $can_option_be_applied_to_order  = "can_${option}_be_applied_to_order";

        # if an Option is assigned to the Promotion
        if ( $promotion->$has_option_assigned ) {
            if ( !$promotion->$can_option_be_applied_to_order( $self->order ) ) {
                # if returned FALSE then no point in continuing
                # the Promotion can't be applied to the Order
                return 0;
            }
        }
    }

    return 1;
}


sub _count_of_promotion_before {
    my ( $self, $promotion_id ) = @_;

    my $customer_id = $self->order->customer_id;

    my $orders_rs = $self->schema->resultset('Public::Orders');

    #$self->schema->storage->debug(1);
    my $rows = $orders_rs->search(
        { 'me.customer_id'                                          => $customer_id,
          'link_orders__marketing_promotions.marketing_promotion_id' => $promotion_id,
        },
        { join      => 'link_orders__marketing_promotions',
         '+select'  => 'link_orders__marketing_promotions.marketing_promotion_id',
         '+as'      => 'marketing_promotion_id',
        })->count;


    return $rows;
}

1;
