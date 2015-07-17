#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock_location_for_returns.t

=head1 DESCRIPTION

=head2 Check basic functionality

Check the basic functionality of getting the correct location for a variant
depending on whether it has a location, another variant for the same product
has a location or no locations available at all.

=head2 Check maximum quantity functionality

Check that the location with the maximum quantity is returned
for either the variant or another variant for the same product.

=head2 Check correct sorting functionality

Check that for locations with the same quantity, the first one sorted
Alphabetically is returned. Do for either a variant or another variant
for the same product.

=head2 Check zero quantity locations are ignored

Checks that locations that have zero quantity are counted as a valid location
when returning a location.

#TAGS goodsin return duplication shouldbeunit sql toobig needsrefactor

=cut

use Data::Dumper;

use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :flow_status );
use Test::XTracker::Mock::Handler;

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Logfile', qw( xt_logger ));
    use_ok('XTracker::Error');
    use_ok('XTracker::Handler');
    use_ok('XTracker::Database::Stock', qw( :DEFAULT check_stock_location ));
    use_ok('XTracker::Database::Logging', qw( log_location ));
    use_ok('XTracker::Database::Location', qw( get_location_of_stock get_suggested_stock_location ));

    can_ok("XTracker::Database::Location",qw( get_suggested_stock_location ));
}

# get a DBH to query
my $schema = xtracker_schema;
my $dbh = $schema->storage->dbh;
isa_ok($dbh, 'DBI::db','DB Handle Created');

# Setup Handler
my $handler = Test::XTracker::Mock::Handler->new({ data => {} });
isa_ok($handler,'Test::MockObject','Mock Handler Created');

$schema->txn_dont(sub{
    _get_data();

    #--------------- Run TESTS ---------------

    _get_locations(1);

    #--------------- END TESTS ---------------
});

done_testing();

#----------------------- Test Functions -----------------------

# Tests returning location needed for doing Returns QC & Returns Putaway
# 23 Tests
sub _get_locations {
    my $dbh = $handler->{dbh};
    my $product_id  = $handler->{data}{product_id};
    my $channel_id  = $handler->{data}{channel_id};
    my $locations   = $handler->{data}{locations};
    my $variants    = $handler->{data}{variants};
    my $zone2zone   = $handler->{data}{zone2zone};

    SKIP: {
        skip "_get_locations",23 if (!shift);

    ### CHECK BASIC FUNCTIONALITY ###
    # Check the basic functionality of getting the correct location for a variant
    # depending on whether it has a location, another variant for the same product
    # has a location or no locations available at all

    # check that nothing is returned when there is nothing to return
    my $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );
    if ( defined $ref ) {
        fail("get_suggested_stock_location unexpectedly returned a defined value");
        local $Data::Dumper::Maxdepth = 4;
        diag Dumper {
            "Returned locations" => $ref,
            "Variant used"       => [$variants],
            "Channel ID"         => $channel_id
        };
    } else {
        pass("Nothing to return");
    }

    # add a location & qty to a variant
    my $int = insert_quantity($dbh, {
        variant_id => $variants->[0],
        quantity => 10,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
    cmp_ok( $int, ">", 0, "Quantity Added to Variant: ".$variants->[0]." @ Location: ".$locations->[0]);

    # check location above is returned
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );
    #is_deeply( $ref, { type => 'VARIANT', location => [ { location => $locations->[0] } ] }, 'Location for Variant Returned' );
    cmp_ok( $ref->{type},"eq",'VARIANT', 'Location Type for Variant Returned' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[0], 'Location for Variant Returned' );

    # log the fact that the variant used the above location last
    log_location($dbh, {
        variant_id => $variants->[0],
        location => $locations->[0],
        channel_id => $channel_id,
        operator_id => $handler->operator_id
    });
    # delete location from variant
    delete_quantity($dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
    $int = check_stock_location($dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
    cmp_ok( $int, "==", 0, "Quantity Deleted for Variant: ".$variants->[0]." @ Location: ".$locations->[0] );

    # insert a location & qty to another variant for the same product
    $int = insert_quantity($dbh, {
        variant_id => $variants->[1],
        quantity => 10,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
    cmp_ok( $int, ">", 0, "Quantity Added to Variant: ".$variants->[1]." @ Location: ".$locations->[1]);

    # check the above location is returned for another variant same product
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'PRODUCT', 'Location Type for Another Variant is Returned' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Location for Another Variant is Returned' );

    # remove that location from variant so no variants once again has any stock
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int    = check_stock_location( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    cmp_ok( $int, "==", 0, "Quantity Deleted for Variant: ".$variants->[1]." @ Location: ".$locations->[1] );

    # now should get zone back matching the original location's zone for the variant that was used first and logged above
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'ZONE', 'Zone Type is Returned' );
    cmp_ok( $ref->{location}[0]{location},"eq",$zone2zone->{ substr( $locations->[0], 0, 4 ) }, 'Zone is Returned:'.( $ref->{location}[0]{location} // 'undef' ).' for Zone: '.substr( $locations->[0], 0, 4 ) );


    ### CHECK MAX QTY FUNCTIONALITY ###
    # Check that the location with the maximum quantity is returned
    # for either the variant or another variant for the same product

    # add locations & various quantities to a variant
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 3,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 6,
        channel_id => $channel_id,
        location => $locations->[2],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    # check the second location (the one with the max qty) is returned
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'VARIANT', 'Location Type for Max QTY Location is Returned for Variant' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Max QTY Location is Returned for Variant' );

    # delete quantites again so as to have none
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[2],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );

    # add locations & various quantities to a different variant of the same product
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 3,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 6,
        channel_id => $channel_id,
        location => $locations->[2],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    # check the second location (the one with the max qty) is returned
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'PRODUCT', 'Location Type for Max QTY Location is Returned for Another Variant' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Max QTY Location is Returned for Another Variant' );

    # delete quantites again so as to have none
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[2],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );


    ### CHECK CORRECT SORTING FUNCTIONALITY ###
    # Check that for locations with the same quatity the first one sorted Alphabetically
    # is returned. Do for either a variant or another variant for the same product

    # add locations & same quantities to a variant in non alphabetical order
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 3,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[2],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    # check the third location inserted is returned which is higher alphabetically than the others
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'VARIANT', 'Location Type for Higher Alphabetical Location is Returned for Variant' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Higher Alphabetical Location is Returned for Variant' );

    # delete quantites again so as to have none
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[2],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );

    # add locations & same quantities to another variant for same product in non alphabetical order
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 3,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[2],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 7,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    # check the third location inserted is returned which is higher alphabetically than the others
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'PRODUCT', 'Location Type for Higher Alphabetical Location is Returned for Another Variant' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Higher Alphabetical Location is Returned for Another Variant' );

    # delete quantites again so as to have none
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[2],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );


    ### CHECK ZERO QUANTITY LOCATIONS ARE IGNORED ###
    # checkts that locations that have zero quantity are counted as
    # valid location when returning a location

    # add locations & quantities to variants
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[0],
        quantity => 0,
        channel_id => $channel_id,
        location => $locations->[0],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $int = insert_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => 1,
        channel_id => $channel_id,
        location => $locations->[1],
        initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'PRODUCT', 'Location Type for Zero Quantities Another Variants Location' );
    cmp_ok( $ref->{location}[0]{location},"eq",$locations->[1], 'Zero Quantities Another Variants Location' );

    # update quantity for Another Variant down to zero
    $int = update_quantity( $dbh, {
        variant_id => $variants->[1],
        quantity => -1,
        channel_id => $channel_id,
        location => $locations->[1],
        type => 'dec',
        current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    # now should get zone back matching the original location's zone for the variant that was used first and logged near the top of these tests
    $ref = get_suggested_stock_location( $dbh, $variants->[0], $channel_id );

    cmp_ok( $ref->{type},"eq",'ZONE', 'Zone Type for Zero Quantities Returned' );
    cmp_ok( $ref->{location}[0]{location},"eq",$zone2zone->{ substr( $locations->[0], 0, 4 ) }, 'Zone Returned for Zero Quantities' );

    # delete quantites again so as to have none just in case more tests are written
    delete_quantity( $dbh, {
        variant_id => $variants->[0],
        channel_id => $channel_id,
        location => $locations->[0],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    delete_quantity( $dbh, {
        variant_id => $variants->[1],
        channel_id => $channel_id,
        location => $locations->[1],
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    }
}

#--------------------------------------------------------------

# Get some test data out of the database
# 2 Tests
sub _get_data {

    Test::XTracker::Data->grab_products({
        how_many => 2,
        ensure_stock_all_variants => 1,
    });

    # get a product with more than one variant
    my $qry =<<____QRY
        SELECT  product_id,
                COUNT(*)
        FROM    variant
        WHERE   product_id < 100000
        GROUP BY 1
        HAVING COUNT(*) > 1
        ORDER BY 2,1 DESC
        LIMIT 1
____QRY
;
    my $sth = $handler->{dbh}->prepare($qry);
    $sth->execute();
    my @data = $sth->fetchrow_array();
    $handler->{data}{product_id} = $data[0];
    cmp_ok($handler->{data}{product_id},">",0,"Product Id Valid");

    # get channel id for product
    $qry    =<<____QRY
        SELECT get_product_channel_id(?)
____QRY
;
    $sth = $handler->{dbh}->prepare($qry);
    $sth->execute( $handler->{data}{product_id} );
    ($handler->{data}{channel_id}) = $sth->fetchrow_array();
        cmp_ok($handler->{data}{channel_id},">",0,"Channel Id Valid");

    # get locations
    $qry =<<____QRY
        SELECT  location
        FROM    location JOIN location_allowed_status ON location.id = location_id
        WHERE   status_id = ?
        ORDER BY location
        LIMIT 3
____QRY
;
    $sth = $handler->{dbh}->prepare($qry);
    $sth->execute( $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS );
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @{ $handler->{data}{locations} }, $row->{location};
    }

    # get all variants for products and current stock locations
    $qry =<<QRY
        SELECT  id
        FROM    variant
        WHERE   product_id = ?
        ORDER BY id
QRY
;
    $sth = $handler->{dbh}->prepare($qry);
    $sth->execute( $handler->{data}{product_id} );

    $qry = "DELETE FROM log_location WHERE variant_id = ?";
    my $delsth  = $handler->{dbh}->prepare($qry);

    while ( my $variant = $sth->fetchrow_hashref() ) {
        my $stock_locations = get_location_of_stock( $handler->{dbh}, {
            type => 'variant_id' ,
            id => $variant->{id},
            stock_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        } );
        # clean out quantities so as to start a fresh
        foreach my $location ( @{ $stock_locations } ) {
            delete_quantity( $handler->{dbh}, {
                variant_id => $variant->{id},
                channel_id => $handler->{data}{channel_id},
                location => $location->{location},
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            } );
        }
        # clean out the logs too
        $delsth->execute( $variant->{id} );

        push @{ $handler->{data}{variants} }, $variant->{id};
    }

    # get Location ZONE Translations
    $qry    =<<____QRY
        SELECT  *
        FROM    location_zone_to_zone_mapping
        WHERE   channel_id = ?
        ORDER BY zone_from
____QRY
;
    $sth = $handler->{dbh}->prepare($qry);
    $sth->execute( $handler->{data}{channel_id} );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $handler->{data}{zone2zone}{ $row->{zone_from} }    = $row->{zone_to};
    }

}
