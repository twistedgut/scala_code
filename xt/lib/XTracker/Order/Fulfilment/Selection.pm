package XTracker::Order::Fulfilment::Selection;
use strict;
use warnings;
use XTracker::Handler;
use XTracker::Config::Parameters qw( sys_param );
use XTracker::Config::Local qw( config_var );

use Data::Page;
use Data::Dump qw( pp );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/fulfilment/selection.tt';
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Selection';
    $handler->{data}{subsubsection} = 'Priority List';

    my $auto_select_shipments = sys_param('fulfilment/selection/enable_auto_selection') // 0;
    my $selection = $handler->{param_of}{selection};
    $handler->{data}{manual_selection} = !$auto_select_shipments;
    $handler->{data}{selection_type} = (!$auto_select_shipments ? 'pick'   : 'prioritise');

    my $page     = $handler->{param_of}{'page'} || 1;
    my $per_page = 50;

    if($selection) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => '/Fulfilment/Selection' } );
    } else {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Transfer Shipments', 'url' => '/Fulfilment/Selection?selection=transfer' } );
    }
    $handler->{data}{selection} = $selection;

    my $schema = $handler->{schema};

    # Grab selection shipments, filter by given shipment_id if necessary
    my $shipments = (($selection && $selection eq "transfer")
        ? $schema->resultset('Public::Shipment')->get_transfer_selection_list()
        : $schema->resultset('Public::Shipment')->get_order_selection_list()
    );
    $shipments = $shipments->search({ id => $handler->{param_of}{'shipment_filter'} }) if $handler->{param_of}{'shipment_filter'};

    # Add pager stuff for EN-803
    $handler->{data}{pager} = Data::Page->new();
    $handler->{data}{pager}->current_page($page);
    $handler->{data}{pager}->entries_per_page($per_page);
    $handler->{data}{pager}->total_entries( $shipments->count );

    # Only need the objects from this page
    $shipments = $shipments->search(undef, {
        page    => $page,
        rows    => $per_page,
    });
    my @shipments = $shipments->all();
    $handler->{data}{shipments} = \@shipments;

    # Work out totals for PRLs on this page
    $handler->{data}{prls_used} = $shipments->get_prl_totals();

    # And total shipment items, PRLs are more picky (only count items that have been PRL allocated)
    if(config_var('PRL', 'rollout_phase')) {
        $handler->{data}{total_items} += $_ for values %{$handler->{data}{prls_used}};
    } else {
        # First version (commented out) below should work, but doesn't seem to return the correct total :/
        #$handler->{data}{total_items} = $shipments->search_related('shipment_items')->count;
        $handler->{data}{total_items} += $_->shipment_items->count for @shipments;
    }

    return $handler->process_template( undef );
}

1;
