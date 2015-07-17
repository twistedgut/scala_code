package XT::JobQueue::Promotion::LyrisExport;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use XT::Domain::Promotion;
use XTracker::Logfile qw(xt_logger);

use base qw( TheSchwartz::Worker );
use base qw( XT::JobQueue::Promotion );

use Class::Std;
{
    sub start_work {
        my $self = shift;
        my ($promotion_domain);

        # get the domain
        $promotion_domain = $self->get_promotion_domain();

        # let the logs know that something is actually happening
        xt_logger->info(
              'Exporting to Lyris for promotion #'
            . $self->get_promotion_id
            . "\n"
        );

        # 1. we need to send the list of custards for the
        # promotion to Lyris
        $promotion_domain->export_to_lyris(
            $self->get_promotion_id,
        );

        return;
    }
}


1;
__END__
