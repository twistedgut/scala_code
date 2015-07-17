package XTracker::Stock::Actions::SetBagAndTag;

use strict;
use warnings;

use XTracker::Constants::FromDB qw( :delivery_action :stock_process_status );
use XTracker::Database::Logging qw( log_delivery );
use XTracker::Database::StockProcess;
use XTracker::Error;
use XTracker::Handler;

use Safe::Isa;
use Try::Tiny;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema = $handler->schema;

    my $operator_id = $handler->operator_id;

    my $redirect_url = '/GoodsIn/BagAndTag';
    # These defaults smell fishy, but don't have time to work through what the
    # correct behaviour 'should' be
    my $delivery_id = $handler->{param_of}{delivery_id} || 0;
    my $group_id = $handler->{param_of}{process_group_id} || q{};
    $group_id =~ s/^p-//i;

    # Redirect unless bagandtag flag is on
    return $handler->redirect_to( $redirect_url )
        unless ( grep { $_ && $_ eq 'on' } $handler->{param_of}{bagandtag} );

    try {
        $schema->resultset('Public::StockProcess')->bag_and_tag($group_id);
        xt_success( "PGID $group_id bagged and tagged" );
    }
    catch {
        xt_warn( $_ );
        # If the PGID isn't in the correct status (Approved) we shouldn't
        # redirect to the delivery's page
        $redirect_url .= "/Book?delivery_id=$delivery_id"
            unless $_->$_isa('NAP::XT::Exception::Stock::IncorrectStatusForPGIDAction');
    };

    # redirect to list/form
    return $handler->redirect_to( $redirect_url );
}

1;
