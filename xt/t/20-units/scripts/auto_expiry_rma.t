#!/usr/bin/env perl


use NAP::policy "tt",     'test';

=head2 RMA Returns

cando-109 :

=cut

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use DateTime;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :return_item_status
                                        :return_type
                                        :return_status
                                        :renumeration_type
                                        :shipment_item_status
                                        :shipment_status
                                        :reservation_status
                                        :renumeration_type
                                        :renumeration_status
                                    );
use XTracker::Script::Returns::AutoExpireRMA;

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();
my $amq = $domain->msg_factory();

#check the house keeping script exists
my $script = config_var('SystemPaths', 'script_dir').'/housekeeping/returns/auto_expire_rma.pl';
my $file_check = 0;

if (-e $script) {
    $file_check = 1 ;
}
#check existence of script
is($file_check, 1, " Script $script Exists");

#----------------------------------------------------------
_test_build_rma_expire_rs($schema, $domain, $amq, 1);
_test_return( $schema, $domain, $amq, 1 );
_test_config_section();
#----------------------------------------------------------

done_testing();

=head2 _test_build_rma_expire_rs

This test builds up data and test the following:
    1) creates 3 orders with return having 2 return_items
    2) make sure above returns has return status log date 41 days old
    3) create 2 orders with return having 2 return items ( return_status_log date is current date)
    4) call rma_expire_rs
    5) among all the above 5 order we expect 3 orders to be return by _build_rma_expire_rs
    6) test the count of return in the resulttset is 3
    7) compare the return id's from the resultset is as expected

=cut

sub _test_build_rma_expire_rs {
     my ( $schema, $domain, $amq, $oktodo )  = @_;

     SKIP: {
        skip "_test_build_rma_expire_rs", 1        if ( !$oktodo );

        note "in '_test_build_rma_expire_rs'";

        $schema->txn_do( sub {
            my $no_of_items = 2;
            my $lowest_day  = 41;

            note " **************** Testing _build_rma_expire_rs method ******\n";

            # create 3 orders with returns having return_status_log date as (current_date - 41 days)
            my $return_rs =  _create_orders_with_return(3, $no_of_items, $lowest_day);

            # create 2 order with returns having return_status_log date as current_date
            my $new_rs = _create_orders_with_return(2, $no_of_items);

            # Test _build_rma_expire_rs subroutine

            # put in array all the $return->ids from both recordset
            my @return_ids = ( keys (%{$return_rs}) ,  keys (%{ $new_rs}) );

            # instantiate AutoExpireRMA module
            my $autoExpireRMA = XTracker::Script::Returns::AutoExpireRMA->new();
            $autoExpireRMA->schema($schema);
            $autoExpireRMA->msg_factory($amq);
            $autoExpireRMA->lowest_day($lowest_day);

            # call method _build_rma_expire_rs
            my $rma_rs = $autoExpireRMA->rma_expire_rs();

            my $result_rs  = $rma_rs->search({'me.id' => { -in => \@return_ids } } );

            # check in total 5 returns are passed in
            is(scalar @return_ids, 5, "5 items are passed to Main Query");

            # returned recordset has  3 return_items
            is($result_rs->count, 3, "3 Return items are in RecordSet");

            # check 3 items returned returned are as expected
            my %expected_result =  map { $_ => 1} keys (%{ $return_rs});
            my %got_result = map {$_->id => 1}  $result_rs->all;
            is_deeply(\%got_result, \%expected_result, "Returm Items are as Expected" );

            # rollback changes
            $schema->txn_rollback();
        });
    };
}

=head2 _test_return

 This test creates an order with  return and calls AutoExpireRMA to check
 if returns/exchanges older than x months gets cancelled and return status
 gets updated appropirately

=cut
sub _test_return {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_return", 1        if ( !$oktodo );

        note "in '_test_return'";

        $schema->txn_do( sub {
            note "************* Test to check return with one return item for return ********** \n";
            my $no_of_items  = 1;
            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);

            #create a return
            my $return              = _create_return_or_exchange( $domain, $shipment, 'Return');

            # get some dates for the logs to test 'in_created_order' method
            my $today       = DateTime->now( time_zone => config_var('DistributionCentre', 'timezone') );
            my $future_date = $today->clone->add( days => 1, hours => 3, minutes => 2 );
            my $past_date   = $today->clone->subtract( days => 46, hours => 2, minutes => 5 );

            #check return status is awaiting return
            is($return->return_status_id, $RETURN_STATUS__AWAITING_RETURN, "Status is awaiting return");
            # check invoice is pending
            is($return->renumerations->first->renumeration_status_id, $RENUMERATION_STATUS__PENDING, "Renumeration status is pending");
            #update return_status_log
            $return->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose

            #run the script
            _run_script($return->id);
            $return->discard_changes();

            #check return_status is cancelled
            is($return->return_status_id, $RETURN_STATUS__CANCELLED, "Status is Cancelled return");
            #check renumeration status is cancelled
            is($return->renumerations->first->renumeration_status_id, $RENUMERATION_STATUS__CANCELLED, "Renumeration status is cancelled");
            #is($return->renumerations->first->renumeration_status_logs->search( {}, { order_by => 'id' } )->first->renumeration_status_id, $RENUMERATION_STATUS__CANCELLED, "Renumeration status is cancelled");

            #check all the return_items are cancelled as well
            cmp_ok($return->return_items->not_cancelled->count, '==', 0, "All return items are cancelled");
            #check returns notes is updated
            ok($return->return_notes->first->note =~ /RMA expired and automatically closed by system/, 'Returns Notes are updated');

            note "***********  Test to check with one return having 2 return items with one for return and other with status of putaway  ********\n";

            #create order with 2 items, one return and another putaway
            $no_of_items  = 2;
            ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);
            $return              = _create_return_or_exchange( $domain, $shipment, 'Return');

            # check invoice is pending
            is($return->renumerations->first->renumeration_status_id, $RENUMERATION_STATUS__PENDING, "Renumeration status is pending");

            $return->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose
            #udpate the status of one of the return_item to be putaway
            my @return_items =  $return->return_items->search( { }, { order_by => 'id' } );
            $return_items[0]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__PUT_AWAY } );

            _run_script($return->id);
            $return->discard_changes();

            #check renumeration status is still pending but renumeration_status_log has pre and post values
            my $renumeration = $return->renumerations->first;
            is($renumeration->renumeration_status_id, $RENUMERATION_STATUS__PENDING, "Renumeration status is pending");
            is($renumeration->renumeration_change_logs->first->pre_value, '200.00' ,"Renumeration change log pre value is correct");
            is($renumeration->renumeration_change_logs->first->post_value, '100.00' ,"Renumeration change log post value is correct");

            @return_items = $return->return_items->search( { }, { order_by => 'id' } );
            #check one of the return item status is cancelled
            is($return_items[1]->return_item_status_id, $RETURN_ITEM_STATUS__CANCELLED, "Status is Cancelled return");
            #check one of the return item status is putaway
            is($return_items[0]->return_item_status_id, $RETURN_ITEM_STATUS__PUT_AWAY, "Status is PutAway");
            #check return status is complete
            is($return->return_status_id, $RETURN_STATUS__COMPLETE, "Status is Complete return");
            #check notes is Returning Item 34301-027 has been automatically cancelled by the system
            my $sku = $return_items[1]->shipment_item->get_sku();
            ok($return->return_notes->first->note =~ /Returning Item $sku has been automatically cancelled by the system/, 'Returns Notes are updated');

            note "************* Test to check with an exchange item **************\n";
            #create an exchange
            $no_of_items  = 1;
            ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);
            my $exchange      = _create_return_or_exchange( $domain, $shipment, 'Exchange');

            $exchange->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose

            #check return status is awaiting return
            is($exchange->return_status_id, $RETURN_STATUS__AWAITING_RETURN, "Status is awaiting return");

            _run_script($exchange->id);
            $exchange->discard_changes();

            #check return_status is cancelled
            is($exchange->return_status_id, $RETURN_STATUS__CANCELLED, "Status is Cancelled return");
            #check all the return_items are cancelled as well
            cmp_ok($exchange->return_items->not_cancelled->count, '==', 0, "All return items are cancelled");
            #check returns notes is updated
            ok($exchange->return_notes->first->note =~ /RMA expired and automatically closed by system/, 'Returns Notes are updated');

            note "****** Test a return with 2 items ,one return item and the other QC - Rejected *********";
            $no_of_items  = 2;
            ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);
            $return              = _create_return_or_exchange( $domain, $shipment, 'Return' );

            $return->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose
            #udpate the status of one of the return_item to be Failed QC - Rejected
            @return_items =  $return->return_items->search( { }, { order_by => 'id' } );
            $return_items[0]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED } );

            #check Return has status Awaiting Return
            is($return->return_status_id, $RETURN_STATUS__AWAITING_RETURN, "Status is awaiting return");

            _run_script($return->id);
            $return->discard_changes();

            @return_items = $return->return_items->search( { }, { order_by => 'id' } );
            #check one of the return item status is cancelled
            is($return_items[1]->return_item_status_id, $RETURN_ITEM_STATUS__CANCELLED, "Status is Cancelled return");
            #check one of the return item status is Failed QC - Rejected
            is($return_items[0]->return_item_status_id, $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED , "Status is Failed QC - Rejected");
            #check return status is complete
            is($return->return_status_id, $RETURN_STATUS__COMPLETE, "Status is Complete return");
            #check notes is Returning Item 34301-027 has been automatically cancelled by the system
            $sku = $return_items[1]->shipment_item->get_sku();
            ok($return->return_notes->first->note =~ /Returning Item $sku has been automatically cancelled by the system/, 'Returns Notes are updated');

            note "******* Test a return with 2 items, one exchange and other booked in ******* ";
            $no_of_items  = 2;
            ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);
            $exchange      = _create_return_or_exchange( $domain, $shipment, 'Exchange' );

            $exchange->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose
            #udpate the status of one of the return_item to be Booked In

            $exchange->discard_changes();
            @return_items =  $exchange->return_items->search( { }, { order_by => 'id'});
            #$return_items[1]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN } );
            $return_items[1]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN } );
            $exchange->update( { return_status_id => $RETURN_STATUS__PROCESSING } );

            _run_script($exchange->id);
            $exchange->discard_changes();

            @return_items =  $exchange->return_items->search( { }, { order_by => 'id'});
            #check one of the return item status is cancelled
            is($return_items[0]->return_item_status_id, $RETURN_ITEM_STATUS__CANCELLED, "Status is Cancelled Exchange");
            #check one of the return item status is Booked In
            is($return_items[1]->return_item_status_id, $RETURN_ITEM_STATUS__BOOKED_IN , "Status is Booked In");
            #check return status is Processing
            is($return->return_status_id, $RETURN_STATUS__COMPLETE, "Status is Complete for return");

            # rollback changes
            $schema->txn_rollback();
        } );
    };
}
=head2 _test_config_section

This test build up data and test following
    * read config values for section "Returns_<channel_name>"
       and setting = auto_expire_return_days/ auto_expire_exchange days
    * update setting such as return days to be less than exchange days
    * call_build_auto_expiry_info method to build lowest_day
    * check lowest_day is equal to return_days
    * create an order with return having one item as returned and other as exchange
    * set return->return_status_log date to be <return days> old
    * invoke AutoExpireRMA module and check return got cancelled

    * repeat the above with exchange days to be less than return days
    * check as above
    * repeat for all channels

=cut

sub _test_config_section {
    # get a copy of the conifg
   my $config  = \%XTracker::Config::Local::config;

    my @channels = $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;
    my $setting_for_returns  = 'auto_expire_return_days';
    my $setting_for_exchange = 'auto_expire_exchange_days';

    note " ************* Testing lowest Day **********************";
    foreach my $channel ( @channels ) {
        my $section              = 'Returns_'.$channel->business->config_section;

        {
            $config->{$section}->{$setting_for_returns}  = 12;
            $config->{$section}->{$setting_for_exchange} = 19;

            my $autoExpireRMA = XTracker::Script::Returns::AutoExpireRMA->new();
            $autoExpireRMA->schema($schema);
            $autoExpireRMA->msg_factory($amq);
            $autoExpireRMA->_build_auto_expiry_info($config);

            # test lowest day is 12
            note "  FOR channel ". $channel->business->config_section."\n";
            cmp_ok($autoExpireRMA->lowest_day, '==', $config->{$section}->{$setting_for_returns}, "channel ". $channel->business->config_section. " for return has the Lowest Day - 12");

            #create a return with one exchange and return
            my $no_of_items  = 2;
            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items,$channel);

            my $exchange      = _create_return_or_exchange( $domain, $shipment, 'Exchange' );

            my $today       = DateTime->now( time_zone => 'local' );
            my $past_date   = $today->clone->subtract( days => 12 );
            $exchange->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose

            my @return_items =  $exchange->return_items->search( { }, { order_by => 'id' } );
            $return_items[0]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN, return_type_id => $RETURN_TYPE__RETURN } );
            $exchange->discard_changes();

            _run_script($exchange->id,$autoExpireRMA->lowest_day, $autoExpireRMA);
            $exchange->discard_changes();

            @return_items =  $exchange->return_items->search( { }, { order_by => 'id' } );
            #check one of the return item status is cancelled
            is($return_items[0]->return_item_status_id, $RETURN_ITEM_STATUS__CANCELLED, "Status is Cancelled for Returned item");
            #check one of the return item status is awaiting return
            is($return_items[1]->return_item_status_id, $RETURN_ITEM_STATUS__AWAITING_RETURN , "Status is Awating return  for Exchanged item ");
            #check return status is Awaiting Return
            is($exchange->return_status_id, $RETURN_STATUS__AWAITING_RETURN, "Status is Awaiting Return for return");
            #check return notes
            my $sku = $return_items[0]->shipment_item->get_sku();
            ok($exchange->return_notes->first->note =~ /Returning Item $sku has been automatically cancelled by the system/, 'Returns Notes are updated');
        }

        {
            $config->{$section}->{$setting_for_returns}  = 10;
            $config->{$section}->{$setting_for_exchange} = 7;
            my $autoExpireRMA = XTracker::Script::Returns::AutoExpireRMA->new();
            $autoExpireRMA->schema($schema);
            $autoExpireRMA->msg_factory($amq);
            $autoExpireRMA->_build_auto_expiry_info();

            cmp_ok($autoExpireRMA->lowest_day, '==', $config->{$section}->{$setting_for_exchange}, "Channel ". $channel->business->config_section. " for exchange has Lowest Day - 7");

            note "  FOR channel ". $channel->business->config_section."\n";

            #create a return with one exchange and return
            my $no_of_items  = 2;
            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items, $channel);
            my $exchange      = _create_return_or_exchange( $domain, $shipment, 'Exchange' );

            my $today       = DateTime->now( time_zone => 'local' );
            my $past_date   = $today->clone->subtract( days => 7 );
            $exchange->return_status_logs->update ( { date => $past_date} ); #this would update date for all the entries, we do not care for testing purpose

            my @return_items =  $exchange->return_items->search( { }, { order_by => 'id' } );
            $return_items[0]->update ( { return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN, return_type_id => $RETURN_TYPE__RETURN } );
            $exchange->discard_changes();

            _run_script($exchange->id,$autoExpireRMA->lowest_day, $autoExpireRMA);
            $exchange->discard_changes();

            @return_items =  $exchange->return_items->search( { }, { order_by => 'id' } );
            #check one of the return item status is awating return
            is($return_items[0]->return_item_status_id, $RETURN_ITEM_STATUS__AWAITING_RETURN, "Status is Awating return for Exchanged item");
            #check one of the return item status is cancelled
            is($return_items[1]->return_item_status_id, $RETURN_ITEM_STATUS__CANCELLED , "Status is cancelled for returned item ");
            #check return status is Awaiting Return
            is($exchange->return_status_id, $RETURN_STATUS__AWAITING_RETURN, "Status is Awaiting Return for return");
            #check return notes
            my $sku = $return_items[1]->shipment_item->get_sku();
            ok($exchange->return_notes->first->note =~ /Returning Item $sku has been automatically cancelled by the system/, 'Returns Notes are updated');
        }

        # move them out of the way for the next loop
        $config->{$section}->{$setting_for_returns}  = 99;
        $config->{$section}->{$setting_for_exchange} = 99;
    }
}
#-------------------------------------------------------------------------------------
# by default this will create a Dispatched Order
sub _create_an_order {
    my ( $num_pids,$channel )  = @_;

    my $schema  = Test::XTracker::Data->get_schema();

    $num_pids   ||= 1;
    $channel    ||= Test::XTracker::Data->channel_for_nap;

    my ( $forget, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => $num_pids,
            #how_many_variants => 4,
            channel     => $channel,
            ensure_stock_all_variants => 1,
            force_create => 1,
    } );

    my $base    = {
            channel_id => $channel->id,
            shipping_charge => 10,
            tenders => [ { type => 'card_debit', value => 10 + ( 100 * $num_pids ) } ],
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [ map { price => 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
        } );

    my $shipment    = $order->get_standard_class_shipment();
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id' } );

    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr );
    note "Shipment Created: ".$shipment->id;
    return ( $order, $shipment, \@ship_items, $pids, $channel );
}

# create a Return/Exchange for a Shipment
sub _create_return_or_exchange {
    my ( $domain, $shipment, $type )   = @_;

    $type = ( $type =~ /return/gi ) ? 'Return' : 'Exchange';

    my $return = $domain->create(
        {
            operator_id    => $APPLICATION_OPERATOR_ID,
            shipment_id    => $shipment->id,
            pickup         => 0,
            refund_type_id => $RENUMERATION_TYPE__STORE_CREDIT,

            #refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
            return_items => {
                map {
                    $_->id => {
                        type             => $type,
                        reason_id        => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                        exchange_variant => $_->variant_id,
                      }
                } $shipment->shipment_items->all
            }
        }
    );

    note "Return1 RMA/Id: " . $return->rma_number."/".$return->id;
    return $return->discard_changes;
}

=head2 _create_orders_with_return

 Create X no. of orders with return having Y no. of return_items

=cut
sub _create_orders_with_return {
    my $no_of_orders           = shift || 1;
    my $no_of_items            = shift || 2;
    my $return_status_log_days = shift;

    my $past_date;
    my $return_hash = ();

    if( $return_status_log_days ) {
        # get some dates for the logs to test 'in_created_order' method
         my $today  = DateTime->now( time_zone => config_var('DistributionCentre', 'timezone') );
         $past_date = $today->clone->subtract( days => $return_status_log_days );
    }

    for ( 1..$no_of_orders)  {
        my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);

        my $return = _create_return_or_exchange( $domain, $shipment, 'Return');

        if( $return_status_log_days ) {
            # update return_status_log
            $return->return_status_logs->update ( { date => $past_date} );
        }
        $return_hash->{$return->id} = $return;
    }
    return $return_hash;
}

sub _run_script {
    my $return_id = shift;
    my $lowest_day = shift || 45 ;
    my $autoExpireRMA = shift;

    $schema->storage->debug(1);
    my $return_rs = $schema->resultset('Public::Return')->search(
        { 'me.id' => $return_id },
        {
            join => [
                'return_status_logs',
                { 'shipment' => { 'link_orders__shipment' => 'orders' } },
            ],
            '+select' => [ 'return_status_logs.date', 'orders.channel_id' ],
            '+as'     => [ 'rsl_date',                'channel_id' ],
        }
    );

    $schema->storage->debug(0);
    #XTracker::Script::Returns::AutoExpireRMA->new->invoke();
    $autoExpireRMA = XTracker::Script::Returns::AutoExpireRMA->new() if (!defined $autoExpireRMA);
    $autoExpireRMA->schema($schema);
    $autoExpireRMA->msg_factory($amq);
    $autoExpireRMA->lowest_day($lowest_day);
    $autoExpireRMA->rma_expire_rs($return_rs);
    $autoExpireRMA->invoke();
    return $autoExpireRMA;
}
