package XTracker::Stock::ChannelTransfer::Overview;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::ChannelTransfer qw( get_channel_transfers get_product_channel_transfers);
use XTracker::Constants::FromDB qw( :channel_transfer_status );
use Data::Page;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Channel Transfer';
    $handler->{data}{subsubsection} = 'Requested';
    $handler->{data}{status_id}     = $CHANNEL_TRANSFER_STATUS__REQUESTED;
    $handler->{data}{content}       = 'stocktracker/channel_transfer/overview.tt';
    $handler->{data}{view}          = $handler->{param_of}{view} // '';
    $handler->{data}{page}          = $handler->{param_of}{'page'} || 1;
    $handler->{data}{iws_rollout_phase} = $handler->iws_rollout_phase; # pass on the override, for testing

    if ( $handler->{param_of}{list_type} ) {
        if ( $handler->{param_of}{list_type} eq 'Picking' ) {
            $handler->{data}{subsubsection} = 'Picking';
            $handler->{data}{status_id}     = $CHANNEL_TRANSFER_STATUS__SELECTED;
        }
        elsif ( $handler->{param_of}{list_type} eq 'Incomplete' ) {
            $handler->{data}{subsubsection} = 'Incomplete Pick';
            $handler->{data}{status_id}     = $CHANNEL_TRANSFER_STATUS__INCOMPLETE_PICK;
        }
        elsif ( $handler->{param_of}{list_type} eq 'Putaway' ) {
            $handler->{data}{subsubsection} = 'Putaway';
            $handler->{data}{status_id}     = $CHANNEL_TRANSFER_STATUS__PICKED;
        }
        elsif ( $handler->{param_of}{list_type} eq 'Complete' ) {
            $handler->{data}{subsubsection} = 'Completed Transfers';
            $handler->{data}{status_id}     = $CHANNEL_TRANSFER_STATUS__COMPLETE;
        }
        elsif ( $handler->{param_of}{list_type} eq 'Search'   ) {
            $handler->{data}{subsubsection} = 'Search';
            $handler->{data}{scan} = {
                action    => '/StockControl/ChannelTransfer',
                field     => 'product_id',
                name      => 'Product Id',
                list_type => 'Search',
            };

        }

        # pass list type into a search terms array so paging links maintain query string
        $handler->{data}{search_terms} = { 'list_type' => $handler->{param_of}{list_type} };
    }

    if ( $handler->{data}{view} ne 'HandHeld' ) {
        # get list of transfers
        if ($handler->{param_of}{product_id}){
            $handler->{data}{transfers} = get_product_channel_transfers( $handler->{dbh}, { product_id => $handler->{param_of}{product_id}} );
            $handler->{data}{submitted} = 1;
        }
        elsif( ($handler->{param_of}{list_type} // '') ne 'Search'){
            $handler->{data}{transfers} = get_channel_transfers( $handler->{dbh}, { status_id => $handler->{data}{status_id} } );
        }
        # page results per channel
        foreach my $channel ( keys %{ $handler->{data}{transfers} } ){
            my @list;
            foreach my $sortkey ( sort {$a <=> $b} keys %{ $handler->{data}{transfers}{$channel} } ){
                push @list, $handler->{data}{transfers}{$channel}{$sortkey};
            }

            $handler->{data}{list}{$channel} = \@list;

            # page results
            my $pager       = Data::Page->new();
            $pager->current_page( $handler->{data}{page} );
            $pager->entries_per_page( 200 );
            $pager->total_entries( scalar(@list) );

            # use the slice method from the Page module to get the records for the current page
            $handler->{data}{paged_list}{$channel}    = [$pager->splice( \@list )];
            $handler->{data}{pager_channel}{$channel} = $pager;
        }


        # work out number of incomplete picks
        my $num_incomplete      = '';
        my $incomplete_picks    = get_channel_transfers( $handler->{dbh}, { status_id => $CHANNEL_TRANSFER_STATUS__INCOMPLETE_PICK } );
        if ( keys %{$incomplete_picks} ) {
            my $num = keys %{$incomplete_picks};
            $num_incomplete = ' ('. $num .')';
        }

        $handler->{data}{sidenav}       = build_sidenav( { navtype => 'channel_transfer', num_incomplete => $num_incomplete } );
    }

    return $handler->process_template;
}

1;
