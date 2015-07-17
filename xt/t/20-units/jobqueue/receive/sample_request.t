#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;

use Data::Dump qw(pp);

use Test::MockObject;

use XTracker::Config::Local         qw{ config_var };
use XTracker::Constants             qw{ :application };
use XTracker::Constants::FromDB     qw{ :channel :recommended_product_type :delivery_item_status };
use XTracker::Logfile               qw{ xt_logger };


BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');

    use_ok("XT::JQ::DC::Receive::Sample::Request");
}

my $fake_job    = _setup_fake_job();

# get a schema to query
my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

#--------------- Run TESTS ---------------

_test_request( $schema, $fake_job, 1 );

#--------------- END TESTS ---------------

note "t/20-units/jobqueue/receive/sample_request.t: done testing at ".localtime();

done_testing;

#----------------------- Test Functions -----------------------

sub _test_request {
    my $schema      = shift;
    my $fake_job    = shift;

    my @channels    = $schema->resultset('Public::Channel')->search( {'is_enabled'=>1}, { order_by => 'id ' } );
    my @payload;
    my $tmp;
    my @copy;
    my @products;

    SKIP: {
        skip "_test_request",1       if (!shift);

        my @var_ids;

                CHANNEL:
        # get a product for each Sales Channel
        foreach my $channel ( @channels ) {

            note "On Channel: (", $channel->id, ") " . $channel->name;
            my (undef,$pids) = Test::XTracker::Data->grab_products( {
                channel_id => $channel->id,
                how_many => 1,
            } );
            my $product = $pids->[0]->{product};
            push @products, $product;

            # clear stock stuff for each variant for the product
            note "Using PID: ".$product->id.", for Channel: (".$channel->id.") ".$channel->name;
            my @variants    = $product->variants->all;
            foreach my $variant ( @variants ) {
                my $qty = $schema->resultset('Public::Quantity')->search( { variant_id => $variant->id } );
                $qty->delete if ( defined $qty );
                # clear any pending stock transfers to the sample room
                my $st  = $schema->resultset('Public::StockTransfer')->search( { variant_id => $variant->id } );
                $st->update( { status_id => 3 } ) if ( defined $st );     # update them to 'Cancelled' status
                # clear any deliveries for variant
                my @ldisoi  = $schema->resultset('Public::LinkDeliveryItemStockOrderItem')
                                        ->search(
                                            {
                                                'stock_order_item.variant_id'   => $variant->id,
                                                'delivery_item.status_id'       => { '<' => $DELIVERY_ITEM_STATUS__COMPLETE },
                                            },
                                            {
                                                join    => [ qw( stock_order_item delivery_item ) ],
                                            }
                                        )->all;
                # update all current delivery items for variant to Complete
                map { $_->delivery_item->update( { status_id => $DELIVERY_ITEM_STATUS__COMPLETE } ) } @ldisoi;

                # maintain a list of variant ids
                push @var_ids, $variant->id;
            }
        }

        # insert an outfit product from the wrong channel
        foreach ( 0..$#channels ) {
                        next unless defined $products[$_];
            push @payload, {
                            channel_id      => $channels[ $_ ]->id,
                            product_id      => $products[ $_ ]->id,
                            operator_id     => $APPLICATION_OPERATOR_ID,
                        };
        }
        $tmp    = create_and_execute_job( $fake_job, \@payload );

        my $stck_xfer_rs    = $schema->resultset('Public::StockTransfer')->search( { 'me.variant_id' => { 'IN' => \@var_ids } }, { order_by => 'me.id DESC', rows => scalar( @products ) } );
        my @stck_xfers      = reverse $stck_xfer_rs->all;

        foreach ( 0..$#channels ) {
                        next unless defined $products[$_];
            $tmp    = $stck_xfers[ $_ ];
            note "Checking request for Channel: (".$channels[ $_ ]->id.") ".$channels[ $_ ]->name;
            note "Choose SKU: ".$tmp->variant->sku;
            cmp_ok( $tmp->variant->product_id, '==', $products[ $_ ]->id, "Stock Transfer Variant's Product Id as expected" );
            cmp_ok( $tmp->channel_id, '==', $channels[ $_ ]->id, "Stock Transfer Channel Id as expected" );
        }
    };
}

#--------------------------------------------------------------

# Creates a job
sub create_job {
    my ( $arg ) = @_;

    my $job = new_ok( 'XT::JQ::DC::Receive::Sample::Request' => [ payload => $arg ] );

    return $job;
}

# Creates and executes a job
sub create_and_execute_job {
    my ( $fake_job, $arg ) = @_;

    eval {
        my $job = create_job( $arg );
        $job->do_the_task( $fake_job );
    };
    if ( $@ ) {
        return $@
    }

    return;
}

# setup a fake TheShwartz::Job
sub _setup_fake_job {

    my $fake    = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );

    return $fake;
}

# This is here to avoid breakage in XT::Common::JQ::Worker::jq_logger
sub logger {
    return xt_logger('XTracker::Comms::DataTransfer');
}
