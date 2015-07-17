package XT::Order::Role::Parser::NAPGroup::PromotionData;
use NAP::policy "tt", 'role';

requires 'as_list';

no Moose;

# a lot of the following code was copied/adapted from:
# XT/Order/Parser/PublicWebsiteXML.pm

sub _get_promotion_data {
    my ($self, $baskets, $lines) = @_;
    my $promotion_data;

    # listify the baskets and lines
    $baskets = $self->as_list($baskets);
    $lines   = $self->as_list($lines);

    # process promotion basket items
    foreach my $basket (@$baskets) {
        if ( !$self->_promo_types()->{ $basket->{type} } ) {
            # FIXME exception
            die "PROMO: Unknown promotion type: $basket->{type}";
        }

        my $promo_rec = $self->_build_promo_record($basket);
        $self->_process_free_shipping( $promo_rec );

        $promotion_data->{promotion_basket}{ $basket->{pb_id} } = $promo_rec;
    }

    # process promotion line items
    foreach my $line (@{$lines}) {
        # collect promo data and validate
        my $promotion_detail_id = $line->{pl_id};
        my $type                = $line->{type};
        my $description         = $line->{description};
        my $value               = $line->{value}{amount} // 0;

        # validate promo type
        if ( !$self->_promo_types()->{ $line->{type} } ) {
            # FIXME exception
            die "PROMO: Unknown promotion type: $type";
        }

        # start processing the promo data
        $promotion_data->{$promotion_detail_id} = {
            type        => $type,
            class       => $self->_promo_types()->{ $line->{type} },
            description => $description,
            value       => $value,
        };

        # this is a 'reimplementation' of a fix first seen in:
        #   https://gitosis/cgit/p.richmond/commit/?id=990ec8498ba20f580ccb30170b1f2d6e2c80afdd
        foreach my $line_id ( @{$line->{order_line_id}} ) {
            $promotion_data->{$promotion_detail_id}{items}{$line_id} = 1;
        }
    }

    # _get_line_items() requires a hash (until we can make it behave more
    # sensibly!)
    return $promotion_data // {};
}

sub _promo_types {
    # SECTION: PROMOTIONS
    # expected promotion types - must match one of these
    return {
        'free_shipping'         => 'Free Shipping',
        'percentage_discount'   => 'Percentage Off',
        'FS_GOING_GOING_GONE'   => 'Reverse Auction',
        'FS_PUBLIC_SALE'        => 'Public Sale',
            # this was Percentage Off but it was impacting
            # NAP evenmotions
    };
}

sub _build_promo_record {
    my ($self, $basket) = @_;
    my $promo_rec = {
        type                => $basket->{type},
        value               => $basket->{value}{amount} // 0,
        description         => $basket->{description},
        class               => $self->_promo_types()->{ $basket->{type} },
        shipping            => 0,
        promotion_discount  => 0,
    };
}

sub _process_free_shipping {
    my ($self, $promo_rec) = @_;
    if ( $promo_rec->{class} eq 'Free Shipping' ) {
        $promo_rec->{shipping} = $promo_rec->{value};
    }
}

__END__
