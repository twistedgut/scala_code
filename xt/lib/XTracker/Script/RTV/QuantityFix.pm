package XTracker::Script::RTV::QuantityFix;

use NAP::policy "tt", 'class';

extends 'XT::Common::Script';

use Data::Dump 'pp';
use List::Util 'sum';
use Time::HiRes 'sleep';
use XTracker::Constants::FromDB qw/:flow_status/;
use XTracker::WebContent::StockManagement::Broadcast;

with 'XTracker::Script::Feature::Schema';

=head1 NAME

XTracker::Script::RTV::QuantityFix

=head1 SYNOPSIS

    XTracker::Script::RTV::QuantityFix->new(%options)->invoke;

=head2 OPTIONS

=over

=item dryrun

Roll back any updates.

=back

=cut

=head1 DESCRIPTION

Look at the wrapper script for the description.

=cut

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

# For throttling the messages to send to product service
has sleep_every => (
    is      => 'ro',
    isa     => 'Int',
    default => 100000,
);

has sleep_length => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

# As we need to send variant_ids that have had changes made to them against the
# quantity table, let's store them here. This should contain a hash with the
# following structure: C<< { $channel_id => { $variant_id => 1 } } >> - we
# store a hashref instead of a list of variant_ids so we don't send duplicate
# messages.
my %variant_ids_to_broadcast;

sub invoke {
    my $self = shift;

    say "*** THIS SCRIPT IS DOING A DRY RUN AND WON'T MAKE ANY CHANGES ***\n"
        if $self->dryrun;
    my $txn_method = $self->dryrun ? 'txn_dont' : 'txn_do';

    $self->schema->$txn_method(sub{
        $self->delete_main_dead_from_rtv_quantity;
        $self->update_rtv_quantity;
        $self->delete_quantities_in_rtv_only;
    });
    # broadcast_variant_ids seemed to send messages successfully but they
    # didn't appear on the topic. Weirdness. Instead of investigating as a
    # massive band-aid (my apologies) let's just print the command to run
    # script/sync_sizes_with_ps.pl and get that to do send the messages as it
    # worked
    #$self->broadcast_variant_ids;
    $self->print_output_for_sync_sizes_with_ps;
    say $self->dryrun ? 'Rolled back' : "\nDone";
}

sub print_output_for_sync_sizes_with_ps {
    my $self = shift;
    my %pid;
    for my $variant_id ( map { keys %$_ } values %variant_ids_to_broadcast ) {
        my $product_id = $self->schema->resultset('Public::Variant')
            ->search( { id => $variant_id } )
            ->get_column('product_id')
            ->single;
        $pid{$product_id} = 1;
    }
    say join q{ },
        q{Printing output to be pasted into script to send messages to product},
        q{service - make sure you're in xt's root directory (i.e. run 'cd/opt/xt/deploy/xtracker'):};
    say sprintf(
        'perl script/sync_sizes_with_ps.pl --throttle %d/%d ',
        $self->sleep_length, $self->sleep_every )
      . join q{ }, map { "--pid $_" } sort { $a <=> $b } keys %pid;
}

sub broadcast_variant_ids {
    my $self = shift;

    for my $channel_id ( sort { $a <=> $b } keys %variant_ids_to_broadcast ) {
        print $self->render_title(
            "Sending quantity updates to product service for channel_id $channel_id"
        );
        state $count = 0;
        try {
            my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
                schema => $self->schema,
                channel_id => $channel_id,
            });
            for my $variant_id (
                sort { $a <=> $b } keys %{$variant_ids_to_broadcast{$channel_id}}
            ) {
                print "Sending stock message update for $variant_id ... ";
                $broadcast->stock_update( variant_id => $variant_id );
                $broadcast->commit unless $self->dryrun;
                say 'done';
                if ( ++$count >= $self->sleep_every ) {
                    $count = 0;
                    sleep($self->sleep_length);
                }
            }
            say "\nvariant_ids for channel_id $channel_id sent successfully\n";
        }
        catch {
            say "Unexpected error: $_";
            say "Here's a dump of the variant_ids we expected to broadcast for channel_id $channel_id:\n"
              . join qq{,\n},
                sort { $a <=> $b } keys %{$variant_ids_to_broadcast{$channel_id}//{}};
        };
    }
}

sub delete_main_dead_from_rtv_quantity {
    my $self = shift;

    print $self->render_title(
        'Deleting main and dead stock from rtv_quantity'
    );
    # We need this as we don't have a $rtvq->status relationship defined :/
    my %status_map = (
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS => 'Main Stock',
        $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS => 'Dead Stock',
    );
    my $rtv_quantity_rs = $self->schema->resultset('Public::RTVQuantity')->search(
        { status_id => [ keys %status_map ], },
        { order_by => [ qw/status_id variant_id id/ ] },
    );
    for my $rtvq ( $rtv_quantity_rs->all ) {
        say sprintf 'Deleted %s row in rtv_quantity for variant_id %i (sku %s)',
            $status_map{$rtvq->status_id}, $rtvq->variant_id, $rtvq->variant->sku;
        $rtvq->delete;
    }
}

sub prepare_quantities {
    my $self = shift;

    my $quantity_rs = $self->schema->resultset('Public::Quantity')->search({
        status_id => [
            $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
            $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        ],
    });
    my $struct;
    for my $quantity ( $quantity_rs->all ) {
        die sprintf 'variant %i already exists at location %i',
            $quantity->variant_id, $quantity->location_id
                if grep {
                    exists $struct->{$_->variant_id}
                 && exists $struct->{$_->variant_id}{$_->location_id}
                } $quantity;
        push @{$struct->{$quantity->variant_id}{$quantity->location_id}}, {
            quantity_id => $quantity->id,
            quantity => $quantity->quantity,
            status_id => $quantity->status_id,
        };
    }
    return $struct;
}

sub delete_quantities_in_rtv_only {
    my $self = shift;

    my $schema = $self->schema;
    my $rtv_quantity_rs = $schema->resultset('Public::RTVQuantity')->search({
        status_id => [
            $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
            $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        ],
    });
    my (%not_found,%unmatched);
    for my $rtv_quantity ( $rtv_quantity_rs->all ) {
        my $quantity = $schema->resultset('Public::Quantity')->search({
            location_id => $rtv_quantity->location_id,
            variant_id => $rtv_quantity->variant_id,
            status_id => [
                $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
                $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
            ],
        })->first;
        # If we have a quantity...
        if ( $quantity ) {
            my $rtvq_rs = $schema->resultset('Public::RTVQuantity')->search({
                location_id => $quantity->location_id,
                variant_id => $quantity->variant_id,
                status_id => [
                    $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
                    $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
                ],
            });
            # ... we exclude rows that have matching sums in the same location
            next if ($rtvq_rs->get_column('quantity')->sum//0) == $quantity->quantity;
            # Otherwise we have mismatching quantities... let's record this
            push @{$unmatched{$quantity->variant_id}{$quantity->location_id}},
                $rtvq_rs->get_column('quantity')->all;
            next;

        }
        push @{$not_found{$rtv_quantity->variant_id}}, {
            rtv_quantity_id => $rtv_quantity->id,
            location_id => $rtv_quantity->location_id,
            quantity => $rtv_quantity->quantity,
        };
    }
    print $self->render_title(
        'rtv_quantity rows without matches in the quantity table'
    );
    my $count = 0;
    for my $variant_id ( sort { $a <=> $b } keys %not_found ) {
        if ( @{$not_found{$variant_id}} > 1 ) {
            say "More than one rtv_quantity for variant_id $variant_id - can't just delete: "
                . pp $not_found{$variant_id};
            next;
        }
        my $rtvq = $schema->resultset('Public::RTVQuantity')->find(
            $not_found{$variant_id}[0]{rtv_quantity_id}
        );
        say sprintf 'Deleted %i items of sku %s (variant_id %i) at %s',
            $rtvq->quantity, $rtvq->variant->sku, $rtvq->variant_id, $rtvq->location->location;
        $rtvq->delete;
        $count++;
    }
    say "\nDeleted $count";

    print $self->render_title(
        'rtv_quantity rows without matching quantities in quantity table'
    );
    say "total @{[scalar keys %unmatched]} " . pp \%unmatched;
}

sub ok_rows {
    my ( $self, $struct ) = @_;

    my %seen;
    # We need to loop once to create a hash of all seen/ok quantities before
    # actually doing the updates
    while ( my ( $variant_id, $l_hash ) = each %$struct ) {
        while ( my ( $location_id, $stocks ) = each %$l_hash ) {
            for my $stock ( @$stocks ) {
                # Check if we have matches
                my $rtv_quantity = $self->schema->resultset('Public::RTVQuantity')->search({
                    location_id => $location_id,
                    variant_id => $variant_id,
                    status_id => $stock->{status_id},
                });
                # If we have a quantity match we can skip this quantity later
                next unless $stock->{quantity}
                         == ($rtv_quantity->get_column('quantity')->sum//0);
                # Mark this quantity as seen/ok
                $seen{$variant_id}{$stock->{quantity_id}}++;
                # Also mark this rtv_quantity as seen/ok
                push @{$seen{$variant_id}{rtv_quantity_ids}},
                    $rtv_quantity->get_column('id')->all;
            }
        }
    }
    return %seen;
}

sub update_rtv_quantity {
    my $self = shift;

    my $struct = $self->prepare_quantities();
    my %seen = $self->ok_rows($struct);

    print $self->render_title( 'Fix quantity rows' );

    my $schema = $self->schema;
    # quantity_only and updated are actually unused... keeping here for
    # debugging purposes
    my ($quantity_only, $multiple_rtvs, $updated, $unmatched);
    my ($deleted_count, $updated_count) = (0,0);
    # Check against complete matches (variant_id, quantity, status_id)
    for my $variant_id ( sort { $a <=> $b } keys %$struct ) {
        while ( my ( $location_id, $stocks ) = each %{$struct->{$variant_id}} ) {
            for my $stock ( @$stocks ) {
                # Skip quantities we know are ok
                next if $seen{$variant_id}{$stock->{quantity_id}};
                # Check if we have a match without the location_id
                my @rtv_quantities = $schema->resultset('Public::RTVQuantity')->search({
                    variant_id => $variant_id,
                    # Exclude rtv quantities we know are ok
                    id => { -not_in => ($seen{$variant_id}{rtv_quantity_ids}||[]) },
                    status_id => $stock->{status_id},
                });
                # No matches in rtv_quantity - these items are basically
                # unactionable
                unless ( @rtv_quantities ) {
                    push @{$quantity_only->{$variant_id}}, [
                        @{$stock}{qw/quantity_id quantity/},
                    ];
                    my $to_delete = $schema->resultset('Public::Quantity')->find($stock->{quantity_id});
                    say sprintf "Deleted variant_id %i (sku %s) at location %s (id %i) with %i items",
                        map {
                            $_->variant_id, $_->variant->sku, $_->location->location, $_->location_id, $_->quantity
                        } $to_delete;
                    $variant_ids_to_broadcast{$to_delete->channel_id}{$to_delete->variant_id} = 1;
                    $to_delete->delete;
                    $deleted_count++;
                    next;
                }
                # We don't know which one to update if we have > 1 match...
                if ( @rtv_quantities > 1 ) {
                    push @{$multiple_rtvs->{$variant_id}}, {
                        $stock->{quantity_id} => [map { $_->id } @rtv_quantities]
                    };
                    next;
                }
                # If our quantities don't match then we can't perform this update
                if ( $stock->{quantity} != sum(map { $_->quantity } @rtv_quantities) ) {
                    push @{$unmatched->{$variant_id}}, $stock->{quantity_id};
                    next;
                }
                # We have found our items to update, so do it!
                $_->update({location_id => $location_id}) for @rtv_quantities;
                die "Variant $variant_id has already been updated"
                    if $updated->{$variant_id};
                $updated->{$variant_id} = $stock->{quantity_id};
                $updated_count++;
                say sprintf(
                    "Updated location for rtv_quantity row (id %i) variant_id $variant_id (sku %s) to location %s (id $location_id)",
                    $_->id, $_->variant->sku, $_->location->location
                ) for map { $_ } @rtv_quantities;

                # We've dealt with this quantity - so skip it next time around
                $seen{$variant_id}{$stock->{quantity_id}}++;
                push @{$seen{$variant_id}{rtv_quantity_ids}},
                    map { $_->id } @rtv_quantities;
            }
        }
    }
    #say "total @{[scalar keys %$quantity_only]} quantity only " . pp $quantity_only;
    #say "total @{[scalar keys %$updated]} updated " . pp $updated;

    print <<EOS

Deleted $deleted_count rows
Updated $updated_count rows
EOS
    ;

    print $self->render_title( q{Rows that couldn't be fixed automatically} );
    say "total @{[scalar keys %$unmatched]} unmatched quantities " . pp $unmatched;
    say "total @{[scalar keys %$multiple_rtvs]} multiple matching rtv_quantity rows " . pp $multiple_rtvs;
}

sub render_title {
    my ( $self, $title, $args ) = @_;
    my $border = $args->{border} // 3;
    my $padding = $args->{padding} // 1;
    my $border_el = $args->{border_el} // q{/};

    my $padded_title = (q{ } x $padding) . $title . (q{ } x $padding);

    my ( $top_bottom_border, $top_bottom_padding, $content ) = map {
        ($border_el x $border) . $_ . ($border_el x $border)
    } (q{/} x length $padded_title), (q{ } x length $padded_title), $padded_title;
    return join q{}, map { $_ . qq{\n} }
        q{},
        $top_bottom_border,
        $top_bottom_padding,
        $content,
        $top_bottom_padding,
        $top_bottom_border,
        q{};
}
