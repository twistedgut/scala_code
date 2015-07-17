package XTracker::Stock::Actions::SetStockLocation;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Utilities                 qw( url_encode :string );
use XTracker::Database::Stock           qw( get_stock_location_quantity check_stock_location delete_quantity update_quantity insert_quantity );
use XTracker::Database::Logging         qw( log_location );
use XTracker::Database::Location        qw( :iws );
use XTracker::Constants::FromDB         qw( :flow_status );
use XTracker::Error;

################################################################
#
# Change for DCEA-499
#
# Previously, in theory, zero items of stock could be allocated
# to a location with this handler (although, technically, I
# think the web UI prevented that case).  Now that we use
# ::Quantity->move_stock() to do the move, that is no longer
# allowed; you have to try to move at least one item of
# stock for the move to be allowed.
#
# It's unlikely that this functional change affects anything,
# but it is a change, and so I'm drawing attention to it here.
#
#

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $product_id  = $handler->{param_of}{product_id}   || 0;
    my $variant_id  = $handler->{param_of}{variant_id}   || 0;
    my $view        = $handler->{param_of}{view}         || '';
    my $view_channel= $handler->{param_of}{view_channel} || '';

    my $redirect_url = "/StockControl/Inventory/MoveAddStock?view=$view&product_id=$product_id&variant_id=$variant_id&view_channel=$view_channel";

    my $location_updates = {};

    eval { $handler->schema->txn_do( sub {

        my %variant_data;

        # loop over form post and get location data
        # into a format we can use
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            # look for two embedded underscores, separated by anything but underscores
            if ( $form_key =~ m/_[^_]+_/ ) {
                my ($field_name,   $variant_id,   $location_id) = split( /_/, $form_key );

                if ($field_name && $variant_id && $location_id) {
                    $variant_data{ $variant_id }{ $location_id }{ $field_name } = $handler->{param_of}{$form_key};
                }
            }
        }

        # loop over variant data and update locations
        foreach my $variant_id ( keys %variant_data ) {
            foreach my $location_id ( keys %{ $variant_data{$variant_id} } ) {
                foreach my $action (  keys %{ $variant_data{$variant_id}{$location_id} } ) {
                    if ( $action eq 'delete' ) {
                        my $del_location_name = trim($variant_data{$variant_id}{$location_id}{olocation});

                        if (_delete_location( $handler, {
                                                variant_id        => $variant_id,
                                                channel_id        => $variant_data{$variant_id}{$location_id}{channel},
                                                del_location_name => $del_location_name
                                              }))
                        {
                            $location_updates->{delete}{$del_location_name} = 1;
                        }
                    }
                    elsif ( $action eq 'assign' ) {
                        my $new_location_name = trim($variant_data{$variant_id}{$location_id}{assign});
                        next unless $new_location_name; # Don't attempt to assign unless we know where...

                        if (_assign_location( $handler, {
                                                  variant_id        => $variant_id,
                                                  channel_id        => $variant_data{$variant_id}{$location_id}{channel},
                                                  new_location_name => $new_location_name
                                              }))
                        {
                            $location_updates->{assign}{$new_location_name} = 1;
                        }
                    }
                    elsif ( $action eq 'nlocation' ) {  # nlocation == 'move', obviously
                        my $cur_location_name = trim($variant_data{$variant_id}{$location_id}{olocation});
                        my $new_location_name = trim($variant_data{$variant_id}{$location_id}{nlocation});
                        my $new_quantity      = trim($variant_data{$variant_id}{$location_id}{nquantity});

                        # only if a new location & a new quantity have been provided, is this really a move
                        if ($new_location_name && $new_quantity &&
                            _transfer_location( $handler, {
                                                    variant_id        => $variant_id,
                                                    channel_id        => $variant_data{$variant_id}{$location_id}{channel},
                                                    cur_quantity      => $variant_data{$variant_id}{$location_id}{oquantity},
                                                    new_quantity      => $new_quantity,
                                                    new_location_name => $new_location_name,
                                                    cur_location_name => $cur_location_name
                                                }))
                        {
                            $location_updates->{nlocation}{$cur_location_name}{$new_location_name} = 1;
                        }
                    }
                }
            }
        }
    } ) };

    if ($@) {
        xt_warn(strip_txn_do($@));
    }
    else {
        my @success_msgs=();

        push @success_msgs,"Locations successfully assigned to: ".join(', ',sort keys %{$location_updates->{assign}})
            if exists $location_updates->{assign};

        push @success_msgs,"Locations successfully deleted: ".join(', ',sort keys %{$location_updates->{delete}})
            if exists $location_updates->{delete};

        if (exists $location_updates->{nlocation}) {
            foreach my $src_location (keys %{$location_updates->{nlocation}}) {
                push @success_msgs,"Successfully transferred from $src_location to ".join(', ',sort keys %{$location_updates->{nlocation}{$src_location}})
                    if exists $location_updates->{nlocation}{$src_location};
            }
        }

        if (@success_msgs) {
            xt_success(join('; ',@success_msgs));
        }
        else {
            xt_warn('Found nothing to do');
        }
    }

    return $handler->redirect_to( $redirect_url );
}

sub _transfer_location {
    my ( $handler, $argref ) = @_;

    my (   $cur_location_name, $new_location_name, $cur_quantity, $new_quantity, $channel_id, $variant_id ) = @{$argref}{
        qw( cur_location_name   new_location_name   cur_quantity   new_quantity   channel_id   variant_id )
    };

    die "Channel must be provided\n"
        unless $channel_id;

    die "Variant ID must be provided\n"
        unless $variant_id;

    die "Current location for transfer must be specified\n"
        unless $cur_location_name;

    die "New location for transfer must be specified\n"
        unless $new_location_name;

    die "Old and new locations must differ\n"
        if $cur_location_name eq $new_location_name;

    die "Transferred quantity ($new_quantity) must be more than zero\n"
        unless $new_quantity > 0;

    die "Transferred quantity ($new_quantity) may not exceed existing quantity ($cur_quantity)\n"
        if $new_quantity > $cur_quantity;

    die "May not move stock from location '$cur_location_name'\n"
        if matches_iws_location($cur_location_name);

    die "May not move stock to location '$new_location_name'\n"
        if matches_iws_location($new_location_name);

    my $loc_rs =  $handler->schema->resultset('Public::Location');

    my $cur_location = eval { $loc_rs->get_location({ location => $cur_location_name }); };

    die "Cannot find location '$cur_location_name', please choose another\n"
        unless $cur_location;

    # The next check ensures that the (currently true) assumption that every
    # location only allows one status holds. There are two exceptions to these
    # currently: IWS (from which we can't move stock, there's a check prior to
    # this one) and single-aisle rows in DC1 (011U999B, 011U999C, 011U999A)
    # which are now obsolete.
    my @allowed_statuses
        = sort $cur_location->allowed_statuses->get_column('name')->all;

    die ( sprintf
        "Cannot determine status of stock as location '%s' supports multiple stock statuses (%s)\n",
        $cur_location_name, join q{, }, @allowed_statuses
    ) if @allowed_statuses > 1;

    my $new_location = eval { $loc_rs->get_location({ location => $new_location_name }); };

    die "Cannot find location '$new_location_name', please choose another\n"
        unless $new_location;

    # At this point we can assume that if we have multiple quantities for the
    # same variant on the same channel at the same location (I don't know if
    # this ever happens, but the below works on resultsets, so I guess it's
    # possible), their statuses will all match.
    my $status = $cur_location->quantities({
            variant_id => $variant_id,
            channel_id => $channel_id,
        })->related_resultset('status')
        ->slice(0,0)
        ->single;

    die ( sprintf
        "Location '%s' does not accept %s, please choose another\n",
        $new_location_name, $status->name
    ) unless $new_location->allows_status($status->id);

    $handler->schema->resultset('Public::Quantity')->move_stock({
        variant  => $variant_id,
        channel  => $channel_id,
        quantity => $new_quantity,
        from => {
            location => $cur_location,
            status   => $status->id,
        },
        to => {
            location => $new_location,
            status   => $status->id,
        },
        log_location_as => $handler->operator_id,
    });

    return 1;
}

sub _assign_location {
    my ( $handler, $argref ) = @_;

    my (   $new_location_name, $variant_id, $channel_id ) = @{$argref}{
        qw (new_location_name   variant_id   channel_id )
    };

    die "Channel must be provided\n"
        unless $channel_id;

    die "Location to add stock to must be specified\n"
        unless $new_location_name;

    die "May not add stock in location '$new_location_name'\n"
        if matches_iws_location($new_location_name);
    die "Variant to assign to location '$new_location_name' must be provided\n"
        unless $variant_id;

    my $new_location = eval {
        $handler->schema->resultset('Public::Location')
                        ->get_location({ location => $new_location_name });
    };

    die "Cannot find location '$new_location_name', please choose another\n"
        unless $new_location;

    my @statuses = $new_location->allowed_statuses->all;
    die ( sprintf
        "Cannot assign variant to location '%s' as it has multiple statuses (%s)\n",
        $new_location_name, join q{, }, sort map { $_->name } @statuses
    ) if @statuses > 1;

    die "You must enter a Main Stock Location " if $statuses[0]->id != $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    my $quantity = $handler->schema->resultset('Public::Quantity')->search({
        variant_id => $variant_id,
        channel_id => $channel_id,
        status_id  => $statuses[0]->id,
    })->slice(0,0)->single;

    if ($quantity){
        die "There is already stock in this location, you may want to move instead";
    }

    insert_quantity( $handler->dbh, {
        variant_id        => $variant_id,
        location          => $new_location,
        quantity          => 0,
        channel_id        => $channel_id,
        initial_status_id => $statuses[0]->id,
    } );

    return 1;
}

sub _delete_location {
    my ( $handler, $argref ) = @_;

    my (   $del_location_name, $variant_id, $channel_id ) = @{$argref}{
        qw (del_location_name   variant_id   channel_id )
    };

    die "Channel must be provided\n"
        unless $channel_id;

    die "Location to be deleted must be specified\n"
        unless $del_location_name;

    die "May not delete location '$del_location_name'\n"
        if matches_iws_location($del_location_name);

    die "Variant for deletion location '$del_location_name' must be provided\n"
        unless $variant_id;

    my $del_location = eval {
        $handler->schema->resultset('Public::Location')
                        ->get_location({ location => $del_location_name });
    };

    die "Cannot find location '$del_location_name'; please choose another\n"
        unless $del_location;

    my @statuses = $del_location->allowed_statuses->all;
    die ( sprintf
        "Cannot delete location '%s' as it has multiple statuses (%s)\n",
        $del_location_name, join q{, }, sort map { $_->name } @statuses
    ) if @statuses > 1;

    my $quantity = get_stock_location_quantity( $handler->dbh, {
                       variant_id => $variant_id,
                       location   => $del_location,
                       channel_id => $channel_id,
                       status_id  => $statuses[0]->id,
                   } );

    die "Cannot delete location '$del_location_name' containing stock\n"
        unless $quantity == 0;

    delete_quantity($handler->dbh, {
        variant_id => $variant_id,
        location   => $del_location,
        channel_id => $channel_id,
        status_id  => $statuses[0]->id,
    } );

    log_location($handler->dbh, {
        variant_id  => $variant_id,
        old_loc     => $del_location_name,
        channel_id  => $channel_id,
        operator_id => $handler->operator_id
    } );

    return 1;
}

1;
