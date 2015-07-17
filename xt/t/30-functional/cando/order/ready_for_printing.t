#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Data::Dump qw(pp);
use FindBin::libs;

use Test::More::Prefix qw/test_prefix/;


use Test::XTracker::Data;
use XTracker::Config::Local;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::Labels::MrPSticker;
use Test::XT::Flow;
use Test::XTracker::RunCondition iws_phase => '2', export => qw( $iws_rollout_phase );
use Test::XTracker::MessageQueue;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [ 'Test::XT::Flow::Fulfilment' ] );


# Set up message and print doc watching
note "Opening XT message queue and prepping it for subsequent reading";
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
# legacy print docs (.html)
my $print_dir = Test::XTracker::PrintDocs->new();
# another type of print doc (.lbl in this case):
my $sticker_dir = Test::XTracker::Artifacts::Labels::MrPSticker->new();

# Setup the orders
my %channels;
for my $channel_id (qw/ MRP NAP /) {

    # Retrieve the channel object
    my $channel_obj =
        $framework->schema->resultset('Public::Channel')->search(
            { 'business.config_section' => $channel_id }, { join => 'business' }
        )->first;

    # Use it to grab a set of PIDs
    @{$channels{ $channel_id }}{qw/ row pids /} =
        Test::XTracker::Data->grab_products({ channel => $channel_obj, how_many => 1 });

}

my $factory = Test::XTracker::MessageQueue->new();

# Set up tests based on templates
test_prefix("Setting up orders for test cases");
my @tests = map {

    # Get each defined test case
    my $test_in  = sanity_check($_);

    # These are the defaults for creating an order
    my $order_template = {
        channel => $channels{ $test_in->{'channel'} }->{'row'},
        pids    => $channels{ $test_in->{'channel'} }->{'pids'},
    };

    # Configure the order from the test case
    $order_template->{'premier'} = $test_in->{'premier'} if defined $test_in->{'premier'};

    # How to describe this order?
    my $order_type = $test_in->{'premier'} ? 'premier' : 'standard';
    my $description =
        ucfirst( $order_type ) . ' ' . $test_in->{'channel'}  . ' order ';
    $description .= format_option('Sticker',      'sticker',      1, $test_in );
    $description .= format_option('Features',     'feature',      0, $test_in );

    note("Setup: $description");

    # Create the order itself
    my $order = $framework->flow_db__fulfilment__create_order_picked(
        %$order_template
    );

    # Sticker required?
    $order->{'order_object'}->update({ sticker => $test_in->{'sticker'} })
        if $test_in->{'sticker'};

    # Create the test case
    my $test_out = {
        shipment_id    => $order->{'shipment_id'},
        display_name   => $description,
        config_section => $test_in->{'channel'},
        type           => $order_type,
        printdocs      => $test_in->{'expected'}
    };

    $test_out;

} (
    {
        channel      => 'MRP',
        sticker      => 'Mr Test Sticker',
        expected     => [qw/ sticker /],
    },
    {
        channel      => 'MRP',
        sticker      => 'Mr Test Sticker',
        premier      => 1,
        expected     => [qw/ address_card sticker /],
    },
    {
        channel      => 'NAP',
        premier      => 1,
        expected     => [qw/ address_card /]
    },
    {
        channel      => 'NAP',
        premier      => 1,
        expected     => [qw/ address_card /]
    },
);

foreach my $test ( @tests ) {
    my $shipment_id = $test->{shipment_id};
    test_prefix('TEST CASE');
    note $test->{'display_name'} . ' ('.$shipment_id.')';
    note "Hoping to find: " . join '; ',  @{$test->{printdocs}};
    test_prefix( 'Shipment '.$shipment_id );

    # Pick station ID turns into u4_mrpsticker_pick_40, which must be in config
    my $pick_station_id = 40;

    # Send ready_for_printing
    {
        my $payload = {
            shipment_id => 's-' . $shipment_id,
            pick_station => $pick_station_id,
        };

        note "Sending ready_for_printing: " . pp( $payload );

        $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ReadyForPrinting',$payload);
    }

    # Check the ready_for_printing was received
    $framework->wms_receipt_dir->expect_messages( {
        messages => [ {
            type    => 'ready_for_printing',
            details => { shipment_id => 's-' . $shipment_id }
        } ]
    } );

    # Check we get back the correct printing_done message
    my ( $message ) = $xt_to_wms->expect_messages( { messages => [ {
        type => 'printing_done',
        details => { shipment_id => 's-' . $shipment_id }
    } ] } );

    # This checks that the number of items in the 'printers' return value
    # matches the number of printed items back. That's a little naive as that
    # assumes everything will be printed from a different printer... This is
    # apparently just a quick sanity check, tho, as we do it a little more
    # hardcore momentarily...
    is(
        scalar @{$message->payload_parsed->{'printers'}},
        scalar @{$test->{printdocs}},
        "Correct number of items printed"
    );

    # Create a list of what we think the message will contain based on the
    # document keys we have
    my $expected_printdocs = 0;
    my $expected_stickers = 0;
    my @expected_message_printers;
    foreach my $doctype (@{$test->{printdocs}}) {
        if ($doctype eq 'sticker') {
            $expected_stickers++;
            push @expected_message_printers, {
                'documents' => ['MrP Sticker'],
                'printer_name' => "Picking MRP Printer $pick_station_id"
            };
        } elsif ($doctype eq 'address_card') {
            $expected_printdocs++;
            push @expected_message_printers, {
                'documents' => ['Address Card'],
                'printer_name' => "Picking Premier Address Card $pick_station_id"
            };
        } elsif ($doctype eq 'gift_message') {
            $expected_printdocs++;
            push @expected_message_printers, {
                'documents' => ['Gift Message'],
                'printer_name' => sprintf("Gift Card %s %s",
                                    $test->{config_section}, $pick_station_id)
            };
        }
    }

    # sort what we got and expect so that we don't rely on any particular order
    # this will break if we print more than one thing to the same printer name though
    my $ss = sub { $a->{'printer_name'} cmp $b->{'printer_name'} };
    my @got_message_printers   = sort $ss @{$message->payload_parsed->{'printers'}};
    @expected_message_printers = sort $ss @expected_message_printers;

    # now compare the details of what was apparently printed
    is_deeply(
        \@got_message_printers, \@expected_message_printers,
        "Correct documents printed");

    # check we've got the right number of actual files created in printdocs
    if ($expected_printdocs) {
        my @printed = $print_dir->wait_for_new_files(files => $expected_printdocs);
    }
    if ($expected_stickers) {
        my @printed = $sticker_dir->wait_for_new_files(files => $expected_stickers);
    }

}

done_testing();

sub format_option {
    my ( $description, $key, $bool, $test ) = @_;
    my $result;
    if ( $bool ) {
        $result = $test->{$key} ? 'Y' : 'N';
    } else {
        $result = $test->{$key} || '';
    }
    return "$description [$result]; ";
}

sub sanity_check {
    my $test_case = shift;

    my @required = (qw/channel expected/);
    my %allowed  = map { $_ => 1 } (@required, qw/ premier feature sticker /);

    for (@required) { die "Test cases require $_ to be set" unless exists $test_case->{$_} }
    for (keys %$test_case) { die "Unknown test case key $_" unless $allowed{$_} }

    die "Unknown channel " . $test_case->{'channel'}
        unless $channels{$test_case->{'channel'}};

    return $test_case;
}
