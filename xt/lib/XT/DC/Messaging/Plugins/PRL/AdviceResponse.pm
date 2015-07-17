package XT::DC::Messaging::Plugins::PRL::AdviceResponse;

use NAP::policy "tt", 'class';

use Data::Dumper; # for error log messages
use DateTime;

# Fasten your seat belts, we're entering LIST PROCESSING LAND!!
use List::MoreUtils qw/all/;

use XTracker::Constants qw/
    :prl_type
/;
use XTracker::Constants::FromDB qw/
    $STOCK_PROCESS_STATUS__PUTAWAY
    $STOCK_PROCESS_TYPE__FASTTRACK

    :putaway_prep_container_status
    :putaway_prep_group_status
/;
use XTracker::Database::StockProcess qw/get_putaway_type get_process_group_total/;
use XTracker::Logfile qw(xt_logger);
use XTracker::Database::Recode;

use NAP::DC::Barcode::Container;

my $log = xt_logger(__PACKAGE__);

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::AdviceResponse - Handle Advice Response message from PRL

=head1 DESCRIPTION

Create a row in the putaway table, and call complete_putaway on it.

The inventory has actually already been stored in the PRLs.

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'advice_response' }

=head2 handler

=head3 Description

Receives the class name, context, and pre-validated payload.

=head3 See also

=over 4

=item *

XT::DC::Messaging::Consumer::XTWMS->stock_received

=item *

XTracker::Stock::Actions::SetPutaway->handler

=item *

http://jira4.nap/browse/DCA-669

=back

=cut

sub handler {
    my ( $self, $c, $payload ) = @_;
    try {
        my $container_id = NAP::DC::Barcode::Container->new_from_id(
            $payload->{'container_id'},
        );
        my $schema = $c->model('Schema');

        # Attempt to find the PutawayPrepContainer that this is referencing
        my $pp_container = $schema->resultset('Public::PutawayPrepContainer')
            ->find_in_transit({ container_id => $container_id })
                or die "Can't find an appropriate PutawayPrepContainer record "
                     . "for container '$container_id'\n";

        # If it's a migration container, we want to send container_empty to
        # Full PRL at this point
        if ($pp_container->does_contain_only_migration_group) {
            $pp_container->send_container_empty_to_full_prl;
        }

        if ( $payload->{'success'} eq $PRL_TYPE__BOOLEAN__TRUE ) {
            $log->debug('success');
            $pp_container->advice_response_success( $c->model('MessageQueue') );
        }
        else {
            $log->debug('failure');
            $pp_container->advice_response_fail( $payload->{reason} );
        }

    }
    catch {
        die "$_. Message: " . Dumper($payload) . "\n";
    };

    return;
}

1;
