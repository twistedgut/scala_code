package XTracker::Sample::SampleTransfer;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB                 qw( :department :authorisation_level );
use XTracker::Database::Channel                 qw( get_channel_config );
use XTracker::Database::Profile                 qw( get_operator );
use XTracker::Database::SampleRequest   qw( :SampleTransfer list_sample_request_dets );
use XTracker::Config::Local                             qw( sample_upload_locations );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__OPERATOR ) {
        ## Redirect to Review Requests
        my $loc = "/Sample/ReviewRequests";
        return  $handler->redirect_to($loc);
    }

    # Get all channels config info
    my $channels    = get_channel_config($handler->{dbh});
    my %locations;
    my @locations;

    # Go through each channel and get the locations available to it for Sample Uploads
    foreach ( keys %{ $channels } ) {
        my $upload = sample_upload_locations($channels->{$_});
        $locations{$_}  = $upload;
        foreach my $location ( @{ $locations{$_}{location} } ) {
        push @locations, $location
            if ( !grep { $location eq $_ } @locations ); # maintain a unique list of locations across all channels
        }
    }

    $handler->{data}{yui_enabled}        = 1;
    $handler->{data}{content}            = 'stocktracker/sample/sampletransfer.tt';
    $handler->{data}{section}            = 'Sample';
    $handler->{data}{subsection}         = 'Sample Transfer';
    $handler->{data}{subsubsection}      = "";
    $handler->{data}{tt_process_block}   = 'main_page';
    $handler->{data}{show_loc_tabs}      = 1;
    $handler->{data}{locations}          = \%locations;
    $handler->{data}{timestring}         = time;
    $handler->{data}{tab_channel_to_use} = $handler->{param_of}{active_channel}          if ( exists($handler->{param_of}{active_channel}) );
    $handler->{data}{active_location}    = $handler->{param_of}{active_location}         if ( exists($handler->{param_of}{active_location}) );

    my %search_args = (
        dbh              => $handler->{dbh},
        filter_locations => \@locations,
        order_by         => $handler->{param_of}{order_by} || 'designer'
    );
    my $transfer_items_ref;
    my $search_items;
    my $searching = 0;


    ## 'Search' button
    if ( exists($handler->{param_of}{submit_search}) ) {

        my $type = "";
        my $id   = "";

        if ( $handler->{param_of}{txt_SKU} =~ m{\A\d+-\d+\z}xms ) {
            $type = "SKU";
            $id   = $handler->{param_of}{txt_SKU};
            $handler->{data}{search_params}->{txt_SKU}      = $id;
        }
        elsif ( $handler->{param_of}{txt_PID} =~ m{\A\d+\z}xms ) {
            $type = "PID";
            $id   = $handler->{param_of}{txt_PID};
            $handler->{data}{search_params}->{txt_PID}      = $id;
        }
        elsif ( $handler->{param_of}{txt_item_ref} =~ m{\A\d+\z}xms ) {
            $type = "sample_request_det_id";
            $id   = $handler->{param_of}{txt_item_ref};
            $handler->{data}{search_params}->{txt_item_ref} = $id;
        }

        if ($type) {
            %search_args = (
                dbh              => $handler->{dbh},
                filter_locations => \@locations,
                type             => $type,
                id               => $id
            );

            $searching = 1;
            $handler->{data}{show_loc_tabs} = 0;
        }
    }

    $search_items   = list_sample_request_dets( \%search_args );
    foreach ( @$search_items ) {
        # get number of items in each channel
        $handler->{data}{channel_list}{$_->{sales_channel}} = 0             if ( !exists($handler->{data}{channel_list}{$_->{sales_channel}}) );
        $handler->{data}{channel_list}{$_->{sales_channel}}++;

        if ($searching) {
            push @{ $transfer_items_ref->{ $_->{sales_channel} } },$_;
        }
        else {
            push @{ $transfer_items_ref->{ $_->{sales_channel} }{ $_->{loc_to} } },$_;
        }
    }

    $handler->{data}{item_list} = $transfer_items_ref;


    $handler->{data}{css} = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}  = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    return $handler->process_template;
}

1;
