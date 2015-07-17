package XT::Order::Role::Parser::IntegrationServiceJSON::PromotionData;
use NAP::policy "tt", 'role';

sub _get_promotion_data {
    my($self,$baskets,$lines) = @_;
    my $promotion_data = {};

    # listify the baskets and lines
    $baskets = $self->as_list($baskets);
    $lines   = $self->as_list($lines);

    # SECTION: PROMOTIONS
    # expected promotion types - must match one of these
    my %promo_type = (
        'free_shipping'         => 'Free Shipping',
        'percentage_discount'   => 'Percentage Off',
        'FS_GOING_GOING_GONE'   => 'Reverse Auction',
        'FS_PUBLIC_SALE'        => 'Public Sale',
            # this was Percentage Off but it was impacting
            # NAP evenmotions
    );

    if (defined $baskets) {
        foreach my $promotion (@{$baskets}) {
            my $promo_id = $promotion->{pb_id};
            my $promo_rec = {
                type => $promotion->{type} || undef,
                description => $promotion->{description},
                shipping => 0,
                promotion_discount => 0,
            };

            # FIXME execption
            die "PROMO: Unknown promotion type: $promo_rec->{type}\n"
                if (!$promo_rec->{type});
            $promo_rec->{class} = $promo_type{ $promo_rec->{type} },

            my $value = $promotion->{value}->{amount} || 0;

            # free shipping
            if ( $promo_rec->{class} eq 'Free Shipping' ) {
                $promo_rec->{shipping} = $value;
            }

            $promotion_data->{'promotion_basket'}{$promo_id} = $promo_rec;
        }
    }

    # process the line
    # FIXME: Should be a foreach loop??
    if (defined $lines) {
        foreach my $line (@{$lines}) {
            # collect promo data and validate
            my $promotion_detail_id = $line->{pl_id};
            my $type                = $line->{type};
            my $description         = $line->{description};
            my $value               = $line->{value}->{amount} || 0;
            # validate promo type
            if ( !$promo_type{ $type } ) {
                # FIXME exception
                die "PROMO: Unknown promotion type: $type";
            }

            # FIXME this just gets overwritten anyway....
            # get items discount applies to
            #foreach my $orderline ($promotion->findnodes('ORDER_LINE_ID')) {
                #my $line_id = $orderline->hasChildNodes ? $orderline->getFirstChild->getData : "";
                #$promotion_data->{$promotion_detail_id}{items}{$line_id} = 1;
            #}

            # start processing the promo data
            $promotion_data->{$promotion_detail_id}{type}           = $type;
            $promotion_data->{$promotion_detail_id}{class}          = $promo_type{ $type };
            $promotion_data->{$promotion_detail_id}{description}    = $description;

            # percentage discount
            # Reverse auction and percentage discount - value already off
            # unit price so only need to work out value off each component
            # of product cost (unit price, tax and duty)
            #if ( $promo_type{ $type } =~ m{^(?:Reverse Auction|Percentage Off|Public Sale)$} ) {

                ## first loop over items to get their full price value
                #my $item_total = 0;

                #foreach my $shipment ($node->findnodes('DELIVERY_DETAILS')) {
                    #foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                        ## only include if item has promo applied
                        #if ( $promotion_data->{$promotion_detail_id}{items}{$item->findvalue('@OL_ID')} ){
                            #$item_total += ( $item->findvalue('UNIT_NET_PRICE/VALUE')
                                    #+ $item->findvalue('TAX/VALUE')
                                    #+ $item->findvalue('DUTIES/VALUE') )
                                #* $item->findvalue('@QUANTITY');

                        #}
                    #}
                #}

                #now calculate the value of promotion as a percentage of item cost to work out split discount
                #$promotion_data->{$promotion_detail_id}{percentage_removed} = sprintf( "%.2f", ($value / $item_total) );

                #second loop over order items to work out discount value per item
                #foreach my $shipment ($order->findnodes('DELIVERY_DETAILS')) {
                    #foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                        #my $ol_id = $item->findvalue('@OL_ID');
                        #only include if item has promo applied
                        #if ( $promotion_data->{$promotion_detail_id}{items}{$ol_id} ){

                            #Going going gone sale items on DC2 are not returnable
                            #$promotion_data->{$promotion_detail_id}{returnable}{$ol_id} =
                              #! (($promo_type{ $type } eq 'Reverse Auction'
                                    #|| $promo_type{ $type } eq 'Public Sale')
                              #&& $DC eq 'DC2' );


                            #if (! $promotion_data->{$promotion_detail_id}{returnable}{$ol_id}) {
                              #$logger->info("GGG/PUBLICSALE: Item $ol_id is not returnable");
                            #}

                            #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{unit_price}
                                #= $item->findvalue('UNIT_NET_PRICE/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                            #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{tax}
                                #= $item->findvalue('TAX/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                            #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{duty}
                                #= $item->findvalue('DUTIES/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                        #}
                    #}
                #}
            }

            #$logger->info("ITEM PROMO: $description ($promotion_detail_id)");
            #$logger->info("TYPE: $type");
            #$logger->info("VALUE: $value");
            #if ( $promotion_data->{$promotion_detail_id}{percentage_discount} ) {
                #$logger->info("PERC DISCOUNT: $promotion_data->{$promotion_detail_id}{percentage_discount}");
                #$logger->info("ITEMS:");
                #foreach my $item_id ( keys %{$promotion_data->{$promotion_detail_id}{items}} ) {
                    #$logger->info("$item_id - $promotion_data->{$promotion_detail_id}{items}{$item_id} subtracted");
                 #}
            #}
            #$logger->info("\n----END PROMO----\n");
        #}
    }

    return $promotion_data;

}
