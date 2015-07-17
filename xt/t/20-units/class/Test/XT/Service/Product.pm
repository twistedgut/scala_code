package Test::XT::Service::Product;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

BEGIN { use_ok( 'XT::Service::Product' ); }

use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data;

sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema();
    ok($self->{schema}->isa('XTracker::Schema'), "Got DB Schema object");
}

sub check_nap_channel_can_access_product_service_for_email : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        if ( $channel->name eq 'NET-A-PORTER.COM' ) {
            ok( $channel->can_access_product_service_for_email,
               "Channel ".$channel->name." can access the product service"
              );
        }
    }
}

sub base_product_service_class : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;
        # Test that the channel PS configuration is present
        my $product_service_url = config_var('Solr_'.$channel->business->config_section,'product_service_url');
        ok($product_service_url, "Product Service URL configuration");

        SKIP: {
            skip "Product Service not used for ".$channel->name, 2
                unless $channel->can_access_product_service;

            my $product_service = XT::Service::Product->new( channel => $channel );
            ok($product_service, "Initiated Product Service class");

            my $other_product_service = XT::Service::Product->new(
                channel => $channel,
                url => 'http://prodserv-prodservdev.dave.net-a-porter.com:8092/productservice/nap'
            );
            ok($other_product_service, "Initiated Product Service class with custom URL");
        }
    }
}

sub grab_products_with_name_fr : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;

        my $product_service = XT::Service::Product->new( channel => $channel );

        my $docs;
        local $@;

        eval {
            $docs = $product_service->search_and_fetch(
                url => $product_service->solr_url,
                business_name => $channel->business->config_section,
                live_or_staging => 'live',
                max_results => 5,
                condition => {
                    name_fr => 'jean*',
                    channel_id => $channel->id,
                    visible => 'true',
                },
                field_list => [ qw( name_en product_id name_fr name_de name_zh ) ],
            );
        };

        if ( $@ ) {
            note( "+++++ ERROR: I cannot get docs from Product Service");
            note( $@ );
        }

        if ( ! $@ ) {
            ok($docs, "I have results");
            my $result = pop @$docs;
            my $input = {
                channel => $channel,
                language => 'fr',
                data => {
                    Test1 => 1,
                    shipment_items => {
                        1 => {
                            product_id => $result->{product_id},
                            name => $result->{name_en},
                        },
                    }
                }
            };

            # Call localise_product_data_hash with hash
            my $localised = $product_service->localise_product_data_hash($input);

            is_deeply($localised, $input->{data}, "They are the same");
        }
    }
}

sub get_random_data_from_product_service : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;
        SKIP: {
            skip "Product Service not used for ".$channel->name, 17
                unless $channel->can_access_product_service;

            my $product_service = XT::Service::Product->new( channel => $channel );
            ok($product_service, "Got a Product Service object...");

            local $@;
            my $docs;

            eval {
                $docs = $product_service->search_and_fetch(
                    url => $product_service->solr_url,
                    business_name => $channel->business->config_section,
                    live_or_staging => 'live',
                    max_results => 5,
                    condition => {
                        name_en => 'coat',
                        channel_id => $channel->id,
                        visible => 'true',
                    },
                    field_list => [ qw( name_en product_id ) ],
                );
            };
            note( $@ ) if $@;

            if ( ! $@ ) {
                ok($docs, "... and the Product Service returns some random data");
                foreach my $result ( @$docs ) {
                    ok( exists $result->{product_id}, "... and this one has a product id");
                    ok( exists $result->{name_en}, "... and this one has a name in English");
                    ok( $result->{name_en} =~ /coat/i, "... and the name includes coat");
                }
            }
        }
    }
}

sub get_some_products : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;
        SKIP: {
            skip "Product Service not used for ".$channel->name, 3
                unless $channel->can_access_product_service;

            my $product_service = XT::Service::Product->new( channel => $channel );
            ok($product_service, "Initiated Product Service class");

            my $products = $product_service->get_some_products( {
                how_many => 3,
                channel => $channel
            } );
            if ( $products ) {
                ok( $products, "I have some products" );

                ok( (scalar keys %$products) == 3, "I have the right number of products" );
            }
            else {
                note("Product Service is not available");
            }
        }
    }
}

sub localise_product_data_hash : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;
        SKIP: {
            skip "Product Service not used for ".$channel->name, 2
                unless $channel->can_access_product_service;

            my $product_service = XT::Service::Product->new( channel => $channel );
            ok($product_service, "Initiated Product Service class");

            my $products = $product_service->get_some_products( {
                how_many => 3,
                channel => $channel,
            } );

            my $input = {
                channel => $channel,
                language => 'fr',
                data => {
                    Test1 => 1,
                    shipment_items => $products,
                }
            };

            # Call localise_product_data_hash with hash
            my $localised = $product_service->localise_product_data_hash($input);

            # Verify that the hash has data in each expected key
            # We cannot test that it has localised data as PS may not have it.
            is_deeply($localised, $input->{data},
                        "Data returned from Product Service OK");
        }
    }
}

sub localise_product_data_hash_to_test_recursion : Tests {
    my $self = shift;

    foreach my $channel (Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;
        SKIP: {
            skip "Product Service not used for ".$channel->name, 2
                unless $channel->can_access_product_service;

            my $product_service = XT::Service::Product->new( channel => $channel );
            ok($product_service, "Initiated Product Service class");

            my $products = $product_service->get_some_products( {
                how_many => 3,
                channel => $channel
            } );

            $products->{1}->{product_id} = 1;
            $products->{1}->{name}       = "Product Name";
            $products->{1}->{long_description} = "Product Description";

            my $input = {
                channel => $channel,
                language => 'de',
                data => {
                    Test1 => 1,
                    shipment_items => $products,
                    other_items => [
                        invoice_items => $products,
                        a_hash_ref => {
                            product_items => $products,
                        },
                    ],
                    reservations => {
                        1 => {
                            product_id => $products->{1}->{product_id},
                            product_name => $products->{1}->{name_en},
                            name => $products->{1}->{name_en},
                            long_description => $products->{1}->{long_desription_en},
                        },
                    },
                }
            };

            # Call localise_product_data_hash with hash
            my $localised = $product_service->localise_product_data_hash($input);

            # Verify that the hash has data in each expected key
            # We cannot test that it has localised data as PS may not have it.
            is_deeply($localised, $input->{data},
                        "Data returned from Product Service OK");

            }
    }
}

