package Test::XT::DC::Messaging::Producer::PRL::StockCheck;

use FindBin::libs;
use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";
use Test::XTracker::Data;
use XT::DC::Messaging::Producer::PRL::StockCheck;
use XTracker::Constants qw/:prl_type/;
use DateTime;

=head1 NAME Test::XT::DC::Messaging::Producer::PRL::StockCheck

Check StockCheck sending utilities

=head1 DESCRIPTION

Tries to send StockCheck message and check actual message content.

=head1 SYNOPSIS

    # Run all tests
    prove t/20-units/class/Test/XT/DC/Messaging/Producer/PRL/StockCheck.pm

=cut


# Check case of sending message to more than one queue
#
sub send_simple_stock_check :Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    $amq->clear_destination();

    my $stock_check_data = {
        client => 'NAP',
        pgid   => 'p1',
    };

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::StockCheck' => {
                destinations => ['/queue/test.1'],
                stock_check => $stock_check_data,
            }
        );
    } 'Try to send one StockCheck message.';

    $amq->assert_messages({
        destination  => '/queue/test.1',
        assert_header => superhashof({
            type => 'stock_check',
        }),
        assert_body => superhashof($stock_check_data),
    }, 'Check that data structure in sent message is the same as initial.' );

    # clean up
    $amq->clear_destination();
}


=head1 SEE ALSO

L<NAP::Test::Class>

L<XT::DC::Messaging::Producer::PRL::StockCheck

=cut

1;
