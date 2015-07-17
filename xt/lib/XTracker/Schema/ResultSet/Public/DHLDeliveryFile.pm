package XTracker::Schema::ResultSet::Public::DHLDeliveryFile;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use XTracker::Config::Local 'config_var';

=head1 DHLDeliveryFile

This object represents a file from DHL with delivery information
that needs to be processed and imported into our system.

A script, script/dhl_delivery_file which is running as a cron job
uses this db table as a mechanism for recording what files are
still to process and so forth.

=cut

=head2 unprocessed

Returns a dbix search result (which can be extended) of unprocessed
items.

=cut

sub unprocessed {
    my $max_failures = config_var('DHL_FFSTATFile', 'max_failures');

    return shift->search({
        processed => 0,
        failures => { '<' => $max_failures }
    }, {
        order_by => [
            'remote_modification_epoch',
            'filename'
        ]
    });
}

=head2 get_next_file_to_process

Returns a single row representing the next file to be processed.
Returns undef if there is no more work to do.

=cut

sub get_next_file_to_process {
    return shift->unprocessed->search(undef, { rows => 1 })->single;
}

=head2 get_remaining_count

Returns the number of jobs in an unprocessed state, that can be
used to query the effeciency / accuracy of the solution.

side note: ./script/dhl_delivery_file.pl --status will use this
to tell you if the script has more work to do.

=cut

sub get_remaining_count {
    return shift->unprocessed->count;
}

1;
