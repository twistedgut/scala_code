package Test::XT::DC::Messaging::Producer::PRL::Deliver;

=head1 NAME

Test::XT::DC::Messaging::Producer::PRL::Deliver

=head1 DESCRIPTION

Check the deliver message sending.

#TAGS goh fulfilment deliver prl

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with    "NAP::Test::Class::PRLMQ",
            'XTracker::Role::WithPRLs';
};

use Test::XTracker::RunCondition prl_phase => '2';
use XT::Domain::PRLs;

use Test::XT::Data; # new_with_traits
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB qw/
    :storage_type
/;
use Test::XTracker::MessageQueue;
use XT::DC::Messaging::Producer::PRL::Deliver;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

sub startup : Test(startup => 1) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    # Create a mechanism for sending XT messages
    $self->{factory} = Test::XTracker::MessageQueue->new;
}

sub send_deliver_message :Tests {
    my ($self, $args) = @_;

    my $allocation_args = {
        how_many => 1,
    };

    my ($allocation) = @{ $self->_create_allocations($allocation_args) };

    my $amq = $self->{factory};

    my ($destination) = $allocation->prl->amq_queue;

    $amq->clear_destination($destination);

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Deliver' => {
                allocation => $allocation,
            }
        );
    } 'Sent a Deliver message.';

    # check the number of sent messages
    $amq->assert_messages(
        {
            destination  => $destination,
            assert_count => 1,
        },
        "Message was sent to $destination."
    );

    $amq->assert_messages({
        destination => $destination,
        assert_header => superhashof({
            type => 'deliver',
        }),
        assert_body => superhashof({
            allocation_id => $allocation->id,
        }),
        assert_count => 1,
    },"message was sent to $destination with the corrent content");

    # clean up
    $amq->clear_destination($destination);
}

sub _create_allocations {
    my $self = shift;
    my $args = shift;

    # Create orders
    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many        => $args->{how_many},
    });
    my $shipment = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    )
    ->new_order(
        products      => \@flat_pids,
        dont_allocate => 1,
    )
    ->{shipment_object};

    $shipment->update({
        sla_cutoff => DateTime->now->add( hours => 1 ),
    });

    # Call allocate_shipment
    my @allocations = $shipment->allocate({
        factory     => $self->{factory},
        operator_id => $APPLICATION_OPERATOR_ID
    });

    return \@allocations;
}

1;
