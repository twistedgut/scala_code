#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 Tests 'XT::Order::Importer' when Order Fails to Import

Tests for each Sales Channel failures that can happen when 'XT::Order::Importer->import_orders' is called.

These are currently:
    * Fail to get a Parser
    * Fail to Parse an Order
    * Fail to Digest an Order
    * and Successfully Imports an Order

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Test::XTracker::Data::Order::Parser::IntegrationServiceJSON;

use XTracker::Utilities         qw( ff_deeply );
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :storage_type );

## HORRIBLE IMPORT HACK - START
#
# This horrible hack was brought to you by the words: dakkar, chisel, beech
# (mostly dakkar)
#
# The test needs to 'do things' to send_email()
# Both Perl6::Export::Attrs and Sub::Exporter store references to the function
# at compile time, so we can't replace what XT::Order::Importer sees/uses
#
# This block is Gianni's solution to the horrible mess
use XTracker::EmailFunctions ();
no warnings "redefine";
my $redef_email_used    = 0;
my $redef_email_msg     = "";
BEGIN {
    my $orig=\&XTracker::EmailFunctions::import;
    *XTracker::EmailFunctions::import=sub {
        my ($class,@args)=@_;
        $class->$orig(@args);
        # we only intercept when our caller is the order importer
        # the order importer isn't doing anything wrong ... so no blaming that
        # module
        # we're the evil overlords rewriting the universe for the test ;-)
        if (caller eq 'XT::Order::Importer') {
            *XT::Order::Importer::send_email= \&_redefined_send_email;
        }
    }
}
use warnings "redefine";
## HORRIBLE IMPORT HACK - END

# now use the module that calls the function we're trying to kill
use XT::Order::Importer;

my $schema   = Test::XTracker::Data->get_schema;
my @channels = $schema->resultset('Public::Channel')->enabled;

# this sets up per channel the Parser to use and
# whether the Importer should 'die' when failing
# to 'digest' an Order
my %expected_channel_args = (
    "NAP" => {
        parser => "PublicWebsiteXML",
        on_digest_fail => 'lives',
    },
    "MRP" => {
        parser => "PublicWebsiteXML",
        on_digest_fail => 'lives',
    },
    "OUTNET" => {
        parser => "PublicWebsiteXML",
        on_digest_fail => 'lives',
    },
    "JC"  => {
        parser => "IntegrationServiceJSON",
        on_digest_fail => 'dies',
    },
);

# get the Config so it can be altered
my $config  = \%XTracker::Config::Local::config;
my $dc_name = config_var('DistributionCentre','name');

# START
foreach my $channel (@channels) {

    my $channel_name    = $channel->name;

    note "Testing Channel: ${channel_name}";

    my (undef, $products) = Test::XTracker::Data->grab_products({
        how_many            => 2,
        dont_ensure_stock   => 1,
        # used to make sure Third Party SKUs are created for Fulfilment Only Channels
        force_create        => 1,
        storage_type_id     => $PRODUCT_STORAGE_TYPE__FLAT,
        channel             => $channel});

    my $customer    = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

    my $order_args = {
        customer => {
            id => $customer->id,
        },
        order => {
            channel_prefix => $channel->business->config_section,
            shipping_price => 10.00,
            shipping_tax   => 1.50,
            tender_amount  => 121.50,
            items => [
                {
                    sku => $products->[0]->{sku},
                    ol_id => 123,
                    description => $products->[0]->{product}->product_attribute->name,
                    unit_price => 100,
                    tax => 10,
                    duty => 0,
                },
            ],
        }
    };

    my $conf_section    = $channel->business->config_section;
    my $channel_args    = $expected_channel_args{ $conf_section };
    my $channel_config  = $config->{ 'OrderImporter_' . $conf_section };
    my $class_name = "Test::XTracker::Data::Order::Parser::". $channel_args->{parser};
    my $parser  = $class_name->new();

    note "test for failure to get a Parser";
    throws_ok {
            XT::Order::Importer->import_orders( { schema => $schema, data => [ 'should_not_get_a_parser' ] } );
        } qr/Unable to find a suitable class/i, "Failed to Find a Parser";

    note  "test for failure to Parse";
    $channel_config->{send_error_email} = 'no'; # this should be ignored for parsing errors
    $redef_email_used   = 0;
    $redef_email_msg    = "";
    throws_ok {
        XT::Order::Importer->import_orders(
            {
                schema => $schema,
                data   => {
                    orders => [ { 1 => 'should_not_parse' } ],
                    merchant_url => 'www.jimmychoo.com',
                }
            }
        );
    } qr/Parsing Failed/i, "Failed to Parse throws an Error";
    cmp_ok( $redef_email_used, '==', 1, "Email Sent on Parser Failure" );
    like( $redef_email_msg, qr/DC: $dc_name, .*Channel: Unknown/si, "Found DC Name & Sales Channel - Unknown - in Email Body" );

    note  "test for failure to Digest";
    my $test_order_args = ff_deeply( $order_args );
    $test_order_args->{order}{items}[0]{sku}    = 'RUBBISH_SKU_SHOULD_FAIL';
    $test_order_args->{channel} = $channel;     # ff_deeply can't clone an Object
    my ( $data )    = $parser->prepare_data_for_parser(
                                $test_order_args,
                            );

    # tests with different email config setting whether a
    # failure email is sent or not
    foreach my $setting ( 'yes', 'no' ) {
        $channel_config->{send_error_email} = $setting;
        note "with Email setting : $setting";

        $redef_email_used   = 0;
        $redef_email_msg    = "";
        my $result;

        given ($channel_args->{on_digest_fail}) {
            when ('lives') {
                lives_ok {
                    $result = XT::Order::Importer->import_orders( { schema => $schema, data => $data } )
                } "Digest Failed : lives ok ";
                cmp_ok ($result, '==', 0, "Digest returned ZERO");
            }
            when ('dies') {
                throws_ok {
                    XT::Order::Importer->import_orders( { schema => $schema, data => $data } )
                } qr /Create Failed/i, "Digest Failed : Throws Error ";
            }
            default { die "Unknown 'no_digest_fail' option: '$_'" }
        }

        if ( $setting eq 'yes' ) {
            cmp_ok ($redef_email_used, '==', 1 , "Email was sent");
            like( $redef_email_msg, qr/DC: $dc_name, .*Channel: $channel_name/si, "Found DC Name & Sales Channel - $channel_name - in Email Body" );
        } else  {
            cmp_ok ($redef_email_used, '==', 0, "Email was NOT sent");
        }
    }

    note  "test for Digest success";
    $order_args->{channel} = $channel;
    $channel_config->{send_error_email} = 'yes'; # should not send email when successfull
    $redef_email_used = 0 ;
    $redef_email_msg  = "";

    ( $data )   = $parser->prepare_data_for_parser(
                                $order_args,
                            );

    my $result = XT::Order::Importer->import_orders( { schema => $schema, data => $data } );
    cmp_ok($result , '==' ,1, "Order digested successfully");
    cmp_ok($redef_email_used , '==' ,0, "Email was NOT sent");
}

done_testing();

#-----------------------------------------------------

# re-defined send_email function
sub _redefined_send_email {
    note "============== IN REDEFINED 'send_email' ==============";
    $redef_email_used   = 1;
    $redef_email_msg    = $_[4];
    return 1;
}
