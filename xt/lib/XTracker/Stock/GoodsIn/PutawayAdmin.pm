package XTracker::Stock::GoodsIn::PutawayAdmin;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Navigation 'build_sidenav';
use XTracker::Logfile 'xt_logger';

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Putaway Prep Admin';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'goods_in/putaway_admin.tt';
    $handler->{data}{js}            = [ '/javascript/jquery.tablesorter.min.js' ];
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'putaway_prep_admin' } );

    # customer_returns_only = 0 means everything but customer returns
    my $customer_returns_only = 0;
    if ($handler->{param_of}->{putaway_type} &&
        $handler->{param_of}->{putaway_type} eq 'customer_returns_only'
    ) {
        $customer_returns_only = 1;
    }

    $handler->{data}->{customer_returns_only} = $customer_returns_only;

    my $groups = $handler->schema->resultset('Public::PutawayPrepInventory')
        ->prepare_data_for_putaway_admin($customer_returns_only);

    if ($groups) {
        # Show most recent ones at the top.
        my @ordered_groups = sort {$b->{last_action} <=> $a->{last_action}} values %$groups;

        # Split by type for display in different sections of the page.
        foreach my $group (@ordered_groups) {
            if ($group->{'putaway_type'} eq 'Return') {
                push @{ $handler->{data}->{stock_returns}}, $group;
            }
            elsif ($group->{'putaway_type'} eq 'SampleReturn') {
                push @{ $handler->{data}->{sample_returns}}, $group;
            }
            elsif ($group->{'putaway_type'} eq 'Recode') {
                push @{ $handler->{data}->{stock_recodes}}, $group;
            }
            elsif ($group->{'putaway_type'} eq 'Main') {
                push @{ $handler->{data}->{stock_normal}}, $group;
            }
            elsif ( $group->{putaway_type} eq 'CancelledGroup' ) {
                push @{ $handler->{data}->{cancelled_group} }, $group;
            }
            elsif ( $group->{putaway_type} eq 'MigrationGroup' ) {
                push @{ $handler->{data}->{migration_group} }, $group;
            }
        }
    }

    return $handler->process_template;
}

1;
