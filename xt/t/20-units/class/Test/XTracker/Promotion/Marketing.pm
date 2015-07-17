package Test::XTracker::Promotion::Marketing;

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

=head1 Test::XTracker::Promotion::Marketing

Testing the 'XTracker::Promotion::Marketing' Class.

=cut
use Test::XTracker::RunCondition
    dc       => [ qw( DC1 DC2 ) ];



use Test::XTracker::Data;
use Test::XTracker::Data::MarketingPromotion;
use Test::XTracker::Data::MarketingCustomerSegment;
use Test::XTracker::Data::Designer;

use XTracker::Promotion::Marketing;
use XTracker::Constants::FromDB     qw( :country );

use DateTime;
use DateTime::Duration;


sub create_data : Test( startup => no_plan ) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;

    # Start a transaction, so we can rollback after testing
    $self->{schema}->txn_begin;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $order = _create_order($channel,$pids);
    $self->{order} = @$order[0];
    $self->{customer}= $self->{order}->customer;
    $self->{channel} = $channel;
    $self->{pids} = $pids;
    $self->{marketing_promotion_rs} = $self->{schema}->resultset('Public::MarketingPromotion');

    # create Marketing Promotion
    my $promotion = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion({channel_id => $channel->id});
    $self->{promotion} = @$promotion[0];
};


sub instantiate : Test(setup) {
    my $self = shift;

    # disable any existing Promotions
    $self->{marketing_promotion_rs}->update( { enabled => 0 } );

    $self->{marketing_promotion} = XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order  => $self->{order},
    });
}

sub destroy : Test(teardown) {
    my $self = shift;

    $self->{marketing_promotion} = undef;
}

sub rollback : Test(shutdown) {
    my $self = shift;

    $self->{schema}->txn_rollback;
}


=head1 TESTS

=head2 instantiate_marketing_promotion_class

Tests the 'XTracker::Promotion::Marketing' Class can be instantiated correctly.

=cut

sub instantiate_marketing_promotion_class : Tests() {
    my $self = shift;

    lives_ok { XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order  => $self->{order},
         });
    } '_instantiate_marketing_promotion_class : instantiated with order object';


    lives_ok {  XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order_id  => $self->{order}->id
         });
    } '_instantiate_marketing_promotion_class : instantiated with order id';

}

=head2 count_of_promotion_before

Tests the '_count_of_promotion_before' method on the 'XTracker::Promotion::Marketing' Class.

=cut

sub count_of_promotion_before : Tests() {
    my $self = shift;

    my $expected = {
        count_before_linking => 0,
        count_after_linking  => 1,
        count_after_creation => 4,
    };

    my $got ={};

    #delete all promotions for this customer if exists
    Test::XTracker::Data::MarketingPromotion->delete_all_link_promotions($self->{order});

    lives_ok { $self->{marketing_promotion}->_count_of_promotion_before($self->{promotion}->id) } '_count_of_promotions_before : instantitated correctly';

    $got->{count_before_linking} = $self->{marketing_promotion}->_count_of_promotion_before($self->{promotion}->id);

    #create a link between order and promotion
    Test::XTracker::Data::MarketingPromotion->create_link($self->{order},$self->{promotion});
    $got->{count_after_linking} = $self->{marketing_promotion}->_count_of_promotion_before($self->{promotion}->id);

    # create 3 more orders for same customer and attach promotion to it
    my $orders = _create_order( $self->{channel}, $self->{pids}, 3, {
        customer => $self->{order}->customer,
    } );
    Test::XTracker::Data::MarketingPromotion->create_link($orders->[0],$self->{promotion});
    Test::XTracker::Data::MarketingPromotion->create_link($orders->[1],$self->{promotion});
    Test::XTracker::Data::MarketingPromotion->create_link($orders->[2],$self->{promotion});
    $got->{count_after_creation} = $self->{marketing_promotion}->_count_of_promotion_before($self->{promotion}->id);

    is_deeply($got, $expected, '_count_of_promotions_before : Count is as expected');
}

=head2 apply_to_order

Tests the 'apply_to_order' method that links an Order with a Promotion.

=cut

sub apply_to_order : Tests() {
    my $self = shift;

    my $expected = {
        first_order_with_flag_set    => 1,
        second_order_with_flag_set   => 0,
        second_order_with_flag_unset => 1,
        expired_promotion            => 0,
    };

    my $got = {};
    #delete all promotions for this customer if exists
    Test::XTracker::Data::MarketingPromotion->delete_all_link_promotions($self->{order});

    #create promotion with send_once_flag =1
    my $promotion = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion({channel_id => $self->{channel}->id});
    #create 3 orders for same customer
    my $orders = _create_order($self->{channel},$self->{pids},3);

    # call apply _to_order for first order - check it attaches the order to promotion
    my $mp_obj = XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order  => @$orders[0],
    });
    $mp_obj->apply_to_order();

    $got->{first_order_with_flag_set} =  @$orders[0]->search_related('link_orders__marketing_promotions', {
        marketing_promotion_id => @$promotion[0]->id,
    })->count;


    #call second order for same promotion check it does not attaches it
    $mp_obj = XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order_id  => @$orders[1]->id,
    });
    $mp_obj->apply_to_order();

    $got->{second_order_with_flag_set} = @$orders[1]->search_related('link_orders__marketing_promotions', {
        marketing_promotion_id => @$promotion[0]->id,
    })->count;


    #update promotion to have sent_once_flag=0
    @$promotion[0]->update({ is_sent_once => 'false' });
    $mp_obj->apply_to_order();

    $got->{second_order_with_flag_unset} = @$orders[1]->search_related('link_orders__marketing_promotions', {
        marketing_promotion_id => @$promotion[0]->id,
    })->count;


    # update the promotion end_date to be yesterday
    my $now = DateTime->now( time_zone => 'local' );
    my $yesterday = $now - DateTime::Duration->new( days => 1 );
    @$promotion[0]->update({ end_date => $yesterday });
    $mp_obj = XTracker::Promotion::Marketing->new({
        schema => $self->{schema},
        order_id  => @$orders[2]->id,
    });
    $mp_obj->apply_to_order();

    $got->{expired_promotion} = @$orders[2]->search_related('link_orders__marketing_promotions', {
        marketing_promotion_id => @$promotion[0]->id,
    })->count;

    is_deeply($got, $expected, '_apply_to_order : attached promotions corectly');

}

=head2 apply_to_orders_for_customer_segment

Tests that Orders with the right Customers get linked to a Promotion
that has Customer Segements assigned to it.

=cut

sub apply_to_orders_for_customer_segment : Tests() {
    my $self = shift;

    #create 2 customers
    my $customers = Test::XTracker::Data::MarketingCustomerSegment->grab_customers({
        how_many    => 2,
        channel_id  => $self->{channel}->id,
    });

    # create 2 customer segments
    my $customer_segments = Test::XTracker::Data::MarketingCustomerSegment->create_customer_segment({
        how_many => 3,
        channel_id  => $self->{channel}->id,
    });

    #link customers to customer_segments
    foreach my $customer ( @{ $customers } ) {
        Test::XTracker::Data::MarketingCustomerSegment->link_to_customer(
            @$customer_segments[0],
            $customer->{customer},
        );
        Test::XTracker::Data::MarketingCustomerSegment->link_to_customer(
            @$customer_segments[1],
            $customer->{customer},
        );
    }

    #link customer (of order) to one of the customersegment
    Test::XTracker::Data::MarketingCustomerSegment->link_to_customer(
            @$customer_segments[0],
            $self->{customer},
        );

    #create marketing promotion
    my $promo = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion( {
        count           => 1,
        channel_id      => $self->{channel}->id,
        start_date      => DateTime->now()->subtract( days => 1 ),
        end_date        => DateTime->now()->add( days => 1 ),
    })->[0];

    #link promotion to all the customer_segments
    foreach my $segment ( @{ $customer_segments } ) {
        $promo->create_related( 'link_marketing_promotion__customer_segments',{
            customer_segment_id => $segment->id,
        });
    }

    # TEST-1: Check Promotion having Active customer_segment With customer_id of order
    #       gets linked to promotion
     my $mp_obj  = XTracker::Promotion::Marketing->new( {
        schema  => $self->{schema},
        order   => $self->{order},
    });
    my $result = $mp_obj->check_promotion_applicable( $promo );

    cmp_ok($result,'==', 1, "Test 1 - check_promotion_applicable returns TRUE");

    # Apply promotion to order
    $mp_obj->apply_to_order();

    my $result2 = $self->{order}->discard_changes->search_related ('link_orders__marketing_promotions', {
        marketing_promotion_id => $promo->id,
    })->count();

    cmp_ok($result2,'==', 1, "Test 1 - Order Got applied to promotion");

    # clean-up data
    $self->{order}->link_orders__marketing_promotions->delete;


    # TEST-2: Disable customer segment which has the cusomter id - Promotion should not get applied to order

    # Make customer segment inactive
    my $inactive_segment = @$customer_segments[0];
    $inactive_segment->update({enabled => 'f' } );
    $inactive_segment->discard_changes();

    $mp_obj->check_promotion_applicable( $promo );

    $result = $mp_obj->check_promotion_applicable( $promo );
    cmp_ok($result,'==', 0, "Test 2 - check_promotion_applicable returns FALSE");

    # Apply promotion to order
    $mp_obj->apply_to_order();
    $result2 = $self->{order}->discard_changes->search_related ('link_orders__marketing_promotions', {
        marketing_promotion_id => $promo->id,
    })->count();

    cmp_ok($result2,'==', 0, "Test 2 - Order Does NOT get applied to promotion");

    # clean-up data
    $self->{order}->link_orders__marketing_promotions->delete;


    # TEST-3: Customer segments wihtout the order-customer_id in it

    #Activate the customer Segment but delete customer_id belonging to order
    my $active_segment = @$customer_segments[0];
    $inactive_segment->update({enabled => 't' } );
    $inactive_segment->delete_related('link_marketing_customer_segment__customers',{
        customer_id => $self->{customer}->id,
    });

    $mp_obj->check_promotion_applicable( $promo );

    $result = $mp_obj->check_promotion_applicable( $promo );
    cmp_ok($result,'==', 0, "Test 3 - check_promotion_applicable returns FALSE");

    # Apply promotion to order
    $mp_obj->apply_to_order();
    $result2 = $self->{order}->discard_changes->search_related ('link_orders__marketing_promotions', {
        marketing_promotion_id => $promo->id,
    })->count();

    cmp_ok($result2,'==', 0, "Test 3 - Order Does NOT get applied to promotion");
}

=head2 apply_to_order_for_designers

Tests that Orders with Products for the right Designers get linked with the
correct Promotion.

=cut

sub apply_to_order_for_designers : Tests() {
    my $self    = shift;

    my @designers   = Test::XTracker::Data::Designer->grab_designers( { how_many => 7 } );

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
                                how_many => 5,
                                channel  => $self->{channel},
                            });

    my %tests   = (
            "An Order has One Product whose Designer is in One Promotion"   => {
                    pids_to_use         => [ $pids->[0] ],      # Apply the Designer to the Product in
                    designers_for_pids  => [ $designers[0] ],   # its corresponding position in the Array
                    promos_with_designers => [
                                    [ $designers[0] ],      # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "An Order has One Product whose Designer is NOT in a Promotion"   => {
                    pids_to_use         => [ $pids->[0] ],
                    designers_for_pids  => [ $designers[0] ],
                    promos_with_designers => [
                                    [ $designers[1] ],      # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "An Order has 3 Products 2 of which are in 2 Different Promotions"  => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    designers_for_pids  => [ @designers[0..2] ],
                    promos_with_designers => [
                                    [ $designers[0] ],      # Promo 1
                                    [ $designers[2] ],      # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "An Order should be assigned to 2 out of 3 Promotions"  => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    designers_for_pids  => [ @designers[0..2] ],
                    promos_with_designers => [
                                    [ $designers[0] ],
                                    [ $designers[3] ],
                                    [ $designers[2] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 0,
                                    3 => 1,
                                },
                },
            "An Order has Products assigned to none of 4 Promotions"    => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    designers_for_pids  => [ @designers[0..2] ],
                    promos_with_designers => [
                                    [ $designers[3] ],
                                    [ @designers[3,4] ],
                                    [ @designers[5..6] ],
                                    [ $designers[6] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Designer applied to an Order"    => {
                    pids_to_use         => [ @{ $pids }[0..3] ],
                    designers_for_pids  => [ @designers[0..3] ],
                    promos_with_designers => [
                                    [ @designers[0,2] ],
                                    [ @designers[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
            "An Order with Products being in more than One Promotion"   => {
                    pids_to_use         => [ @{ $pids }[0..3] ],
                    designers_for_pids  => [ @designers[0..3] ],
                    promos_with_designers => [
                                    [ @designers[0,2] ],
                                    [ @designers[1,2,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # assign Designers to Products
        foreach my $idx ( 0..$#{ $test->{pids_to_use} } ) {
            $test->{pids_to_use}[ $idx ]{product}->update( {
                                    designer_id => $test->{designers_for_pids}[ $idx ]->{designer_id},
                                } );
        }

        # assign Designers to Promotions
        my @promotions;
        my %expected_promotions;
        foreach my $idx ( 0..$#{ $test->{promos_with_designers} } ) {
            my $designers   = $test->{promos_with_designers}->[ $idx ];
            my $promo       = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion( {
                                                        count           => 1,
                                                        channel_id      => $channel->id,
                                                        start_date      => DateTime->now()->subtract( days => 1 ),
                                                        end_date        => DateTime->now()->add( days => 1 ),
                                                } )->[0];

            foreach my $designer ( @{ $designers } ) {
                $promo->create_related( 'link_marketing_promotion__designers', {
                                                        designer_id => $designer->{designer_id},
                                                        include     => 1,
                                                } );
            }

            push @promotions, $promo;

            # store whether Promotion Id would be
            # assigned to an Order along with its Index
            $expected_promotions{ $promo->id }   = {
                                        idx     => ( $idx + 1 ),
                                        assigned=> ( $test->{expected_promos}{ ( $idx+1 ) } ? 1 : 0 ),
                                    }
        }

        # get the Promo Ids that are expected to be assigned to Orders
        my @expected_promo_ids  = sort { $a <=> $b }
                                        grep { $expected_promotions{ $_ }{assigned} }
                                                keys %expected_promotions;

        # create an Order
        my $order   = _create_order( $channel, $test->{pids_to_use}, 1 )->[0];

        my $mp_obj  = XTracker::Promotion::Marketing->new( {
                            schema  => $self->{schema},
                            order   => $order,
                        } );

        # check the 'check_promotion_applicable' method first
        foreach my $promo ( @promotions ) {
            my $result      = $mp_obj->check_promotion_applicable( $promo );
            my $idx_of_promo= $expected_promotions{ $promo->id }{idx};
            if ( $expected_promotions{ $promo->id }{assigned} ) {
                cmp_ok( $result, '==', 1, "'check_promotion_applicable' method retured TRUE for Promo: ${idx_of_promo}" );
            }
            else {
                cmp_ok( $result, '==', 0, "'check_promotion_applicable' method retured FALSE for Promo: ${idx_of_promo}" );
            }
        }

        # apply the Promotions to the
        # Order at a Database level
        $mp_obj->apply_to_order();

        my @got_promo_ids   = sort { $a <=> $b }
                                    map { $_->marketing_promotion_id }
                                            $order->discard_changes
                                                    ->link_orders__marketing_promotions
                                                        ->all;
        is_deeply( \@got_promo_ids, \@expected_promo_ids,
                            "'apply_to_order' method applied the Expected Promotions to the Order" );

        # clean-up data
        $order->link_orders__marketing_promotions->delete;
        foreach my $promo ( @promotions ) {
            $promo->link_marketing_promotion__designers->delete;
            $promo->delete;
        }
    }

    return;
}

=head2 apply_to_order_for_countries

Tests that Orders with the right Shipping Country get linked with the
correct Promotion.

=cut

sub apply_to_order_for_countries : Tests() {
    my $self    = shift;

    my @countries   = $self->rs('Public::Country')->search(
        {
            id  => { '!=' => $COUNTRY__UNKNOWN },
        }
    )->all;

    my %tests   = (
            "An Order's Shipping Country is in One Promotion"   => {
                    country_to_use  => $countries[0],      # Apply the Country to the Order
                    promos_with_countries => [
                                    [ $countries[0] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "An Order's Shipping Country is NOT in a Promotion"   => {
                    country_to_use      => $countries[0],
                    promos_with_countries => [
                                    [ $countries[1] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "An Order's Shipping Country is in 2 Different Promotions"  => {
                    country_to_use      => $countries[1],
                    promos_with_countries => [
                                    [ $countries[1] ],     # Promo 1
                                    [ $countries[1] ],     # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "An Order's Shipping Country is in 2 out of 3 Promotions"  => {
                    country_to_use      => $countries[1],
                    promos_with_countries => [
                                    [ $countries[0] ],
                                    [ $countries[1] ],
                                    [ $countries[1] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 1,
                                    3 => 1,
                                },
                },
            "An Order's Shipping Country is NOT assigned to any of 4 Promotions"    => {
                    country_to_use      => $countries[1],
                    promos_with_countries => [
                                    [ $countries[3] ],
                                    [ @countries[3,4] ],
                                    [ @countries[5..6] ],
                                    [ $countries[6] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Country applied to an Order"    => {
                    country_to_use      => $countries[1],
                    promos_with_countries => [
                                    [ @countries[0..2] ],
                                    [ @countries[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # assign Countries to Promotions
        my %expected_promotions;
        my @promotions  = $self->_apply_options_to_promotions( {
            promos_with_options => $test->{promos_with_countries},
            link_table          => 'link_marketing_promotion__countries',
            link_field_id       => 'country_id',
            expected_promos     => $test->{expected_promos},
            expected_promotions => \%expected_promotions,
        } );

        # create an Order
        my $order   = _create_order( $self->{channel}, $self->{pids}, 1 )->[0];

        # change the Shipping Country
        $order->get_standard_class_shipment->shipment_address->update( {
            country => $test->{country_to_use}->country,
        } );

        my $mp_obj  = XTracker::Promotion::Marketing->new( {
                            schema  => $self->{schema},
                            order   => $order,
                        } );

        $self->_test_assigning_promotions( $order, \@promotions, \%expected_promotions );

        $self->_cleanup_data( $order, \@promotions, 'link_marketing_promotion__countries' );
    }
}

=head2 apply_to_order_for_languages

Tests that Orders with Customers who have chosen the right preferred Language
get linked with the correct Promotion.

=cut

sub apply_to_order_for_languages : Tests() {
    my $self    = shift;

    my @languages   = $self->rs('Public::Language')->all;

    my %tests   = (
            "A Customer's Language is in One Promotion"   => {
                    language_to_use  => $languages[0],      # Apply the Language to the Order
                    promos_with_languages => [
                                    [ $languages[0] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "A Customer's Language is NOT in a Promotion"   => {
                    language_to_use      => $languages[0],
                    promos_with_languages => [
                                    [ $languages[1] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "A Customer's Language is in 2 Different Promotions"  => {
                    language_to_use      => $languages[1],
                    promos_with_languages => [
                                    [ $languages[1] ],     # Promo 1
                                    [ $languages[1] ],     # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "A Customer's Language is in 2 out of 3 Promotions"  => {
                    language_to_use      => $languages[1],
                    promos_with_languages => [
                                    [ $languages[0] ],
                                    [ $languages[1] ],
                                    [ $languages[1] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 1,
                                    3 => 1,
                                },
                },
            "A Customer's Language is NOT assigned to any of 4 Promotions"    => {
                    language_to_use      => $languages[1],
                    promos_with_languages => [
                                    [ $languages[3] ],
                                    [ @languages[0,2,3] ],
                                    [ @languages[0,2] ],
                                    [ $languages[2] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Language applied to an Order"    => {
                    language_to_use      => $languages[1],
                    promos_with_languages => [
                                    [ @languages[0..2] ],
                                    [ @languages[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # assign Languages to Promotions
        my %expected_promotions;
        my @promotions  = $self->_apply_options_to_promotions( {
            promos_with_options => $test->{promos_with_languages},
            link_table          => 'link_marketing_promotion__languages',
            link_field_id       => 'language_id',
            expected_promos     => $test->{expected_promos},
            expected_promotions => \%expected_promotions,
        } );

        # create an Order
        my $order   = _create_order( $self->{channel}, $self->{pids}, 1 )->[0];

        # change the Customer's Language Preference
        $order->customer->update_or_create_related( 'customer_attribute', {
            language_preference_id => $test->{language_to_use}->id,
        } );

        my $mp_obj  = XTracker::Promotion::Marketing->new( {
                            schema  => $self->{schema},
                            order   => $order,
                        } );

        $self->_test_assigning_promotions( $order, \@promotions, \%expected_promotions );

        $self->_cleanup_data( $order, \@promotions, 'link_marketing_promotion__languages' );
    }
}

=head2 apply_to_order_for_product_types

Tests that Orders with Products which have the right Product Types get linked with the
correct Promotion.

=cut

sub apply_to_order_for_product_types : Tests() {
    my $self    = shift;

    my @prodtypes   = $self->rs('Public::ProductType')->search(
        {
            id  => { '!=' => 0 },
        },
    )->all;
    my $default_prod_type   = shift @prodtypes;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
        how_many    => 5,
        channel     => $self->{channel},
    } );

    foreach my $pid ( @{ $pids } ) {
        $pid->{product}->update( {
            product_type_id => $default_prod_type->id,
        } );
    }

    my %tests   = (
            "An Order has One Product whose Type is in One Promotion"   => {
                    pids_to_use         => [ $pids->[0] ],          # Apply the Product Type to the Product in
                    prodtypes_for_pids  => [ $prodtypes[0] ],       # its corresponding position in the Array
                    promos_with_prodtypes => [
                                    [ $prodtypes[0] ],      # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "An Order has One Product whose Type is NOT in a Promotion"   => {
                    pids_to_use         => [ $pids->[0] ],
                    prodtypes_for_pids  => [ $prodtypes[0] ],
                    promos_with_prodtypes => [
                                    [ $prodtypes[1] ],      # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "An Order has 3 Products 2 of which are in 2 Different Promotions"  => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    prodtypes_for_pids  => [ @prodtypes[0..2] ],
                    promos_with_prodtypes => [
                                    [ $prodtypes[0] ],      # Promo 1
                                    [ $prodtypes[2] ],      # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "An Order should be assigned to 2 out of 3 Promotions"  => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    prodtypes_for_pids  => [ @prodtypes[0..2] ],
                    promos_with_prodtypes => [
                                    [ $prodtypes[0] ],
                                    [ $prodtypes[3] ],
                                    [ $prodtypes[2] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 0,
                                    3 => 1,
                                },
                },
            "An Order has Products assigned to none of 4 Promotions"    => {
                    pids_to_use         => [ @{ $pids }[0..2] ],
                    prodtypes_for_pids  => [ @prodtypes[0..2] ],
                    promos_with_prodtypes => [
                                    [ $prodtypes[3] ],
                                    [ @prodtypes[3,4] ],
                                    [ @prodtypes[5..6] ],
                                    [ $prodtypes[6] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Product Type applied to an Order"    => {
                    pids_to_use         => [ @{ $pids }[0..3] ],
                    prodtypes_for_pids  => [ @prodtypes[0..3] ],
                    promos_with_prodtypes => [
                                    [ @prodtypes[0,2] ],
                                    [ @prodtypes[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
            "An Order with Products whose Types are in more than One Promotion"   => {
                    pids_to_use         => [ @{ $pids }[0..3] ],
                    prodtypes_for_pids  => [ @prodtypes[0..3] ],
                    promos_with_prodtypes => [
                                    [ @prodtypes[0,2] ],
                                    [ @prodtypes[1,2,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # assign Product Types to Products
        foreach my $idx ( 0..$#{ $test->{pids_to_use} } ) {
            $test->{pids_to_use}[ $idx ]{product}->update( {
                product_type_id => $test->{prodtypes_for_pids}[ $idx ]->id,
            } );
        }

        # assign Product Types to Promotions
        my %expected_promotions;
        my @promotions  = $self->_apply_options_to_promotions( {
            promos_with_options => $test->{promos_with_prodtypes},
            link_table          => 'link_marketing_promotion__product_types',
            link_field_id       => 'product_type_id',
            expected_promos     => $test->{expected_promos},
            expected_promotions => \%expected_promotions,
        } );

        # create an Order
        my $order   = _create_order( $channel, $test->{pids_to_use}, 1 )->[0];

        my $mp_obj  = XTracker::Promotion::Marketing->new( {
                            schema  => $self->{schema},
                            order   => $order,
                        } );

        $self->_test_assigning_promotions( $order, \@promotions, \%expected_promotions );

        $self->_cleanup_data( $order, \@promotions, 'link_marketing_promotion__product_types' );
    }

    return;
}

=head2 apply_to_order_for_titles

Tests that Orders with Customers who have the right Titles
get linked with the correct Promotion.

=cut

sub apply_to_order_for_titles : Tests() {
    my $self    = shift;

    my @titles  = $self->rs('Public::MarketingGenderProxy')->all;

    my %tests   = (
            "A Customer's Title is in One Promotion"   => {
                    title_to_use  => $titles[0]->title,        # Apply the Title to the Customer
                    promos_with_titles => [
                                    [ $titles[0] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "A Customer's Title is NOT in a Promotion"   => {
                    title_to_use      => $titles[0]->title,
                    promos_with_titles => [
                                    [ $titles[1] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "A Customer's Title is in 2 Different Promotions"  => {
                    title_to_use      => lc( $titles[1]->title ),
                    promos_with_countries => [
                                    [ $titles[1] ],     # Promo 1
                                    [ $titles[1] ],     # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "A Customer's Title is in 2 out of 3 Promotions"  => {
                    title_to_use      => uc( $titles[1]->title ),
                    promos_with_titles => [
                                    [ $titles[0] ],
                                    [ $titles[1] ],
                                    [ $titles[1] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 1,
                                    3 => 1,
                                },
                },
            "A Customer's Title is NOT assigned to any of 4 Promotions"    => {
                    title_to_use      => $titles[1]->title,
                    promos_with_titles => [
                                    [ $titles[3] ],
                                    [ @titles[3,4] ],
                                    [ @titles[5..6] ],
                                    [ $titles[6] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Title applied to an Order"    => {
                    title_to_use      => $titles[1]->title,
                    promos_with_titles => [
                                    [ @titles[0..2] ],
                                    [ @titles[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
            "A Customer's Title is Empty Should NOT be assigned to a Promotion"    => {
                    title_to_use      => '',
                    promos_with_titles => [
                                    [ @titles ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                },
                },
            "A Customer's Title is 'undef' Should NOT be assigned to a Promotion"    => {
                    title_to_use      => undef,
                    promos_with_titles => [
                                    [ @titles ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                },
                },
            "A Customer's Title is not one from the List of Titles, Should NOT be assigned to a Promotion"    => {
                    title_to_use      => 'klsdfk',
                    promos_with_titles => [
                                    [ @titles ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # A Title can be on the Customer record or the Shipping Address
        # record, these are the different combinations. If the Shipping
        # Address record has a value then only it should be used
        my @title_combinations  = (
            { customer => undef,                 address => $test->{title_to_use} },
            { customer => $test->{title_to_use}, address => undef },
            { customer => '',                    address => $test->{title_to_use} },
            { customer => $test->{title_to_use}, address => '' },
            { customer => 'nonsense',            address => $test->{title_to_use} },
            { customer => $test->{title_to_use}, address => 'nonsense', no_promotions_should_apply => 1 },
        );

        note "Testing with Different Customer & Shipping Address Title Combinations";
        foreach my $combination ( @title_combinations ) {

            # assign Titles to Promotions
            my %expected_promotions;
            my @promotions  = $self->_apply_options_to_promotions( {
                promos_with_options => $test->{promos_with_titles},
                link_table          => 'link_marketing_promotion__gender_proxies',
                link_field_id       => 'gender_proxy_id',
                expected_promos     => $test->{expected_promos},
                expected_promotions => \%expected_promotions,
            } );

            # create an Order
            my $order               = _create_order( $self->{channel}, $self->{pids}, 1 )->[0];
            my $shipping_address    = $order->get_standard_class_shipment->shipment_address;

            my $mp_obj  = XTracker::Promotion::Marketing->new( {
                schema  => $self->{schema},
                order   => $order,
            } );

            note "Customer Title: '" . ( $combination->{customer} // 'undef' ) . "'" .
                 "Shipping Address Title: '" . ( $combination->{address} // 'undef' ) . "'" .
                 ( $combination->{no_promotions_should_apply} ? ' - AND NO PROMOTIONS SHOULD BE APPLIED' : '' );

            $order->customer->update( { title => $combination->{customer} } );
            $shipping_address->update( { title => $combination->{address} } );

            if ( $combination->{no_promotions_should_apply} ) {
                $_->{assigned}  = 0     foreach ( values %expected_promotions );
            }

            $self->_test_assigning_promotions( $order, \@promotions, \%expected_promotions );
            $self->_cleanup_data( $order, \@promotions, 'link_marketing_promotion__gender_proxies' );
        }
    }
}

=head2 apply_to_order_for_categories

Tests that Orders with Customers who have the right Customer Category
get linked with the correct Promotion.

=cut

sub apply_to_order_for_categories : Tests() {
    my $self    = shift;

    my @categories = $self->rs('Public::CustomerCategory')->all;

    my %tests   = (
            "A Customer's Category is in One Promotion"   => {
                    category_to_use  => $categories[0],    # Apply the Category to the Order
                    promos_with_categories => [
                                    [ $categories[0] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 to be
                                },                      # assigned to the Order
                },
            "A Customer's Category is NOT in a Promotion"   => {
                    category_to_use      => $categories[0],
                    promos_with_categories => [
                                    [ $categories[1] ],     # Promo 1
                                ],
                    expected_promos => {
                                    1 => 0,             # expect Promo 1 NOT to
                                },                      # be assigned to the Order
                },
            "A Customer's Category is in 2 Different Promotions"  => {
                    category_to_use      => $categories[1],
                    promos_with_categories => [
                                    [ $categories[1] ],     # Promo 1
                                    [ $categories[1] ],     # Promo 2
                                ],
                    expected_promos => {
                                    1 => 1,             # expect Promo 1 and 2 to
                                    2 => 1,             # be assigned to the Order
                                },
                },
            "A Customer's Category is in 2 out of 3 Promotions"  => {
                    category_to_use      => $categories[1],
                    promos_with_categories => [
                                    [ $categories[0] ],
                                    [ $categories[1] ],
                                    [ $categories[1] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 1,
                                    3 => 1,
                                },
                },
            "A Customer's Category is NOT assigned to any of 4 Promotions"    => {
                    category_to_use      => $categories[1],
                    promos_with_categories => [
                                    [ $categories[3] ],
                                    [ @categories[0,2,3] ],
                                    [ @categories[0,2] ],
                                    [ $categories[2] ],
                                ],
                    expected_promos => {
                                    1 => 0,
                                    2 => 0,
                                    3 => 0,
                                    4 => 0,
                                },
                },
            "Promotions with more than one Category applied to an Order"    => {
                    category_to_use      => $categories[1],
                    promos_with_categories => [
                                    [ @categories[0..2] ],
                                    [ @categories[1,3] ],
                                ],
                    expected_promos => {
                                    1 => 1,
                                    2 => 1,
                                },
                },
        );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # assign Categories to Promotions
        my %expected_promotions;
        my @promotions  = $self->_apply_options_to_promotions( {
            promos_with_options => $test->{promos_with_categories},
            link_table          => 'link_marketing_promotion__customer_categories',
            link_field_id       => 'customer_category_id',
            expected_promos     => $test->{expected_promos},
            expected_promotions => \%expected_promotions,
        } );

        # create an Order
        my $order   = _create_order( $self->{channel}, $self->{pids}, 1 )->[0];

        # change the Customer's Category
        $order->customer->update( { category_id => $test->{category_to_use}->id } );

        $self->_test_assigning_promotions( $order, \@promotions, \%expected_promotions );

        $self->_cleanup_data( $order, \@promotions, 'link_marketing_promotion__customer_categories' );
    }
}

=head2 check_promotion_applicable_for_multiple_options

Tests that when a Promotion has Multiple Options assigned to it that it
gets Applied to Orders that have ALL of those Options applied to them.

=cut

sub check_promotion_applicable_for_multiple_options : Tests() {
    my $self    = shift;

    # Get 2 Customers and assign one of them to a Customer Segment
    my $customers = Test::XTracker::Data::MarketingCustomerSegment->grab_customers( {
        how_many    => 2,
        channel_id  => $self->{channel}->id,
    } );
    my $customer_segments = Test::XTracker::Data::MarketingCustomerSegment->create_customer_segment( {
        how_many => 1,
        channel_id  => $self->{channel}->id,
    } );
    Test::XTracker::Data::MarketingCustomerSegment->link_to_customer(
        $customer_segments->[0],
        $customers->[0]{customer},
    );

    my @designers   = Test::XTracker::Data::Designer->grab_designers( { how_many => 2, want_dbic_recs => 1 } );
    my @countries   = $self->rs('Public::Country')->search(
        {
            id  => { '!=' => $COUNTRY__UNKNOWN },
        }
    )->all;
    my @languages   = $self->rs('Public::Language')->all;
    my @prodtypes   = $self->rs('Public::ProductType')->search(
        {
            id  => { '!=' => 0 },
        },
    )->all;
    my @titles      = $self->rs('Public::MarketingGenderProxy')->all;
    my @categories  = $self->rs('Public::CustomerCategory')->all;

    my %options = (
        designer    => {
            link_table      => 'link_marketing_promotion__designers',
            link_field_id   => 'designer_id',
            should_apply    => shift @designers,
            should_not_apply=> shift @designers,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                my @items = $order->get_standard_class_shipment
                                    ->shipment_items->all;
                foreach my $item ( @items ) {
                    if( defined $item->variant ){
                        $item->variant->product->update( {
                            designer_id => $option->id,
                        } );
                    }
                }

                return;
            },
        },
        customer    => {
            link_table      => 'link_marketing_promotion__customer_segments',
            link_field_id   => 'customer_segment_id',
            apply_to_promo  => $customer_segments->[0],
            should_apply    => $customers->[0]{customer},
            should_not_apply=> $customers->[1]{customer},
            apply_option    => sub {
                my ( $option, $order )  = @_;
                $order->update( { customer_id => $option->id } );
                return;
            },
        },
        country     => {
            link_table      => 'link_marketing_promotion__countries',
            link_field_id   => 'country_id',
            should_apply    => shift @countries,
            should_not_apply=> shift @countries,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                $order->get_standard_class_shipment->shipment_address
                        ->update( {
                    country => $option->country,
                } );
                return;
            },
        },
        language    => {
            link_table      => 'link_marketing_promotion__languages',
            link_field_id   => 'language_id',
            should_apply    => shift @languages,
            should_not_apply=> shift @languages,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                $order->customer->update_or_create_related( 'customer_attribute', {
                    language_preference_id  => $option->id,
                } );
                return;
            },
        },
        prodtype    => {
            link_table      => 'link_marketing_promotion__product_types',
            link_field_id   => 'product_type_id',
            should_apply    => shift @prodtypes,
            should_not_apply=> shift @prodtypes,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                my @items = $order->get_standard_class_shipment
                                    ->shipment_items->all;
                foreach my $item ( @items ) {

                    if( defined $item->variant ){
                        $item->variant->product->update( {
                            product_type_id => $option->id,
                        } );
                    }
                }

                return;
            },
        },
        title       => {
            link_table      => 'link_marketing_promotion__gender_proxies',
            link_field_id   => 'gender_proxy_id',
            should_apply    => shift @titles,
            should_not_apply=> shift @titles,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                $order->customer->update( {
                    title   => $option->title,
                } );
                $order->get_standard_class_shipment->shipment_address
                        ->update( {
                    title   => $option->title,
                } );
                return;
            },
        },
        customer_category => {
            link_table      => 'link_marketing_promotion__customer_categories',
            link_field_id   => 'customer_category_id',
            should_apply    => shift @categories,
            should_not_apply=> shift @categories,
            apply_option    => sub {
                my ( $option, $order )  = @_;
                $order->customer->update( {
                    category_id  => $option->id,
                } );
                return;
            },
        },
    );

    # create an Order
    my $order   = _create_order( $self->{channel}, $self->{pids}, 1 )->[0];

    # create a Promotion and assign all of the Options to it and the Order
    my $promotion;
    foreach my $value ( values %options ) {
        ( $promotion )  = $self->_apply_options_to_promotions( {
            promotion           => $promotion,
            promos_with_options => [ [ ( $value->{apply_to_promo} // $value->{should_apply} ) ] ],
            link_table          => $value->{link_table},
            link_field_id       => $value->{link_field_id},
        } );

        $value->{apply_option}->( $value->{should_apply}, $order );
        # make sure changes are applied
        $order->discard_changes;
    }

    my $mp_obj  = XTracker::Promotion::Marketing->new( {
        schema  => $self->schema,
        order   => $order,
    } );

    # check that the Order should be Applied to the Promotion
    cmp_ok( $mp_obj->check_promotion_applicable( $promotion ), '==', 1,
            "Promotion with Multiple Options is Applied to an Order that has ALL Multiple Options" );

    # now go through each Type of Option and assign a value
    # to the Order which is not part of the Promotion
    foreach my $label ( keys %options ) {
        note "Using NON Applicable Option for Type: '${label}'";
        my $option_type = $options{ $label };

        # apply the NON Applicable Option
        $option_type->{apply_option}->( $option_type->{should_not_apply}, $order );
        # make sure changes are applied
        $order->discard_changes;

        cmp_ok( $mp_obj->check_promotion_applicable( $promotion ), '==', 0,
                    "Promotion DOESN'T get Applied to the Order" );

        # put back the Applicable Option
        $option_type->{apply_option}->( $option_type->{should_apply}, $order );
        $order->discard_changes;
    }
}

#-----------------------------------------------------------------------------


sub _create_order {
    my ( $channel, $pids, $no_of_orders, $args ) = @_;

    my $count = $no_of_orders || 1;
    my $customer    = $args->{customer} || Test::XTracker::Data->find_customer({
        channel_id => $channel->id,
    });

    Test::XTracker::Data->ensure_stock(
        $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id
    );

    # go get some pids relevant to the db I'm using - channel is for test context
    my ($voucher_channel,$voucher_pids) = Test::XTracker::Data->grab_products( {
        how_many => 1,
        phys_vouchers   => {
            how_many => 1,
            want_stock => 10,
            want_code => 10,
            value => '100.00',
        },
        virt_vouchers   => {
            how_many => 1,
            want_code => 1,
        },
    });

    push @$pids, @$voucher_pids;

    my @orders;
    for my $i ( 1 .. $count ) {
         my($order,$order_hash) = Test::XTracker::Data->create_db_order({
            base => {
                customer_id          => $customer->id,
                channel_id           => $channel->id,
            },
            pids => $pids,
            attrs => [
                { price => 100.00 },
            ],
        });
        push ( @orders, $order);
   }

    return \@orders;
}

sub _apply_options_to_promotions {
    my ( $self, $args ) = @_;

    my @promotions;
    foreach my $idx ( 0..$#{ $args->{promos_with_options} } ) {
        my $options = $args->{promos_with_options}->[ $idx ];
        my $promo   = $args->{promotion} //
            Test::XTracker::Data::MarketingPromotion->create_marketing_promotion( {
                count           => 1,
                channel_id      => $self->{channel}->id,
                start_date      => DateTime->now()->subtract( days => 1 ),
                end_date        => DateTime->now()->add( days => 1 ),
            } )->[0];

        foreach my $option ( @{ $options } ) {
            $promo->create_related( $args->{link_table}, {
                $args->{link_field_id} => $option->id,
            } );
        }

        push @promotions, $promo;

        # store whether Promotion Id would be
        # assigned to an Order along with its Index
        $args->{expected_promotions}{ $promo->id }   = {
                                    idx     => ( $idx + 1 ),
                                    assigned=> ( $args->{expected_promos}{ ( $idx+1 ) } ? 1 : 0 ),
                                }
    }

    return @promotions;
}

sub _test_assigning_promotions {
    my ( $self, $order, $promotions, $expected_promotions ) = @_;

    # get the Promo Ids that are expected to be assigned to Orders
    my @expected_promo_ids  = sort { $a <=> $b }
                                    grep { $expected_promotions->{ $_ }{assigned} }
                                            keys %{ $expected_promotions };

    my $mp_obj  = XTracker::Promotion::Marketing->new( {
        schema  => $self->schema,
        order   => $order,
    } );

    # check the 'check_promotion_applicable' method first
    foreach my $promo ( @{ $promotions } ) {
        my $result      = $mp_obj->check_promotion_applicable( $promo );
        my $idx_of_promo= $expected_promotions->{ $promo->id }{idx};
        if ( $expected_promotions->{ $promo->id }{assigned} ) {
            cmp_ok( $result, '==', 1, "'check_promotion_applicable' method retured TRUE for Promo: ${idx_of_promo}" );
        }
        else {
            cmp_ok( $result, '==', 0, "'check_promotion_applicable' method retured FALSE for Promo: ${idx_of_promo}" );
        }
    }

    # apply the Promotions to the
    # Order at a Database level
    $mp_obj->apply_to_order();

    my @got_promo_ids   = sort { $a <=> $b }
                                map { $_->marketing_promotion_id }
                                        $order->discard_changes
                                                ->link_orders__marketing_promotions
                                                    ->all;
    is_deeply( \@got_promo_ids, \@expected_promo_ids,
                        "'apply_to_order' method applied the Expected Promotions to the Order" );

    return;
}

sub _cleanup_data {
    my ( $self, $order, $promotions, $link_table )  = @_;

    # clean-up data, so doesn't effect a Customer's history of Promotions
    $order->link_orders__marketing_promotions->delete;
    foreach my $promo ( @{ $promotions } ) {
        $promo->$link_table->delete;
        $promo->delete;
    }

    return;
}

