package Test::XT::DC::Messaging::Producer::PRL::Pick;

=head1 NAME

Test::XT::DC::Messaging::Producer::PRL::Pick - Test messages around picking

=head1 DESCRIPTION

Test messages around picking.

#TAGS fulfilment picking prl

=head1 SEE ALSO

Some of this code was inspired by L<Test::XTracker::AllocateManager>

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with    "NAP::Test::Class::PRLMQ",
            'XTracker::Role::WithPRLs';
};

use Test::XTracker::RunCondition prl_phase => 'prl';
use XT::Domain::PRLs;

use Test::XT::Data; # new_with_traits
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB qw/
    :storage_type
    :allocation_status
/;
use Test::XTracker::MessageQueue;
use XT::DC::Messaging::Producer::PRL::Pick;
use Test::XT::Flow;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

sub startup : Test(startup => 1) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    # Test::XT::Data instance
    $self->{test_xt_data} = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    # Create a mechanism for sending XT messages
    $self->{factory} = Test::XTracker::MessageQueue->new();

    $self->{flow} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::Role::DBSamples',
        ],
    );


}
sub send_sample_pick_message : Tests {
    my $self = shift;
    $self->send_pick_message({type =>'Sample'});
}

sub send_simple_pick_message : Tests {
    my $self = shift;

    # Send a standard pick message
    $self->send_pick_message();

    # Send one where the shipment has the 'is_prioritised' flag
    $self->send_pick_message({ is_prioritised => 1 });
}

sub send_pick_message {
    my ($self, $args) = @_;

    my $allocation;
    my $allocation_args = {
        how_many        => 1,
        is_prioritised  => $args->{is_prioritised},
    };

    if ($args->{type} && $args->{type} eq 'Sample') {
        ($allocation) = $self->create_sample_allocations($allocation_args);
    } else {
        ($allocation) = $self->create_allocations($allocation_args);
    }

    my $amq = $self->{factory};
    # Where are we sending it?
    my @destinations = $allocation->prl->amq_queue;

    $amq->clear_destination($_) for @destinations;

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Pick' => {
                allocation_id => $allocation->id,
            }
        );
    } 'Sent a Pick message.';

    # check the number of sent messages
    foreach my $destination (@destinations) {
        $amq->assert_messages({
                destination  => $destination,
                assert_count => 1},
            "Message was sent to $destination."
        );

        my $date_time_required = $allocation->shipment()->sla_cutoff();

        # WHM-1847: When talking to the PRL and the shipment has had its priority 'bumped',
        # subtract a week from the SLA to make sure it appears higher
        $date_time_required->subtract( weeks => 1 )
            if $args->{is_prioritised} and $self->prl_rollout_phase();

        $amq->assert_messages({
            destination => $destination,
            assert_header => superhashof({
                type => 'pick',
            }),
            assert_body => superhashof({
                allocation_id => $allocation->id,
                mix_group => $allocation->picking_mix_group,
                date_time_required => $date_time_required->strftime('%FT%T%z'),
            }),
            assert_count => 1,
        },"message was sent to $destination with the corrent content");
    }

    # clean up
    $amq->clear_destination($_) for @destinations;
}


# Utilities

sub create_allocations {
    my $self = shift;
    my $args = shift;

    # Create orders
    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => $args->{how_many},
    });
    my $shipment = $self->{test_xt_data}->new_order(
        products => \@flat_pids,
        dont_allocate => 1,
    )->{'shipment_object'};

    $shipment->update({
        sla_cutoff => DateTime->now->add( hours => 1 ),
        (defined($args->{is_prioritised}) ? ( is_prioritised => $args->{is_prioritised} ) : () ),
    });

    # Call allocate_shipment
    my @allocations = $shipment->allocate({
        factory => $self->{factory},
        operator_id => $APPLICATION_OPERATOR_ID
    });

    return @allocations;
}

sub create_sample_allocations {
    my $self = shift;

    my $channel = Test::XTracker::Data->any_channel;
    my $variant = (Test::XTracker::Data->grab_products({
            channel_id => $channel->id,
            force_create => 1,
        }))[1][0]->{variant};

    my $shipment = $self->{flow}->db__samples__create_shipment({
        channel_id => $channel->id,
        variant_id => $variant->id,
        dont_allocate => 1
    });
    $shipment->update({ sla_cutoff => DateTime->now->add( hours => 1 ) });

    # Call allocate_shipment
    my @allocations = $shipment->allocate({
        factory => $self->{factory},
        operator_id => $APPLICATION_OPERATOR_ID
    });

    return @allocations;

}
1;
