package Test::XT::DC::Messaging::Plugins::PRL::PrintLabelRequest;

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::PrintLabelRequest - Test printing labels

=head1 DESCRIPTION

Test printing labels.

#TAGS prl printer premier dematic gift misc fulfilment

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';
use Test::XT::Flow;
use Test::XT::DC::JQ;
use Test::XTracker::Artifacts::Labels::MrPSticker;

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw(
    :storage_type
);

sub startup : Test(startup => 1) {
    my ( $test ) = @_;
    $test->SUPER::startup;
    $test->{'schema'} = Test::XTracker::Data->get_schema;
    $test->{framework} = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Flow::Fulfilment' ] );

    my $prl = XT::Domain::PRLs::get_prl_from_name({
        prl_name => 'Dematic',
    });
    $test->{destination_queue} = $prl->amq_queue;
}

=head2 test_print_premier_address_cards

=cut

sub test_print_premier_address_cards : Tests {
    my $test = shift;

    ## test premier nap order
    $test->test_consumer({channel => 'NAP', premier => 1 });
}

=head2 test_print_mrp_sticker

=cut

sub test_print_mrp_sticker : Tests {
    my $test = shift;

    $test->test_consumer({channel => 'MRP', sticker => 1 });
}

=head2 test_automated_print_gift_message

=cut

sub test_automated_print_gift_message : Tests {
    my $test = shift;

    $test->test_consumer({channel => 'NAP', gift_message => 1 });
}

sub test_consumer{
    my ($test, $args) = @_;

    my $print_dir = Test::XTracker::PrintDocs->new();
    my $channel = $test->{schema}->resultset('Public::Channel')->search(
            { 'business.config_section' => $args->{channel} }, { join => 'business' }
        )->first;

    # Get a Dematic product
    # (that's the only PRL which supports printing at picking so far)
    my ($product) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        how_many_variants => 1,
    });

    # Configure the order from the test case
    my $order_template = {
        channel  => $channel,
        products => [$product],
    };
    $order_template->{'premier'} = $args->{premier};

    # Create a picked order
    my $order = $test->{framework}->flow_db__fulfilment__create_order_picked(
        %$order_template
    );
    $order->{'order_object'}->update({ sticker => 'Test Sticker' })
        if $args->{sticker};


    my $shipment_id = $order->{'shipment_id'};
    my $shipment = $test->{schema}->resultset('Public::Shipment')->find($shipment_id);
    my $allocation_id = $shipment->allocations->first->id;

    if ($args->{gift_message}){
        $shipment->update({gift_message => 'Test Picking Gift Message'});
    }
    my $allocation_hash = { allocation_id => $allocation_id };
    my @allocations;
    push (@allocations ,$allocation_hash);

    my $amq = Test::XTracker::MessageQueue->new;
    $amq->clear_destination($test->{destination_queue});

    my $sticker_print_directory = Test::XTracker::Artifacts::Labels::MrPSticker->new();

    # Create a message
    my $message = $test->create_message( PrintLabelRequest => {
        location => 'DA.RP01.GTP04.PL05', # from example supplied by dematic
        allocations => \@allocations,
    });

    lives_ok( sub { $test->send_message( $message )}, "PrintLabelRequest handler returned normally");

    if ($args->{gift_message}){
        # If we've disabled gift message printing at picking, we don't need to test any further.
        # We've made sure the print_label_request got processed without dying, which is all we need.
        my $disable_automatic_gift_messages = config_var('GiftMessages', 'disable_automatic_gift_messages');
        return if $disable_automatic_gift_messages;
    }


    ## check the message print_label_request was sent to the producer
    $amq->assert_messages({
        destination => $test->{destination_queue},
        assert_header => superhashof({
            type => 'print_label_response',
        }),
        assert_body => superhashof({
            allocations => [
                {
                    allocation_id => $allocation_id,
                    printers => [
                        superhashof({
                            item        => $args->{sticker} ? 'MrP Sticker' :
                                            ($args->{gift_message} ? 'Gift Message' : 'Address Card'),
                            printer     => $args->{sticker} ? 'Picking MRP Sticker GTP04' :
                                            ($args->{gift_message} ? 'Picking Gift Message GTP04' : 'Picking Premier Address Card GTP04'),
                            quantity    => 1
                        }),
                    ]
                }
            ],
        })
    }, 'Message was sent, correctly.');

    if ($args->{sticker}){
        # stickers are printed like everything else
        my @docs = $sticker_print_directory->new_files;
        is( scalar(@docs), 1, "Sticker print doc appeared" );
    } else {
        # not-stickers print other documents
        my $file_name = $args->{gift_message} ?'giftmessage' : 'addresscard';
        my @printed = $print_dir->wait_for_new_files(files => 1);
        is ($printed[0]->{file_type}, $file_name, 'Premier address card printed');
        is ($printed[0]->{file_id}, $shipment_id, 'Correct file id');
    }
}
