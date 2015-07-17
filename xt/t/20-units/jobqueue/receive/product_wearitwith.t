#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;

use Data::Dump qw(pp);

use Test::MockObject;

use XTracker::Config::Local         qw{ config_var };
use XTracker::Constants             qw{ :application };
use XTracker::Constants::FromDB     qw{ :channel :recommended_product_type };
use XTracker::Logfile               qw{ xt_logger };
use Test::XTracker::Data;

use Test::XTracker::RunCondition database => 'full';

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');

    use_ok("XT::JQ::DC::Receive::Product::WearItWith");
}

my $fake_job    = _setup_fake_job();

# get a schema to query
my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

#--------------- Run TESTS ---------------

_test_wearitwith( $schema, $fake_job, 1 );

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_wearitwith {
    my $schema      = shift;
    my $fake_job    = shift;

    my $data        = _define_dbic_data( $schema );
    my $channels    = $data->{channels}();
    my $payload;
    my @payload;
    my $tmp;
    my @copy;

    SKIP: {
        skip "_test_wearitwith",1       if (!shift);

        $schema->txn_do( sub {
            my $products    = $data->{products}( $channels->[0] );
            my $othr_pids   = $data->{products}( $channels->[1] );
            my $master_pid  = pop @{ $products };
            my $rp_rs       = $schema->resultset('Public::RecommendedProduct')
                                        ->search( {
                                                    product_id  => $master_pid->id,
                                                    channel_id  => $channels->[0],
                                                    type_id     => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION,
                                                  } );

            note "Using Outfit Product: ".$master_pid->id;
            # clear out recommended product table for master pid
            $master_pid->recommended_master_products->delete;

            # insert an outfit product from the wrong channel
            $payload    = {
                    action          => 'insert',
                    outfit_product  => $master_pid->id,
                    product         => $products->[0]->id,
                    channel_id      => $channels->[1],
                    sort_order      => 1,
                    slot            => 1,
                };
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            like($tmp,qr/Product $payload->{outfit_product} not found on channel/,"Can't insert an Outfit Product for Wrong Channel: ".$payload->{outfit_product});

            # insert a recommended product from the wrong channel
            $payload->{outfit_product}  = $othr_pids->[0]->id;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            like($tmp,qr/Product $payload->{product} not found on channel/,"Can't insert a Recommended Product for Wrong Channel: ".$payload->{product});

            # now everything is on the correct channel
            $payload    = {
                    outfit_product  => $master_pid->id,
                    channel_id      => $channels->[0],
                    sort_order      => 1,
                };

            # insert a product
            $payload->{action}  = 'insert';
            $payload->{product} = $products->[0]->id;
            $payload->{slot}    = 1;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            is($tmp,undef,"Job Executed");
            $tmp    = _get_prod_back( $rp_rs, $payload );
            cmp_ok($tmp,"==",1,"Inserted a Product: ".$payload->{product});

            # insert the same product again
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            is($tmp,undef,"Inserted the Same Product Again OK");

            # delete a product
            $payload->{action}  = 'delete';
            $payload->{product} = $products->[1]->id;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            is($tmp,undef,"Handled Deleting a non-existent Product");

            $payload->{product} = $products->[0]->id;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            is($tmp,undef,"Deleted a Product");
            $tmp    = _get_prod_back( $rp_rs, $payload );
            cmp_ok($tmp,"==",0,"Deleted a Product: ".$payload->{product});

            # insert a few products
            $payload->{action}  = 'insert';
            push @payload, { %$payload };
            $payload->{product} = $products->[1]->id;
            $payload->{slot}    = 2;
            push @payload, { %$payload };
            $payload->{product} = $products->[2]->id;
            $payload->{slot}    = 3;
            push @payload, { %$payload };
            $tmp    = create_and_execute_job( $schema, $fake_job, \@payload );
            is($tmp,undef,"Inserted Multiple Products");
            # check they are all there
            $tmp    = _get_prod_back( $rp_rs, $payload[0] );
            cmp_ok($tmp,"==",1,"Inserted Multi Products: ".$payload[0]->{product});
            $tmp    = _get_prod_back( $rp_rs, $payload[1] );
            cmp_ok($tmp,"==",1,"Inserted Multi Products: ".$payload[1]->{product});
            $tmp    = _get_prod_back( $rp_rs, $payload[2] );
            cmp_ok($tmp,"==",1,"Inserted Multi Products: ".$payload[2]->{product});
            @copy   = @payload;

            # delete a product then insert a new one in it's slot
            @payload    = ();
            $payload->{action}  = 'delete';
            $payload->{product} = $products->[2]->id;
            push @payload, { %$payload };
            $payload->{action}  = 'insert';
            $payload->{product} = $products->[5]->id;
            $payload->{slot}    = 3;
            push @payload, { %$payload };
            $tmp    = create_and_execute_job( $schema, $fake_job, \@payload );
            is($tmp,undef,"Deleted Then Inserted a Product");
            # check deleted product has gone & new one is there
            $tmp    = _get_prod_back( $rp_rs, $payload[0] );
            cmp_ok($tmp,"==",0,"Deleted Product: ".$payload[0]->{product});
            $tmp    = _get_prod_back( $rp_rs, $payload[1] );
            cmp_ok($tmp,"==",1,"Inserted Product: ".$payload[1]->{product});

            # insert a matching product over a non-empty slot
            $payload->{action}  = 'insert';
            $payload->{product} = $products->[1]->id;
            $payload->{slot}    = 1;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            like($tmp,qr/Clash for Product.*is in a different slot for Outfit Product/,"Couldn't Insert another Recommended Product in a Non Empty Slot");

            # THIS SHOULD WORK BUT IS THE CAUSE OF THE PROBLEMS (I THINK)
            # insert a new product over a non-empty slot
            $payload->{action}  = 'insert';
            $payload->{product} = $products->[6]->id;
            $payload->{slot}    = 2;
            $tmp    = create_and_execute_job( $schema, $fake_job, [ $payload ] );
            is($tmp,undef,"Inserted a New Product in a Non Empty Slot");
            $tmp    = _get_prod_back( $rp_rs, $payload );
            cmp_ok($tmp,"==",1,"Inserted Product: ".$payload->{product});

            # delete a product, then insert one of the other recom prods
            # in it's slot
            @payload    = ();
            $payload->{action}  = 'delete';
            $payload->{product} = $products->[0]->id;
            push @payload, { %$payload };
            $payload->{action}  = 'insert';
            $payload->{slot}    = 1;
            $payload->{product} = $products->[5]->id;
            push @payload, { %$payload };
            $tmp    = create_and_execute_job( $schema, $fake_job, \@payload );
            like($tmp, qr/duplicate key value violates unique constraint/,
                "Delete a Product: ".$payload[0]->{product}." then Insert a Matching Product: ".$payload[1]->{product}." Should Fail"
            );

            $schema->txn_rollback();
        });
    };
}

#--------------------------------------------------------------

# return back if position of products in payload is in the table
sub _get_prod_back {
    my ( $rs, $payload )    = @_;

    $rs->reset;
    return $rs->count( {
                            recommended_product_id  => $payload->{product},
                            sort_order              => $payload->{sort_order},
                            slot                    => $payload->{slot},
                       } );
}

# setup some dbic stuff
sub _define_dbic_data {
    my $schema      = shift;

    my $retval;

    $retval->{channels} = sub {
            my $rs  = $schema->resultset('Public::Channel')->search( undef, { order_by => 'id ' } );
            my @channels;
            while ( my $channel = $rs->next ) {
                push @channels,$channel->id;
            }
            return \@channels;
        };

    $retval->{products} = sub {
        my (undef,$pids) = Test::XTracker::Data->grab_products({
            channel_id => shift,
            how_many => 10,
        });
        my @products;

        for my $product (map { $_->{product} } @$pids) {
            # get products and set them to be invisible so they don't
            # get updated to the web-site
            $product->get_product_channel->update( { live => 0 } );
            push @products, $schema->resultset('Public::Product')->find( $product->id );
        }
        return \@products;
    };

    return $retval;
}

# Creates a job
sub create_job {
    my ( $schema, $arg ) = @_;

    my $job = new_ok( 'XT::JQ::DC::Receive::Product::WearItWith' => [ payload => $arg, schema => $schema ] );

    return $job;
}

# Creates and executes a job
sub create_and_execute_job {
    my ( $schema, $fake_job, $arg ) = @_;

    eval {
        my $job = create_job( $schema, $arg );
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
