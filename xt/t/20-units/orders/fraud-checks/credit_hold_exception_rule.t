#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-491
Credit Check Rule for NAP and OUTNET

=cut

use Test::Most '-Test::Deep';
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::FraudRule;
use Test::XTracker::Mechanize;
use Data::Dumper;
use XTracker::Database::Finance         qw( :DEFAULT get_credit_hold_thresholds );
use XTracker::Database::Currency        qw( get_local_conversion_rate );
use XTracker::Database::Order           qw( get_order_flags get_order_id );
use XTracker::Database::Customer        qw( :DEFAULT match_customer );
use XTracker::Config::Local             qw( config_var sys_config_var);

use String::Random;

use Data::Dump 'pp';
use DateTime;

use XTracker::Database qw( :common );
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
    :order_status
    :flag
    :renumeration_type
    :shipment_status
);

# this gives us XT::Domain::Payment with our injected method
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::DHL::XMLRequest;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories;

my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;


my $pids = Test::XTracker::Data->get_pid_set({
                nap => 1,
                outnet => 1,
                mrp => 1,
            });



my @channels = $schema->resultset('Public::Channel')->search( { is_enabled => 1, fulfilment_only => 0 }, { join => 'business' } )->all;
my $old_order; #variable for storing pre-existing order to be manipulated latter

my $expected_order_check_rule = {
    'passed_criteria' => {
        'MRPORTER.COM' => 0,
        'theOutnet.com' => 1,
        'NET-A-PORTER.COM' => 1,
    },
    'failed_criteria' => {
        'MRPORTER.COM'  => 0,
        'theOutnet.com' => 0,
        'NET-A-PORTER.COM' => 0,
    },
    'across_channel' => {
        'NET-A-PORTER.COM' => 1,
    },
};


my $expected_card_check_rule = {
    'no_card_history' => {
        'MRPORTER.COM'     => 1,
        'theOutnet.com'    => 1,
        'NET-A-PORTER.COM' => 1,
    },
   'failed_criteria' => {
       'MRPORTER.COM'     => 1,
       'theOutnet.com'    => 0,
       'NET-A-PORTER.COM' => 0,
    },
};

my $expected_address_check_rule = {
    'same_address'=> {
        'MRPORTER.COM'     => 1,
        'theOutnet.com'    => 1,
        'NET-A-PORTER.COM' => 1,
    },
    'address_count' => {
        'MRPORTER.COM'     => 2,
        'theOutnet.com'    => 2,
        'NET-A-PORTER.COM' => 2,
    },
};

# for Disabled Sales Channels then remove them from the Expected Data
_remove_expectations( \@channels, $expected_order_check_rule );
_remove_expectations( \@channels, $expected_card_check_rule );
_remove_expectations( \@channels, $expected_address_check_rule );

$schema->txn_do( sub {

    Test::XTracker::Data::FraudRule->switch_all_channels_off();

    #Create a order for each channel to be manupulated latter
    foreach my $channel ( @channels ) {

            isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel', 'Got Channel Record for: '.$channel->id.' - '.$channel->name );

            # change the sys_config_var to known values
            my $config_month           = '';
            my $config_ordervalue      = '';
            my @config_include_channel = ();

            my $config_params     = $channel->config_group->search( { name => 'CreditHoldExceptionParams' } ) ;

            if($config_params->count > 0) {
                $config_month      = $config_params->first->config_group_settings_rs->search( { setting => 'month' } )->first;
                $config_ordervalue = $config_params->first->config_group_settings_rs->search( { setting => 'order_total' } )->first;
                @config_include_channel = $config_params->first->config_group_settings_rs->search( { setting => 'include_channel' } )->all;
            }

            if( $channel->name !~ /MRPORTER.COM/i ) {
                $config_month->update( { value => 9 } ) if $config_month ne '';
                $config_ordervalue->update( { value => '5000' } ) if $config_ordervalue ne '';
            } else {
                $config_month->update( { value =>  } ) if $config_month ne '';
                $config_ordervalue->update( { value => '5000' } ) if $config_ordervalue ne '';
            }

            my $customer_id = create_unmatchable_customer( $channel->id );
            my $customer = $schema->resultset('Public::Customer')->find( $customer_id );

            my ( undef, $pids )  = Test::XTracker::Data->grab_products({
                how_many            => 1,
                dont_ensure_stock   => 1,
                channel             => $channel,
            });

            my $sku = $pids->[0]{sku};

            # Create existing order.
            my ( $existing_order ) = Test::XTracker::Data->create_db_order ( {
                pids => $pids,
                attrs => [ { price => 2500, tax => 0, duty => 0 } ],
                base => {
                    customer_id         => $customer_id,
                    channel_id          => $channel->id,
                    shipping_charge     => 0,
                    tenders             => [
                        { type => 'card_debit', value => 2500 },
                    ],
                    invoice_address_id => Test::XTracker::Data->create_order_address_in("current_dc")->id,
                },
            } );

            note " +++ ORDER: " . $existing_order->id. " =>". $existing_order->channel_id;

            $old_order->{$existing_order->channel_id}->{'order'}    = $existing_order;
            $old_order->{$existing_order->channel_id}->{'customer'} = $customer;
            $old_order->{$existing_order->channel_id}->{'sku'} = $sku;
            $old_order->{'channel_obj'} = $channel if ($channel->name =~ /theOutnet.com/gi);

            #populate config values
            $old_order->{$existing_order->channel_id}->{'order_value'} ='';
            if( $config_ordervalue ne '') {
                $old_order->{$existing_order->channel_id}->{'month'} = $config_ordervalue->value;
            }

            $old_order->{$existing_order->channel_id}->{'month'} = '';
            if( $config_month ne '') {
                $old_order->{$existing_order->channel_id}->{'month'} = $config_month->value;
            }

            my %list;
            if(@config_include_channel) {
                foreach my $list (@config_include_channel) {
                    $list{$list->value} = 1;
                }
            }
            $old_order->{$existing_order->channel_id}->{'channel_list'} = { %list};



    }


    note("*** Start tests ***");
    _test__has_order_check_rule_passed_subroutine( $schema, 1 );
    _test__is_payment_card_new_subroutine($schema, 1);
    _test__count_address_in_uncancelled_for_customer_subroutine($schema, 1);
    _test__process_fraud_exception_subroutine($schema, 1);

    $schema->txn_rollback();

} );
#--------------------------------------------
done_testing;
#-----------------------------------------------------------------
=head2 _test__has_order_check_rule_passed_subroutine

Testing if
* the customer has x months old order in given channel list
* and order value < y months

=cut
sub _test__has_order_check_rule_passed_subroutine {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test__has_order_check_rule_passed_subroutine", 1 if (!$oktodo);

        note "RUNNING Order Check Rule  For Satisfied Condition \n";

        my $got_results ={};
        foreach my $channel ( @channels ) {
            my $other_customer_id = create_unmatchable_customer( $channel->id );

            my $existing_order = $old_order->{$channel->id}->{'order'};
            my $customer       = $old_order->{$channel->id}->{'customer'};
            my $sku            = $old_order->{$channel->id}->{'sku'};
            my @channel_list   = keys %{$old_order->{$channel->id}->{'channel_list'}};

            my %exception_channel_list=   map { $_->id  => 1 }
                                   $schema->resultset('Public::Channel')
                                           ->search( {
                                                    'business.config_section' => { 'IN' => \@channel_list },
                                                 },
                                                 {
                                                    join    => 'business',
                                                 } )->all;


            prepare_order( $existing_order, 'date', '>' ); # creates order 10 months old
            Test::XTracker::Mock::PSP->set_card_history( [ {'orderNumber' => 2900000,} ] ); # set the card to be  NOT new

            #order with statified conditions - order value <5000 & order older than 9 months
            my $order_data =  create_and_import_order( 2501, $customer, $existing_order, $channel, $sku  ); #created order with value  < 5000
            $order_data->{'data_order'}->_credit_hold_exception_channel_list(\%exception_channel_list);
            $got_results->{'passed_criteria'}->{$channel->name} = $order_data->{'data_order'}->_has_order_check_rule_passed($order_data->{'order'});
            cleanup_order( $order_data->{'order'}, $other_customer_id );


            #order with failed conditions -  there is no order older than 9 months.
            prepare_order( $existing_order, 'date', '<' ); #order 8 months old
            $order_data =  create_and_import_order( 2502, $customer, $existing_order, $channel, $sku  ); #created order with value  < 5000
            $got_results->{'failed_criteria'}->{$channel->name} = $order_data->{'data_order'}->_has_order_check_rule_passed($order_data->{'order'});
            cleanup_order( $order_data->{'order'}, $other_customer_id );

            #old cancelled order
            prepare_order( $existing_order, 'date', '>' );
            set_order_cancelled($existing_order, 1 ); #set the order as cancelled
            #create new order
            $order_data =  create_and_import_order( 2503, $customer, $existing_order, $channel, $sku  ); #created order with value  < 5000
            $got_results->{'cancelled_criteria'}->{$channel->name} = $order_data->{'data_order'}->_has_order_check_rule_passed($order_data->{'order'});
            #my $tt =$order_data->{'order'};
            cleanup_order( $order_data->{'order'}, $other_customer_id );


            #threshold values test
            prepare_order( $existing_order, 'date', '>' ); #order 9 months old
            $order_data =  create_and_import_order( 5001, $customer, $existing_order, $channel, $sku  ); #  < 5000
            $got_results->{'threshold_criteria'}->{$channel->name} = $order_data->{'data_order'}->_has_order_check_rule_passed($order_data->{'order'});
            cleanup_order( $order_data->{'order'}, $other_customer_id );

        } #end of foreach

        # create an order for the same customer in another channel to check a
        # fraud rule for customers ordering with a history over 9
        # months/multiple channels (CANDO-something)
        # 1. create an order for outner any channel
        # 2. fudge the date to make the order 'old'
        # 3. create an order on a different channel
        # 4. make sure we get the expected results

        FRAUD_RULE_TEST: {

            my $nap_channel = Test::XTracker::Data->nap_channel();
            my $out_channel = Test::XTracker::Data->out_channel();

            SKIP: {
                skip "FRAUD_RULE_TEST - Because Outnet Channel is NOT enabled on this DC", 1        if ( !$out_channel->is_enabled );

                my $nap_customer = $old_order->{ $nap_channel->id }->{'customer'};
                my $out_customer = $old_order->{ $out_channel->id }->{'customer'};

                my $other_nap_customer_id = create_unmatchable_customer( $nap_channel->id );
                my $other_out_customer_id = create_unmatchable_customer( $out_channel->id );

                my $out_order = create_and_import_order(
                    2505,
                    $out_customer,
                    $old_order->{ $out_channel->id }->{order},
                    $out_channel,
                    $old_order->{ $out_channel->id }->{sku},
                );
                prepare_order( $out_order->{order}, 'date', '>' );

                my $nap_order = create_and_import_order(
                    2504,
                    $nap_customer,
                    $old_order->{ $nap_channel->id }->{order},
                    $nap_channel,
                    $old_order->{ $nap_channel->id }->{sku},
                );
                $out_order->{order}->discard_changes;
                $got_results->{across_channel}{ $nap_channel->name } =
                    $out_order->{data_order}
                        ->_has_order_check_rule_passed($out_order->{order});
                cleanup_order( $nap_order->{'order'}, $other_nap_customer_id );
                cleanup_order( $out_order->{'order'}, $other_out_customer_id );

                note "Testing Order Check Rule across channels \n";
                eq_or_diff($got_results->{'across_channel'}, $expected_order_check_rule->{'across_channel'}, 'Order Check Rule Across channel');
            };
        }

        note "TESTING Order Check Rule  For Satisfied Condition \n";
        eq_or_diff($got_results->{'passed_criteria'}, $expected_order_check_rule->{'passed_criteria'},'Order Check Rule for Satisfied condition');

        note "Testing Order Check rule For failed Conditions \n";
        eq_or_diff($got_results->{'failed_criteria'}, $expected_order_check_rule->{'failed_criteria'},'Order Check Rule for Failed condition');

        note "Testing Order Check Rule for cancelled order \n";
        is_deeply($got_results->{'cancelled_criteria'}, $expected_order_check_rule->{'failed_criteria'},'Order Check Rule For Cancelled order');

        note "Testing Order Check Rule for Threshold values \n";
        is_deeply($got_results->{'threshold_criteria'}, $expected_order_check_rule->{'failed_criteria'},'Order Check Rule For Threshold values');
    };
}



sub _test__is_payment_card_new_subroutine {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test__is_payment_card_new_subroutine", 1 if (!$oktodo);

        note "TESTING Order Check Rule  For Satisfied Condition \n";


        my $got_results = {};
        foreach my $channel ( @channels ) {
            my $other_customer_id = create_unmatchable_customer( $channel->id );

            my $existing_order = $old_order->{$channel->id}->{'order'};
            my $customer       = $old_order->{$channel->id}->{'customer'};
            my $sku            = $old_order->{$channel->id}->{'sku'};
            my @channel_list   = keys %{$old_order->{$channel->id}->{'channel_list'}};

            my %exception_channel_list=   map { $_->id  => 1 }
                                   $schema->resultset('Public::Channel')
                                           ->search( {
                                                    'business.config_section' => { 'IN' => \@channel_list },
                                                 },
                                                 {
                                                    join    => 'business',
                                                 } )->all;

            #create a new order with same card
            prepare_order( $existing_order, 'date', '>' );
            Test::XTracker::Mock::PSP->set_card_history( [ {'orderNumber' => $existing_order->order_nr,} ] );
            my $order_data = create_and_import_order( 2500, $customer, $existing_order, $channel, $sku  ); #created order with value  < 5000
            my $payment =$order_data->{'data_order'}->_find_card_payment($order_data->{'order'});
            #mock the hashes
            $order_data->{'data_order'}->_payment_card($payment);
            $order_data->{'data_order'}->_credit_hold_exception_channel_list(\%exception_channel_list);
            $got_results->{'failed_criteria'}->{$channel->name} = $order_data->{'data_order'}->_is_payment_card_new($order_data->{'order'});
            cleanup_order( $order_data->{'order'}, $other_customer_id ); #clean up order once it is done

            #test with no card history => card is new
            prepare_order( $existing_order, 'date', '>' );
            Test::XTracker::Mock::PSP->set_card_history( [ {} ] );
            $order_data = create_and_import_order( 2500, $customer, $existing_order, $channel, $sku  );
            #populate hash
            $order_data->{'data_order'}->_credit_hold_exception_channel_list(\%exception_channel_list);
            $payment = $order_data->{'data_order'}->_find_card_payment($order_data->{'order'});
            #mock the hashes
            $order_data->{'data_order'}->_payment_card($payment);
            $order_data->{'data_order'}->_credit_hold_exception_channel_list(\%exception_channel_list);
            $got_results->{'no_card_history'}->{$channel->name} = $order_data->{'data_order'}->_is_payment_card_new($order_data->{'order'});
            cleanup_order( $order_data->{'order'}, $other_customer_id );

        }

        note "Testing Card Check Rule with Card History \n";
        is_deeply($got_results->{'failed_criteria'}, $expected_card_check_rule->{'failed_criteria'}, 'Card check rule with history');

        note "Testing Card Check Rule with no card history \n";
        is_deeply($got_results->{'no_card_history'}, $expected_card_check_rule->{'no_card_history'}, 'Card check rule with no history');


    };
}

sub _test__count_address_in_uncancelled_for_customer_subroutine {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test__has_order_check_rule_passed_subroutine", 1 if (!$oktodo);

        note "TESTING Order Check Rule  For Satisfied Condition \n";

        my $got_results={};
        foreach my $channel ( @channels ) {
            my $existing_order = $old_order->{$channel->id}->{'order'};
            my $customer       = $old_order->{$channel->id}->{'customer'};
            my $sku            = $old_order->{$channel->id}->{'sku'};
            my @channel_list   = keys %{$old_order->{$channel->id}->{'channel_list'}};

            #making sure there are no old orders for this customer
            $customer->orders->update( { order_status_id => $ORDER_STATUS__CANCELLED } );
            $customer->discard_changes;

            prepare_order( $existing_order, 'date', '=' );

            my $order_data1 = create_and_import_order( 2500, $customer, $existing_order, $channel, $sku  );
            my $shipment = $order_data1->{'order'}->shipments->first;
            my @list;
            push (@list, $customer->id);
            push (@list, $order_data1->{'order'}->customer_id);
            #should return 1
            $got_results->{'same_address'}->{$channel->name} = $shipment->count_address_in_uncancelled_for_customer({customer_list => \@list});

#           $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__CANCELLED });
            #create a new order with same customer id and shipping address
            my $order_data = create_and_import_order( 2500, $customer, $existing_order, $channel, $sku  );
            $shipment = $order_data->{'order'}->shipments->first;
            push(@list, $order_data->{'order'}->customer_id);
            #should return 2
            $got_results->{'count'}->{$channel->name} = $shipment->count_address_in_uncancelled_for_customer({customer_list => \@list});


            #create new order with new customer id
            my $new_customer_id = create_unmatchable_customer( $channel->id );
            my $other_customer = $schema->resultset('Public::Customer')->find( $new_customer_id);
            $order_data = create_and_import_order( 2500, $other_customer, $existing_order, $channel, $sku  );
            @list = ();
            push (@list, $new_customer_id);
            $shipment = $order_data->{'order'}->shipments->first;
            $got_results->{'new_address'}->{$channel->name} = $shipment->count_address_in_uncancelled_for_customer({customer_list => \@list});
        }

        note "Testing Address count with same shipping address and customer id\n";
        is_deeply($got_results->{'same_address'}, $expected_address_check_rule->{'same_address'},'Address check rule with similar shipping address');

        note "Testing Address count with cancelled shipping order\n";
        is_deeply($got_results->{'count'}, $expected_address_check_rule->{'address_count'},'Address Check rule with cancelled shipping address');

        note "testing Address count with new customer id and same shipping address";
        is_deeply($got_results->{'new_address'}, $expected_address_check_rule->{'same_address'},'Address Check rule with New customer id');

    };
}


sub _test__process_fraud_exception_subroutine {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test__process_fraud_exception_subroutine", 1 if (!$oktodo);

        note "TESTING Fraud Check Rule\n";
        #get me channel id for nap

        my @channel_list = ('NAP');
        my $channel = $schema->resultset('Public::Channel')
                                           ->search( {
                                                    'business.config_section' => { 'IN' => \@channel_list },
                                                 },
                                                 {
                                                    join    => 'business',
                                                 } )->first;


        my $existing_order = $old_order->{$channel->id}->{'order'};
        my $customer       = $old_order->{$channel->id}->{'customer'};
        my $sku            = $old_order->{$channel->id}->{'sku'};

        # create a new order with same card
        prepare_order( $existing_order, 'date', '>' );
        my $order_data = create_and_import_order( 2500, $customer, $existing_order, $channel, $sku  ); #created order with value  < 5000
        my $shipment = $order_data->{'order'}->shipments->first;

        $order_data->{'data_order'}->_fraud_exception( {
                                                       'credit_hold_exception' =>  {
                                                                     'hotlist_flag' => 1,
                                                                      'financewatch_flag' =>1,
                                                                      'ccheck_flag' => 1,
                                                                      'chold_flag'  => 1,
                                                                      }
                                                            });

        my $rating = 10;
        $rating = $order_data->{'data_order'}->_process_fraud_exception($rating, $order_data->{'order'}, $shipment);
        cmp_ok( $rating, '==', 10 ,"Fraud check was not statisfied");


        $order_data->{'data_order'}->_fraud_exception( {
                                                       'credit_hold_exception' =>  {
                                                                      'hotlist_flag' => 0,
                                                                      'financewatch_flag' => 0,
                                                                      'ccheck_flag' => 0,
                                                                      'chold_flag'  => 0,
                                                                      }
                                                            });

        no warnings "redefine";
        ## no critic(ProtectPrivateVars)
        *XT::Data::Order::_is_payment_card_new = \&__is_payment_card_new;
        *XT::Data::Order::_has_order_check_rule_passed = \&__has_order_check_rule_passed;
        *XTracker::Schema::Result::Public::Shipment::count_address_in_uncancelled_for_customer = \&__count_address_in_uncancelled_for_customer;
        use warnings "redefine";

        $rating = 10;
        $rating = $order_data->{'data_order'}->_process_fraud_exception($rating, $order_data->{'order'}, $shipment);
        cmp_ok( $rating, '==', 1 ,"Fraud check was statisfied");

        };
}

1;

sub __is_payment_card_new {

    return 0;
}

sub __has_order_check_rule_passed {

    return 1;
}

sub __count_address_in_uncancelled_for_customer {

    return 2;
}

sub prepare_order {
    my $order       = shift;
    my $action      = shift || '';
    my $parameter   = shift;

    die "prepare_order: Invalid action '$action'\n"
        unless $action =~ /date|cancelled|hotlist|finance_watch|credit_check|credit_hold|^$/;

    # Set the date.
    if ( $action eq 'date' ) {
        set_order_date( $order, $parameter );
    } else {
        set_order_date( $order, '=' );
    }

    # Order hotlist.
    if ( $action eq 'hotlist' ) {
        set_order_hotlist( $order, 1 );
    } else {
        set_order_hotlist( $order, 0 );
    }

    # Order finance watch.
    if ( $action eq 'finance_watch' ) {
        set_order_finance_watch( $order, 1 );
    } else {
        set_order_finance_watch( $order, 0 );
    }

    set_order_credit_check( $order, 0, $ORDER_STATUS__ACCEPTED );


}

sub cleanup_order {
    my ( $order, $other_customer_id ) = @_;

    note sprintf(
        'Munging order.id=%d, channel=%s, customer.id=%d',
            $order->id,
            $order->channel->name,
            $order->customer->id
    );

    # Clear any customer flags.
    $order->customer->customer_flags->search( { flag_id => $FLAG__FINANCE_WATCH } )->delete;
    $order->customer->update( { credit_check => undef } );

    # Move the order to the other customer.
    $order->update( { customer_id => $other_customer_id } );

}

sub create_unmatchable_customer {
    my ($channel_id) = @_;

    my $i = 0;
    my $rstring  = String::Random->new(max => 15);

    my $customer_id;
    do {
        if ($i > 10) {
            ok (0,'Failed to create an unmatchable customer');
            plan skip_all => 'must rewrite create_unmatchable_customer';
        }
        $i++;
        my $email = $rstring->randregex('\w\w\w\w\w\w\w\w\w\w\w').'@gmail.com';
        note("Random email $email");
        $customer_id = Test::XTracker::Data->create_test_customer(
            channel_id => $channel_id, email => $email);
    } until  scalar(@{match_customer ($dbh, $customer_id) }) == 0;

    return $customer_id;
}

sub create_and_import_order {
    my ( $unit_price, $customer, $existing_order, $channel, $sku, $new_address ) = @_;
    my $order_xml_data;

    my $address = $existing_order->shipments->first->shipment_address;
    my $next_preauth = Test::XTracker::Data->get_next_preauth( $dbh );

    my $order_args = [
            {
                customer    => {
                    id              => $customer->is_customer_number,
                    currency        => config_var('Currency', 'local_currency_code'),
                    email           => $customer->email,
                    address_line_1  => ( $new_address ? 'X' : '' ) . $address->address_line_1,
                    address_line_2  => ( $new_address ? 'X' : '' ) . $address->address_line_2,
                    address_line_3  => ( $new_address ? 'X' : '' ) . $address->address_line_3,
                    town_city       => ( $new_address ? 'X' : '' ) . $address->towncity,
                    county          => ( $new_address ? 'X' : '' ) . $address->county,
                    postcode        => ( $new_address ? 'X' : '' ) . $address->postcode,
                    country         => $address->country_table->code,
                },
                order       => {
                    channel_prefix => $channel->business->config_section,
                    tender_type => 'Card',
                    shipping_price => 0,
                    shipping_tax => 0,
                    shipping_duties => 0,
                    # amount plus standard shipping costs which are in the XML Template
                    tender_amount => $unit_price,# 10.00 + 2.00,
                    pre_auth_code => $next_preauth,
                    items   => [
                        {
                            #sku         => $pids->{nap}{pids}[0]{sku},
                            sku         => $sku,
                            unit_price  => $unit_price,
                            tax         => 0.00,
                            duty        => 0.00,
                        },
                    ],
                },
            },
        ];

    note Dumper($order_args);
    # parse an order
    my $parsed      = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);
    my $data_order  = $parsed->[0];

    # part digest the parsed order
    my $order   = $data_order->digest;

    $order->discard_changes;

    $order_xml_data->{'data_order'} = $data_order;
    $order_xml_data->{'order'} = $order;

    return $order_xml_data;
}

sub flags_contain {
    my ($flags, $description) = @_;

    foreach my $order_flag_id (keys(%$flags)) {
        return 1 if $flags->{$order_flag_id}->{description} eq $description;
    }

    return;
}

sub set_order_date {
    my ( $order, $offset )  = @_;

    my $date;

    if ( $offset eq '<' ) {
        $date = DateTime->now->subtract( months => 8 );

    } elsif ( $offset eq '>' ) {

        $date = DateTime->now->subtract( months => 10 );

    } elsif ( $offset eq '=' ) {

        $date = DateTime->now;

    } else {

        fail "set_order_date: Invaid type '$offset', expected <, > or =";

    }
    $order->update( { date => $date } )->discard_changes
        if $date;


}

#   Cancelled
sub set_order_cancelled {
    my ( $order, $enabled, $new_status ) = @_ ;

    if ( $enabled ) {

        $order->update( { order_status_id => $ORDER_STATUS__CANCELLED } )->discard_changes;

    } else {

        $order->update( { order_status_id => $new_status } )->discard_changes;

    }

}

#   Hotlist
sub set_order_hotlist {
    my ( $order, $enabled ) = @_;

    if ( $enabled ) {

        $order->add_flag_once( $FLAG__FRAUD_EMAIL );

    } else {

        $order->order_flags->search( { flag_id => $FLAG__FRAUD_EMAIL } )->delete;

    }

}

#   Finance Watch
sub set_order_finance_watch {
    my ( $order, $enabled ) = @_;

    if ( $enabled ) {

        set_order_finance_watch( $order, 0 );
        $order->customer->customer_flags->create( { flag_id => $FLAG__FINANCE_WATCH } );

    } else {

        $order->customer->customer_flags->search( { flag_id => $FLAG__FINANCE_WATCH } )->delete;

    }

}

#   Credit Check
sub set_order_credit_check {
    my ( $order, $enabled, $new_status ) = @_;

    if ( $enabled ) {

        $order->update( { order_status_id => $ORDER_STATUS__CREDIT_CHECK } );
        $order->customer->update( { credit_check => DateTime->now } );

    } else {

        $order->update( { order_status_id => $new_status } );
        $order->customer->update( { credit_check => undef } );

    }

}

#   Credit Hold
sub set_order_credit_hold {
    my ( $order, $enabled, $new_status ) = @_;

    if ( $enabled ) {

        $order->set_status_credit_hold( $APPLICATION_OPERATOR_ID );

    } else {

        $order->change_status_to( $new_status, $APPLICATION_OPERATOR_ID );

    }

}


# remove test expectations
sub _remove_expectations {
    my ( $channels, $expect )   = @_;

    # get channels we have
    my %have_channel_names  = map { $_->name => 1 } @{ $channels };

    foreach my $test ( keys %{ $expect } ) {
        foreach my $channel_name ( keys %{ $expect->{ $test } } ) {
            if ( !exists( $have_channel_names{ $channel_name } ) ) {
                delete $expect->{ $test }{ $channel_name };
            }
        }
    }

    return;
}
