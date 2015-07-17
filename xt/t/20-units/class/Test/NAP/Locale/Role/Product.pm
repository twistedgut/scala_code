package Test::NAP::Locale::Role::Product;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

BEGIN { use_ok( 'NAP::Locale::Role::Product' ); }

use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data::Order;
use Test::XTracker::Data;
use NAP::Locale;

use XT::Service::Product;

use XTracker::Database::Order;
use XTracker::Database::Shipment;

sub startup : Test(startup) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema();
    $self->{dbh} = Test::XTracker::Data->get_dbh;
    ok($self->{schema}->isa('XTracker::Schema') && exists $self->{dbh}
        && defined $self->{dbh}, "Schema and DBI handle exist");
}

sub local_role_product_minimal_data : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;

        my $customer = Test::XTracker::Data->find_customer( {
            channel_id => $channel->id,
        } );

        # Try and get some data for products we know are available with
        # translated data in Product Service

        my $data = { Test => 1, };
        my $docs;
        local $@;
        my @languages = $self->schema->resultset('Public::Language')
            ->get_all_language_codes;
        my @required_fields = map { 'name_'.$_ } @languages;

        eval {
            my $product_service = XT::Service::Product->new(
                channel => $channel
            );
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
                field_list => [ qw( product_id ), @required_fields ],
            );
        };
        if ( ! $@ ) {
            foreach my $index (0 .. $#{$docs}) {
                my $result = $docs->[$index];
                $data->{other_items}->{$index} = {
                    product_id  => $result->{product_id},
                    name        => $result->{name_en},
                };
                $data->{shipment_items}->{$index} = {
                    product_id  => $result->{product_id},
                    name        => $result->{name_en},
                };
                $data->{invoice_items}->{$index} = {
                    product_id  => $result->{product_id},
                    name        => $result->{name_en},
                };
            }
        }

        foreach my $language ( @languages ) {
            my $locale = NAP::Locale->new(
                locale      => $language,
                customer    => $customer
            );

            my $localised = $locale->localise_product_data( $data );

            is_deeply($localised, $data, "Data matches");
        }

    }
}

sub locale_role_product_with_order : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all) {
        next unless $channel->can_access_product_service;

        my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channel,
        } );

        my ($order, $customer, $shipment) = map { $order_data->{$_} }
            qw( order_object customer_object shipment_object );

        ok($order, "I have an order ...");
        ok($order->isa('XTracker::Schema::Result::Public::Orders'),
            "... and the order is an order DBIC object");

        ok($customer, "I have a customer ...");
        ok($customer->isa('XTracker::Schema::Result::Public::Customer'),
            "... and the customer is a DBIC Customer object");

        ok($shipment, "I have a shipment ...");
        ok($shipment->isa('XTracker::Schema::Result::Public::Shipment'),
            "... and the customer is a DBIC Shipment object");

        my $language = $customer->get_language_preference->{language}->code ?
            $customer->get_language_preference->{language}->code
            : $self->{schema}->resultset('Public::Language')->get_default_language_preference->code;

        ok($language, "I have a language ($language) to work with");

        my $locale = NAP::Locale->new(
            locale      => $language,
            customer    => $customer
        );
        ok($locale, "I have a NAP::Locale instance");

        my $data = {
            order           => get_order_info($self->{dbh}, $order->id),
            order_id        => $order->order_nr,
            channel         => $channel->business->config_section,
            shipment_items  => get_shipment_item_info($self->{dbh}, $shipment->id),
        };

        my $localised_data = $locale->localise_product_data( $data );

        if ( lc $language eq 'en' ) {
            is_deeply($data, $localised_data, "Localised Data is unchanged for English");
        }

    }
}
