package Test::XT::DC::Messaging::Producer::PRL::Advice;

use FindBin::libs;
use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";
use Test::XTracker::Data;
use XT::DC::Messaging::Producer::PRL::Advice;
use XTracker::Constants qw/:prl_type $DEFAULT_TOTE_COMPARTMENT_CONFIGURATION/;
use DateTime;

=head1 NAME Test::XT::DC::Messaging::Producer::PRL::Advice

Check Advice sending utilities

=head1 DESCRIPTION

Tries to send Advice message and check actual message content.

=head1 SYNOPSIS

    # Run all tests
    prove t/20-units/class/Test/XT/DC/Messaging/Producer/PRL/Advice.pm

=cut


# Check case of sending message to more than one queue
#
sub send_simple_advice:Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    $amq->clear_destination('/queue/test.1');

    my $advice_data = _get_advice_data();

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Advice' => {
                destinations => ['/queue/test.1'],
                advice => $advice_data,
            }
        );
    } 'Try to send one Advice message.';

    $amq->assert_messages({
        destination  => '/queue/test.1',
        assert_header => superhashof({
            type => 'advice',
        }),
        assert_body => superhashof($advice_data),
    }, 'Check that data structure in sent message is the same as initial.' );

    # clean up
    $amq->clear_destination('/queue/test.1');
}

sub default_compartment_configuration :Tests() {
    my $self = shift;

    my $amq = Test::XTracker::MessageQueue->new;

    $amq->clear_destination('/queue/test.1');

    my $advice_data = _get_advice_data();
    # We're testing the default value for compartment_configuration.
    delete $advice_data->{compartment_configuration};

    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Advice' => {
            destinations => ['/queue/test.1'],
            advice => $advice_data,
        }
    );

    $amq->assert_messages({
        destination  => '/queue/test.1',
        assert_header => superhashof({
            type => 'advice',
        }),
        assert_body => superhashof({
            compartment_configuration => $DEFAULT_TOTE_COMPARTMENT_CONFIGURATION,
        }),
    }, 'Default compartment configuration set correctly');

    # clean up
    $amq->clear_destination('/queue/test.1');
}

sub _get_advice_data {
    return {
        container_id => 'M1234',
        compartment_configuration => 'foobar',
        container_fullness => '95%',
        compartments => [
            {
                compartment_id => '1',
                inventory_details => [
                    {
                        client => 'NAP',
                        sku => '123123-1233',
                        quantity => '1',
                        pgid => 'p1234',
                        stock_status => 'Main Stock',
                        expiration_date => DateTime->now->strftime('%FT%T%z'),
                        returned_flag => 'N',
                    },
                ],
            }
        ]
    };
}

=head1 SEE ALSO

L<NAP::Test::Class>

L<XT::DC::Messaging::Producer::PRL::Advice>

=cut

1;
