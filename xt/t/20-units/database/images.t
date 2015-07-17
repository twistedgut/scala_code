#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :currency :country :sub_region :business );

use DateTime;
use Math::Round;
use Data::Dump  qw( pp );


use Test::Exception;

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Image', qw(
                            get_images
                            get_image_list
                        ) );

    can_ok("XTracker::Image", qw(
                            get_images
                            get_image_list
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;

#---- Test Functions ------------------------------------------

$schema->txn_do( sub {
        _test_image_funcs($dbh,$schema,1);

        $schema->txn_rollback();
    } );

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests image functions
sub _test_image_funcs {

    my $dbh     = shift;
    my $schema  = shift;

    my $tmp;
    my @tmp;

    my $nap_pid;
    my $out_pid;
    my $mrp_pid;

    ( $tmp, $nap_pid )  = Test::XTracker::Data->grab_products( { channel => 'nap', how_many => 1, dont_ensure_stock => 1, } );
    ( $tmp, $out_pid )  = Test::XTracker::Data->grab_products( { channel => 'out', how_many => 1, dont_ensure_stock => 1, } );
    ( $tmp, $mrp_pid )  = Test::XTracker::Data->grab_products( { channel => 'mrp', how_many => 1, dont_ensure_stock => 1, } );

    my %tests   = (
            'NaP'   => {
                pid     => $nap_pid->[0],
                fnamestr=> $nap_pid->[0]{pid},
                filename=> qr/$$nap_pid[0]{pid}_in_m/,
                sizes   => {
                    m  => qr/[\d]_in_m\.jpg/,
                    m2 => qr/[\d]_in_m\.jpg/,
                    m3 => qr/[\d]_in_m\.jpg/,
                    m4 => qr/[\d]_in_m4\.jpg/,
                },
                listfname   => qr/$$nap_pid[0]{pid}_in_s\.jpg/,
            },
            'Outnet'=> {
                pid     => $out_pid->[0],
                fnamestr=> $out_pid->[0]{pid},
                filename=> qr/$$out_pid[0]{pid}_in_m/,
                sizes   => {
                    m  => qr/[\d]_in_m\.jpg/,
                    m2 => qr/[\d]_in_m\.jpg/,
                    m3 => qr/[\d]_in_m\.jpg/,
                    m4 => qr/[\d]_in_m4\.jpg/,
                },
                listfname   => qr/$$out_pid[0]{pid}_in_s\.jpg/,
            },
            'MrP'   => {
                pid     => $mrp_pid->[0],
                fnamestr=> $mrp_pid->[0]{pid}."_mrp",
                filename=> qr/$$mrp_pid[0]{pid}_mrp_in_m3/,
                sizes   => {
                    m  => qr/[\d]_mrp_in_m3\.jpg/,
                    m2 => qr/[\d]_mrp_in_m2\.jpg/,
                    m3 => qr/[\d]_mrp_in_m3\.jpg/,
                    m4 => qr/[\d]_mrp_in_m4\.jpg/,
                },
                listfname   => qr/$$mrp_pid[0]{pid}_mrp_in_s\.jpg/,
            },
        );

    SKIP: {
        skip "_test_image_funcs"            if (!shift);

        note "TESTING Image Functions";

        #
        # 'get_image_list' function
        #

        note "testing 'get_images' function";
        foreach my $test_label ( keys %tests ) {
            note "Sales Channel: $test_label";
            my $test    = $tests{ $test_label };
            my $pid     = $test->{pid}{pid};        # get the product id for the product
            my $pc      = $test->{pid}{product_channel};

            # make all product's channels initally non-live
            # gets round Outnet PIDs being on 2 channels
            $test->{pid}{product}->product_channel->update( { live => 0 } );
            $pc->discard_changes;

            my $args    = {
                    product_id      => $test->{pid}{pid},
                    schema          => $schema,
                };

            # 'non-live' first
            $tmp    = get_images( $args );
            like( $tmp->[0], qr{^/images}, "for non-live image, filename starts '/images'" );

            # override live by passing it in explicitly
            $args->{live}   = 1;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/^http:/, "(overridden live flag) for live image, filename starts 'http'" );
            delete $args->{live};       # get rid of live flag for next test

            # make product 'live'
            $pc->update( { live => 1 } );
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/^http:/, "for live image, filename starts 'http'" );
            like( $tmp->[0], $test->{filename}, "for live image, 1st filename looks as expected ".$test->{filename} );
            like( $tmp->[1], qr/$$test{fnamestr}_bk_xs\.jpg/, "for live image, 'back' image filename looks as expected" );
            like( $tmp->[2], qr/$$test{fnamestr}_cu_xs\.jpg/, "for live image, 'close up' image filename looks as expected" );

            # override live by passing it in explicitly
            $args->{live}   = 0;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr{^/images}, "(overridden live flag) for non-live image, filename starts '/images'" );
            delete $args->{live};       # get rid of live flag for next test

            # don't pass 'schema' to function
            delete $args->{schema};
            $args->{live}   = 1;        # explicitly set 'live' flag
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/${pid}_in_m\.jpg/, "with no 'schema' passed in and 'live' flag set to true, image filename is default: $$test{pid}{pid}_in_m.jpg" );
            # restore arguments
            delete $args->{live};
            $args->{schema} = $schema;


            note "test different sizes for live images";
            foreach my $size ( keys %{ $test->{sizes} } ) {
                my $sizematch   = $test->{sizes}{ $size };
                $args->{size}   = $size;
                $tmp    = get_images( $args );
                like( $tmp->[0], $sizematch, "filename for size '$size' as expected: ".$sizematch );
            }
            delete $args->{size};


            note "set 'business_id' to be for MRP explicitly to change the image filename returned";

            $args->{business_id}  = $BUSINESS__MRP;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/${pid}_mrp_in_m3\.jpg/, "'business_id' as MRP set explicitly returns a MrP style image name: ".$tmp->[0] );

            $args->{business_id}  = 0;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/${pid}_in_m\.jpg/, "'businsess_id' as ZERO set explicitly returns a default (non MrP) style image name: ".$tmp->[0] );

            $args->{business_id}  = $BUSINESS__NAP;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/${pid}_in_m\.jpg/, "'businsess_id' as NAP set explicitly returns a default (non MrP) style image name: ".$tmp->[0] );

            # don't pass 'schema' and set 'business_id' to be for MRP & 'live' flags to be true
            delete $args->{schema};
            $args->{business_id}= $BUSINESS__MRP;
            $args->{live}       = 1;
            $tmp    = get_images( $args );
            like( $tmp->[0], qr/${pid}_mrp_in_m3\.jpg/, "with no 'schema' passed and 'business_id' set as MRP & 'live' flags set to true returns a MrP style image name: ".$tmp->[0] );
        }


        #
        # 'get_image_list' function
        #

        note "testing 'get_image_list' function";
        my $prod_ref    = [
                {
                    product_id  => $nap_pid->[0]{pid},
                },
                {
                    id          => $out_pid->[0]{pid},      # can also pass product id like this
                },
                {
                    product_id  => $mrp_pid->[0]{pid},
                },
            ];

        # set all pids to be 'non-live'
        $_->[0]{product_channel}->update( { live => 0 } )      foreach ( $nap_pid, $out_pid, $mrp_pid );

        $tmp    = get_image_list( $schema, $prod_ref );
        foreach my $test_label ( keys %tests ) {
            my $test    = $tests{ $test_label };
            like( $tmp->{ $test->{pid}{pid} }, qr{^/images}, "$test_label: 'non-live' product image filename starts as expected: /images" );
        }

        # override 'live' flag for first product
        $prod_ref->[0]{live}    = 1;
        $tmp    = get_image_list( $schema, $prod_ref );
        like( $tmp->{ $prod_ref->[0]{product_id} }, qr/^http:/, "overridden 'live' flag for first product, image filename starts as expected: http:" );
        like( $tmp->{ $prod_ref->[1]{id} }, qr{^/images}, "overridden 'live' flag for first product, second image filename still starts: /images" );
        delete $prod_ref->[0]{live};        # get rid of 'live' flag for next test

        # set all pids to be 'live'
        $_->[0]{product_channel}->update( { live => 1 } )      foreach ( $nap_pid, $out_pid, $mrp_pid );

        $tmp    = get_image_list( $schema, $prod_ref );
        foreach my $test_label ( keys %tests ) {
            my $test    = $tests{ $test_label };
            like( $tmp->{ $test->{pid}{pid} }, $test->{listfname}, "$test_label: 'live' product image filename is as expected: ".$test->{listfname} );
        }

        note "pass a different size: testsize to get for the images";
        $tmp    = get_image_list( $schema, $prod_ref, "testsize" );
        foreach my $test_label ( keys %tests ) {
            my $test    = $tests{ $test_label };
            my $pid     = $test->{pid}{pid};
            like( $tmp->{ $pid }, qr/$$test{fnamestr}_in_testsize/, "$test_label: product image filename has different 'size' in it: ".$tmp->{ $pid } );
        }

        note "explictitly set the 'business' flag to true for 1st product which is a 'NaP' PID and set to false for 3rd product which is a 'MrP' PID";
        $prod_ref->[0]{business_id} = $BUSINESS__MRP;
        $prod_ref->[2]{business_id} = $BUSINESS__NAP;
        $tmp    = get_image_list( $schema, $prod_ref );
        like( $tmp->{ $prod_ref->[0]{product_id} }, qr/_mrp_in_s\.jpg/,
                    "'business_id' set a MRP for 1st product (NaP) has 'mrp' in image name: ".$tmp->{ $prod_ref->[0]{product_id} } );
        unlike( $tmp->{ $prod_ref->[1]{id} }, qr/_mrp_/,
                    "2nd product (Outnet) didn't have 'business_id' set at all & doesn't have 'mrp' in the image name: ".$tmp->{ $prod_ref->[1]{id} } );
        unlike( $tmp->{ $prod_ref->[2]{product_id} }, qr/_mrp_/,
                    "3rd product (MrP) had 'business_id' set as NAP and doesn't have 'mrp' in the image name: ".$tmp->{ $prod_ref->[2]{product_id} } );
        delete $prod_ref->[0]{business_id};       # get rid of 'business_id' for next test


        note "update all PIDs to be FALSE and explictily set 'business_id' as MRP & 'live' flags to be true";

        # set all pids to be 'non-live'
        $_->[0]{product_channel}->update( { live => 0 } )      foreach ( $nap_pid, $out_pid, $mrp_pid );

        # explictitly set 'business_id' as MRP & 'live' flags to be true for all pids
        foreach ( @{ $prod_ref } ) {
            $_->{business_id} = $BUSINESS__MRP;
            $_->{live}      = 1;
        }

        $tmp    = get_image_list( $schema, $prod_ref );
        foreach my $test_label ( keys %tests ) {
            my $test    = $tests{ $test_label };
            my $pid     = $test->{pid}{pid};
            like( $tmp->{ $pid }, qr/${pid}_mrp_in_s\.jpg/, "with 'buisness_id' as MRP & 'live' flags set to true, $test_label: product image filename has 'MrP' style image name: ".$tmp->{ $test->{pid}{pid} } );
        }
    }
}

#--------------------------------------------------------------
