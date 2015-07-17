=pod

=head1 NAME

    XTracker::Schema::ResultSet::Public::Quantity

=head1 DESCRIPTION

    ResultSet class for Public::Quantity

=head1 METHODS

=over 4

=cut

package XTracker::Schema::ResultSet::Public::Quantity;
use strict;
use warnings;
use Moose;
with 'XTracker::Role::WithPRLs';
extends 'DBIx::Class::ResultSet';
use Scalar::Util 'blessed';
use Log::Log4perl ':easy';
use List::MoreUtils 'any';
use XTracker::Constants::FromDB qw( :flow_type );
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw(
    :flow_type
    :stock_action
    :flow_status
    :pws_action
    :variant_type
);
use XTracker::WebContent::StockManagement;
use XTracker::Logfile 'xt_logger';
use XTracker::Config::Local qw( config_var );
use NAP::XT::Exception::Stock::RTVQuantityMove;

=item move_stock

Allows movement of stock, including creation/deletion of quantity rows.

Requires a hashref argument as follows:

    {
        variant     => $variant_id_or_object,                           # required
        channel     => $channel_id_or_object,                           # required
        quantity    => $Int,                                            # required
        from        => {                                                # required, though can be undef
                         location       => $location_id__object__name,  # required if 'from' != undef
                         status         => $status_id_or_object,        # required if 'from' != undef
                       },
        to          => {                                                # required, though can be undef
                         location       => $location_id__object__name,  # required if 'to' != undef
                         status         => $status_id_or_object,        # required if 'to' != undef
                       },
       keep_if_zero     => $bool,                                       # optional. If set to true value, quantity row will not be deleted
                                                                                # when quantity gets to zero
       log_location_as  => $operator_id_or_object,                      # optional. If set should be operator id or object to use in
                                                                                # log_location when deleting quantity
    }

=over 8

=item *

Supplying 'from' and 'to' arguments will try to move stock in the DB

=item *

Supplying just 'to' argument (and 'from' => undef) will create stock from the given location

=item *

Supplying just 'from' argument (and 'to' => undef) will delete stock from the given location

=item *

Supplying neither 'from' nor 'to' argument will throw an error.

=back

=cut

sub move_stock {
    my ($self, $args) = @_;
    my $schema = $self->result_source->schema;

    my $valid = $self->validate_move_stock($args); # dies on error

    # is there actually anything to do
    if (defined $valid->{from} && defined $valid->{to} &&
        $valid->{from}->{location}->id == $valid->{to}->{location}->id &&
        $valid->{from}->{status}->id == $valid->{to}->{status}->id ){
        # what's the point in that. Not changing anything
        WARN("Attempt to move variant, but 'from' and 'to' locations are the same.");
        return;
    }

    $schema->txn_do(sub{
        my %keep_rtv_cols;
        my %keep_rma_detail_cols;
        if ($valid->{from}){
            my $find_method = $args->{'force'} ? 'find_or_create' : 'find';
            # decrement quantity in this location, and delete if quantity will == 0
            my $quantity = $schema->resultset('Public::Quantity')->$find_method({
                                variant_id  => $valid->{variant}->id,
                                channel_id  => $valid->{channel}->id,
                                location_id => $valid->{from}->{location}->id,
                                status_id   => $valid->{from}->{status}->id,
                            });
            die sprintf (
                'Could not find sku %s on channel %s in location %s with status %s (using %s)',
                $valid->{variant}->sku,
                $valid->{channel}->name,
                $valid->{from}{location}->location,
                $valid->{from}{status}->name,
                $find_method
            ) unless $quantity;

            # If we have a related RTV quantity row we need to make sure the
            # stock is moved from there as well
            my $rtv_quantity = $quantity->rtv_quantity;
            my ($rma_request_detail, $rma_request);

            if($rtv_quantity) {
                #... and that we preserve the data
                %keep_rtv_cols = $rtv_quantity->get_columns();
                $rma_request_detail = $rtv_quantity->rma_request_detail();

                if ($rma_request_detail) {
                    # WHM-2286 : Can't move a quantity if it is marked for RTV
                    NAP::XT::Exception::Stock::RTVQuantityMove->throw()
                        if $rma_request_detail->is_rtv();

                    %keep_rma_detail_cols = $rma_request_detail->get_columns();
                }
            }

            # If we later want to create new entries for rtv_quantity and
            # rma_request_detail, we won't want to use the original entry's PK
            delete $keep_rtv_cols{id};
            delete $keep_rma_detail_cols{id};

            if ((!$args->{'force'}) && $quantity->quantity < $valid->{quantity}){
                die "Not enough stock in 'from' location to move";
            } else {
                # WHY is this here, even if we are setting the value
                # to 0? we delete that record just afterwards…
                #
                # BUT! we have triggers on update of the quantity
                # table, and we want them to fire. So we do this
                # haly-useless update call
                my $new_quantity = ($quantity->quantity||0) - $valid->{quantity};
                $_->update({quantity => $new_quantity })
                    for (grep { $_ } ($rtv_quantity, $rma_request_detail)), $quantity;
            }
            if ($quantity->quantity == 0) {
                if ( !$valid->{keep_if_zero} ) {
                    if ($valid->{log_location_as}){
                        $quantity->delete_and_log( $valid->{log_location_as}->id );
                    } else {
                        $quantity->delete;
                    }
                }
                # We don't bother keeping an empty rtv_quantity row
                $rtv_quantity->delete if $rtv_quantity;
            }
        }
        if ($valid->{to}){
            # increment quantity in 'to' location
            my $loc_details = { variant_id  => $valid->{variant}->id,
                                channel_id  => $valid->{channel}->id,
                                location_id => $valid->{to}->{location}->id,
                                status_id   => $valid->{to}->{status}->id,
            };
            my ( $quantity, $rtv_quantity ) = map {
                $schema->resultset($_)->find($loc_details)
            } qw/Public::Quantity Public::RTVQuantity/;
            my $total_to_quantity;
            if (!$quantity){
                $total_to_quantity = $valid->{quantity};
                $schema->resultset('Public::Quantity')->create({
                    %$loc_details, quantity => $total_to_quantity,
                });
            } else {
                $total_to_quantity = $quantity->quantity + $valid->{quantity};
                $quantity->update({quantity => $total_to_quantity});
            }
            # We also need to deal with the rtv_quantity table if we had a
            # related row
            if ( %keep_rtv_cols ) {
                # We shouldn't have a discrepancy, but if we do, we assume the
                # quantity in the Public::Quantity table to be authoritative - so
                # we always use the value from above
                if ( !$rtv_quantity ) {
                    $rtv_quantity = $schema->resultset('Public::RTVQuantity')->create({
                        %keep_rtv_cols, %$loc_details, quantity => $total_to_quantity
                    });
                }
                else {
                    $rtv_quantity->update({quantity => $total_to_quantity});
                }
            }

            # Also update rma_request_detail if necessary
            my $rma_request_detail;
            $rma_request_detail = $rtv_quantity->rma_request_detail() if $rtv_quantity;
            if ($rma_request_detail) {
                $rma_request_detail->update({ quantity => $total_to_quantity });
            } elsif(%keep_rma_detail_cols) {
                $schema->resultset('Public::RmaRequestDetail')->create({
                    %keep_rma_detail_cols,
                    quantity        => $total_to_quantity,
                    rtv_quantity_id => $rtv_quantity->id(),
                });
            }
        }
    });
}

sub validate_move_stock {
    my ($self, $args) = @_;
    my $schema = $self->result_source->schema;

    my $arg_class = {
        variant         => ['XTracker::Schema::Result::Public::Variant','XTracker::Schema::Result::Voucher::Variant'],
        channel         => ['XTracker::Schema::Result::Public::Channel'],
        location        => ['XTracker::Schema::Result::Public::Location'],
        status          => ['XTracker::Schema::Result::Flow::Status'],
        log_location_as => ['XTracker::Schema::Result::Public::Operator'],
    };

    my $valid;
    my @errors;
    foreach my $arg ( qw(variant channel) ){
        unless (defined $args->{$arg}){
            push @errors, "Required argument '$arg' not defined";
            next;
        }
        if ( blessed($args->{$arg}) &&
             any {$args->{$arg}->isa($_)} @{$arg_class->{$arg}} ) {
            $valid->{$arg} = $args->{$arg};
        } elsif ($args->{$arg} =~ m/^\d+$/){
            foreach my $rs_name (@{$arg_class->{$arg}}) {
                $valid->{$arg} = $schema->resultset($rs_name)->find($args->{$arg});
                last if $valid->{$arg};
            }
            push @errors, "$arg with id $args->{$arg} not found" unless $valid->{$arg};
        } else {
            push @errors, "Required argument '$arg' must be an integer or a @{$arg_class->{$arg}} object.";
            next;
        }
    }

    if (defined $args->{quantity} && $args->{quantity} =~ m/^\d+$/ && $args->{quantity} > 0){
        $valid->{quantity} = $args->{quantity};
    } else {
        push @errors, "Required argument 'quantity' must be an integer > 0";
    }

    foreach my $ft ( qw(from to)){
        push @errors, "Argument '$ft' is required, though it can be undefined" unless exists $args->{$ft};
        next unless defined $args->{$ft}; # OK to not be defined
        unless (ref $args->{$ft} eq 'HASH'){
            push @errors, "Argument '$ft' must be a hashref if defined" unless ref $args->{$ft} eq 'HASH';
            next;
        }

        foreach my $arg (qw(location status)){
            my $val = $args->{$ft}->{$arg};
            unless (defined $val){
                push @errors, "If defined, argument '$ft' must have a key '$arg' defined";
                next;
            }
            if ( blessed($val) &&
                 any {$val->isa($_)} @{$arg_class->{$arg}} ) {
                $valid->{$ft}->{$arg} = $val;
            } elsif ($val =~ m/^\d+$/){
                foreach my $rs_name (@{$arg_class->{$arg}}) {
                    $valid->{$ft}->{$arg} = $schema->resultset($rs_name)->find($val);
                    last if $valid->{$ft}->{$arg};
                }
                push @errors, "'$ft' $arg with id $val not found" unless $valid->{$ft}->{$arg};
            } elsif ($arg eq 'location' && !ref $val && $val =~ m/\w/){
                # must be a location string
                foreach my $rs_name (@{$arg_class->{$arg}}) {
                    $valid->{$ft}->{$arg} = $schema->resultset($rs_name)->find({location => $val});
                    last if $valid->{$ft}->{$arg};
                }
                push @errors, "'$ft' location with name '$val' not found" unless $valid->{$ft}->{$arg};
            } else {
                # if it's not an object or an integer that's a problem
                my $locstr = ($arg eq 'location') ? ', a location' : '';
                push @errors, "If defined, argument '$ft' must have a key '$arg' containing an id$locstr or a @{$arg_class->{$arg}} object.";
            }
        }
        delete $valid->{$ft} unless ($valid->{$ft}->{location} && $valid->{$ft}->{status}); # don't want the key in $valid unless it's valid
    }
    push @errors, "Arguments 'from' and 'to' cannot both be undef" unless (defined $args->{from} || defined $args->{to});

    # check optional fields
    if ($args->{keep_if_zero}){
        $valid->{keep_if_zero} = $args->{keep_if_zero};
    }
    if (defined $args->{log_location_as}){
        my $val = $args->{log_location_as};
        if ( blessed($val) &&
             any {$val->isa($_)} @{$arg_class->{log_location_as}} ) {
            $valid->{log_location_as} = $val;
        } elsif ($val =~ m/^\d+$/){
            foreach my $rs_name (@{$arg_class->{log_location_as}}) {
                $valid->{log_location_as} = $schema->resultset($rs_name)->find($val);
                last if $valid->{log_location_as};
            }
            push @errors, "operator with id $val not found" unless $valid->{log_location_as};
        } else {
            # if it's not an object or an integer that's a problem
            push @errors, "If defined, argument 'log_location_as' must have a key containing an operator id or object.";
        }
    }

    # check valid flow
    if (defined $valid->{from} && defined $valid->{to} &&
        !$valid->{from}->{status}->is_valid_next($valid->{to}->{status}) ){
        push @errors, "Can't move from status '" . $valid->{from}->{status}->name . "' to '" . $valid->{to}->{status}->name . "'";
    }

    # validate 'initial' states
    if (!defined $valid->{from} && defined $valid->{to} &&
        !$valid->{to}->{status}->is_initial){
        push @errors, "Status '". $valid->{to}->{status}->name ."' is not a valid initial status."
    }

    # check location can hold status
    if (defined $valid->{to} &&
        !$valid->{to}->{location}->allows_status($valid->{to}->{status}) ){
        push @errors, "Location '" . $valid->{to}->{location}->location . "' does not accept next status '" . $valid->{to}->{status}->name . "'";
    }

    # check that status is a 'stock status' type.
    if (defined $valid->{to} &&
        $valid->{to}->{status}->type_id != $FLOW_TYPE__STOCK_STATUS ){
        push @errors, "Status type should be 'Stock Status' not '" . $valid->{to}->{status}->type->name . "'";
    }

    die join('; ', @errors)."\n" if @errors; # newline on end to suppress "at __FILE__..." stuff

    return $valid
}


=item get_empty_locations

return hashref of quantity rows with 0 quantity

=cut

sub get_empty_locations {
    my $self = shift;

    my $empties = $self->search({
        quantity                => 0,
        'product_variant.id'    => {'!=' => undef}, # Don't care about vouchers at the moment
    },{
        prefetch => ['location', 'product_variant', 'channel', 'status']
    });

    my $return;
    while (my $q = $empties->next){
        push @{$return->{$q->channel->name}}, {
            quantity_id     => $q->id,
            location        => $q->location->location,
            status          => $q->status->name,
            date            => $q->zero_date ? $q->zero_date->ymd : undef,
            time            => $q->zero_date ? $q->zero_date->hms : undef,
            product_id      => $q->product_variant->product_id,
            size_id         => sprintf("%03d", $q->product_variant->size_id),
            legacy_sku      => $q->product_variant->legacy_sku,
        };
    }
    return $return;
}

=item adjust_quantity_and_log

Does the appropriate inventory adjustment in XTracker when IWS or a PRL
sends a message relating to stock discrepancies in its own inventory.

For IWS this is the inventory_adjust message, for the PRLs it's stock_adjust.

If moving_to_transit is set (conditions for this differ between IWS and PRL
worlds), the quantity is moved into the transit location.

Returns the updated or created quantity rs.

=cut

sub adjust_quantity_and_log {
    my ($self, $args) = @_;

    my $status              = $args->{'status'};
    my $moving_to_transit   = $args->{'moving_to_transit'};
    my $quantity_change     = $args->{'quantity_change'};
    my $operator_id         = $args->{'operator_id'} // $APPLICATION_OPERATOR_ID;

    xt_logger->info(sprintf("adjust_quantity_and_log adjusting %s for SKU %s", $args->{quantity_change}, $args->{sku}));

    return if $args->{quantity_change} == 0; # Valid but pointless

    my $schema = $self->result_source->schema;

    my $variant = $schema->resultset('Public::Variant' )->find_by_sku($args->{sku},undef,1,$VARIANT_TYPE__STOCK)
               || $schema->resultset('Voucher::Variant')->find_by_sku($args->{sku});

    die "No variant found to match ".$args->{sku} unless ($variant);

    my $channel = $variant->product->get_product_channel->channel;

    if ($moving_to_transit) {
        die "On moving to XT, quantity must be negative, but is '$quantity_change'"
            unless $quantity_change < 0;
    }

    # Make sure the client code supplied matches that in the variant
    $variant->validate_client_code({
        client_code     => $args->{client},
        throw_on_fail   => 1,
    }) if $args->{client};

    my $quant;

    $schema->txn_do(
        sub {

            xt_logger->info(sprintf("adjust_quantity_and_log starting transaction for SKU %s", $args->{sku}));
            $quant = $self->adjust_or_create({
                channel_id  => $channel->id,
                variant_id  => $variant->id,
                location_id => $args->{location}->id,
                status_id   => $status->id,
            }, $quantity_change);

            if ($moving_to_transit) {
                my $transit_location = $schema->resultset('Public::Location')->get_transit_location
                    or die "Cannot find transit location";

                my $transit = $self->adjust_or_create({
                    channel_id  => $channel->id,
                    variant_id  => $variant->id,
                    location_id => $transit_location->id,
                    status_id   => $args->{transit_status_id},
                }, -$quantity_change);
            }

            $schema->resultset('Public::LogStock')->log({
                variant         => $variant,
                channel_id      => $channel->id,
                stock_action_id => $STOCK_ACTION__MANUAL_ADJUSTMENT,
                operator_id     => $operator_id,
                quantity        => $quantity_change,
                notes           => $args->{reason},
            });
            xt_logger->info(sprintf("adjust_quantity_and_log adjusted and logged for SKU %s", $args->{sku}));

            # inform the website
            if ($status->id == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS) {

                xt_logger->info(sprintf("adjust_quantity_and_log creating stock manager for main stock SKU %s", $args->{sku}));

                my $stock_manager
                    = XTracker::WebContent::StockManagement->new_stock_manager({
                    schema      => $schema,
                    channel_id  => $channel->id,
                });

                $stock_manager->stock_update(
                    quantity_change => $quantity_change,
                    variant_id      => $variant->id,
                    skip_non_live   => 1,
                    pws_action_id   => $PWS_ACTION__MANUAL_ADJUSTMENT,
                    operator_id     => $operator_id,
                    notes           => $args->{reason},
                );

                $stock_manager->commit();
                xt_logger->info(sprintf("adjust_quantity_and_log finished with stock manager for main stock SKU %s", $args->{sku}));
            }

            if ($quant->quantity() == 0) {
                $quant->delete_and_log($APPLICATION_OPERATOR_ID);
            }

            xt_logger->info(sprintf("adjust_quantity_and_log before try_to_reallocate for SKU %s", $args->{sku}));
            # If the inventory has been migrated to a new PRL
            # and was on hold because of a stock discrepancy,
            # try reallocating, as it may now be pickable.
            $quant->try_to_reallocate({
                variant     => $variant,
                operator_id => $operator_id,
                reason      => $args->{reason},
            });
            xt_logger->info(sprintf("adjust_quantity_and_log after try_to_reallocate for SKU %s", $args->{sku}));

        } # anon. sub
    ); # txn_do

    return $quant;
}

=item adjust_or_create

Takes some search criteria and a quantity change. Looks for a quantity
matching the criteria, adjusts its quantity value if it finds it, otherwise
creates new quantity row with that value.

Returns the row that was updated/created.

=cut

sub adjust_or_create {
    my ($self, $criteria, $quantity_change) = @_;

    my $quant = $self->search(
        $criteria
    )->slice(0,0)->single;

    if ($quant) {
        $quant->update({
            quantity => \ [ 'quantity + ?', [ quantity => $quantity_change ] ],
        });
        $quant->discard_changes;

    } else {
        $quant=$self->create({
            %$criteria,
            quantity => $quantity_change,
        });
    }
    return $quant;
}

=head2 filter_prl

Specializes a resultset to return only quantities in locations that are really
PRLs.

=cut

sub filter_prl {
    my $self = shift;

    my $prl_location_names = XT::Domain::PRLs::get_prl_location_names();

    return $self->search({
        'location.location' => { IN => $prl_location_names }
    }, {
        join => 'location'
    });
}

=back

=head1 AUTHOR

    amonney

=cut

1;
