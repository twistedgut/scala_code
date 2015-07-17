package Test::XT::DC::Messaging::Producer::PRL::Prepare;

=head1 NAME

Test::XT::DC::Messaging::Producer::PRL::Prepare

=head1 DESCRIPTION

Check the deliver message sending.

#TAGS goh fulfilment prepare prl

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
use XTracker::Config::Parameters 'sys_param';

sub startup : Test(startup => 1) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    # Create a mechanism for sending XT messages
    $self->{factory} = Test::XTracker::MessageQueue->new;
}

sub send_prepare_message_simple :Tests {
    my $self = shift;
    $self->_send_prepare_message();
}

sub send_prepare_message_with_extra_parameter :Tests {
    my $self = shift;
    $self->_send_prepare_message({
        deliver_within_seconds => 60,
        destination            => 'direct_lane',
    });
}

sub _send_prepare_message {
    my ($self, $args) = @_;

    my $allocation_args = {
        how_many     => 1,
        storage_type => $PRODUCT_STORAGE_TYPE__HANGING,
    };

    my ($allocation) = @{ $self->_create_allocations( $allocation_args ) };

    my $amq = $self->{factory};

    my ($destination) = $allocation->prl->amq_queue;

    $amq->clear_destination($destination);

    my $keys_to_check = {
        allocation => $allocation,
    };

    for my $key (qw/deliver_within_seconds destination/) {
        next unless $args->{$key};

        $keys_to_check->{ $key } = $args->{ $key };
    }

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Prepare' => $keys_to_check,
        );
    } 'Sent a Prepare message.';

    # We want to check that the delivery destination has been set up
    # correctly. But we don't want that value in the $keys_to_check hash
    # as transform_and_send() is called, because it will override the
    # code that sets that value automatically. So we add to the hash
    # *after* the message has been sent.
    if (!exists $keys_to_check->{destination}) {
        if (my $destination_row = $allocation->get_prl_delivery_destination) {
            $keys_to_check->{destination} = $destination_row->message_name;
        }
    }
    delete $keys_to_check->{allocation};
    $keys_to_check->{allocation_id} = $allocation->id;

    if ($allocation->is_single_item_shipment &&
        $destination eq 'direct_lane') {
        $keys_to_check->{deliver_within_seconds} //=
            sys_param('prl_pick_scheduler_v2/deliver_within_seconds');
    }

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
            type => 'prepare',
        }),
        assert_body => superhashof($keys_to_check),
        assert_count => 1,
    },"message was sent to $destination with the corrent content");

    # clean up
    $amq->clear_destination($destination);
}

sub _create_allocations {
    my $self = shift;
    my $args = shift;

    my $storage_type = $args->{storage_type} // $PRODUCT_STORAGE_TYPE__FLAT;

    # Create orders
    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $storage_type,
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

