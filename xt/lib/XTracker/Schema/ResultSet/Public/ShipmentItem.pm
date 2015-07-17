package XTracker::Schema::ResultSet::Public::ShipmentItem;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw(
    :shipment_class
    :shipment_item_status
);

sub update {
    my ($self,$cols) = @_;

    # If we're not updating container_id we don't change update's behaviour
    return $self->next::method($cols) unless exists $cols->{container_id};

    # If we are, we need to log. We already have an override for update, so
    # we'll need to use that and perform the updates individually. Slow, but
    # doing bulk updates for large numbers of shipment item containers all into
    # the same container is a very unlikely scenario anyway.
    my $guard = $self->result_source->schema->txn_scope_guard;
    my @rows = $self->all;
    $_->update($cols) for @rows;
    $guard->commit;

    # update returns the number of rows that were updated
    return scalar @rows;
};

sub shipment_item_picking_date {
    my $resultset = shift;
    my $shipment_id = shift;

    my $list = $resultset->search(
        {
            shipment_id         => $shipment_id,
            'shipment_item_status_log.shipment_item_status_id'
                                => $SHIPMENT_ITEM_STATUS__PICKED,
        },
        {
            prefetch => [ qw/shipment shipment_item_status_log/ ],
            order_by => [ 'shipment_item_status_log.date DESC' ],
        },
    );

    return $list;
}

sub not_cancelled {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__CANCELLED } },
    );
}

sub cancelled {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED },
    );
}

sub not_cancel_pending {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING } },
    );
}

sub cancel_pending {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING },
    );
}

sub qc_failed {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION }
    );
}

sub missing {
    my ($self) = @_;

    $self->search(
        { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
          container_id            => undef }
    );
}

=head2 pre_picking

Filter the resultset by rows that have a status_id of 'New' or 'Selected'.

=cut

sub pre_picking {
    shift->search({shipment_item_status_id => {
        -in => [ $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED ]
    }});
}

=head2 selected

Filter the resultset by rows that have a status of 'Selected'.

=cut

sub selected {
    shift->search({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED});
}

sub are_all_new {
    my $self = shift;
    return 0 unless $self->count;

    return ! $self->search({
        shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__NEW}}
    )->count;
}

sub are_all_selected {
    my $self = shift;
    return 0 unless $self->count;

    return ! $self->search({
        shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__SELECTED}}
    )->count;
}

sub unpick {
    my ($self) = @_;

    $self->reset;

    while (my $item = $self->next) {
        $item->unpick;
    }

    return $self->reset;
}

sub pick_into {
    my ($self, @args) = @_;

    $self->reset;

    while (my $item = $self->next) {
        $item->pick_into( @args );
    }

    return $self->reset;
}


sub find_by_sku {
    my ($self, $sku) = @_;

    my $joined_rs = $self->search( { }, { join => 'variant' } );

    # Use a sub goto rather than a fn call so that the error comes from the right place
    @_ = ($joined_rs, $sku, 'variant');
    goto \&XTracker::Schema::ResultSet::Public::Variant::find_by_sku;
}

sub order_by_sku {
    my ($self) = @_;

    $self->search( undef,
        { join => [ 'variant', 'voucher_variant' ],
          order_by => [ 'variant.product_id', 'variant.size_id', 'voucher_variant.voucher_product_id' ],
        }
    );
}

sub search_by_sku {
    my($self,$sku) = @_;

    my $var_field   = 'variant_id';

    # search for a Normal Product first
    my $variant = $self->result_source
        ->schema
        ->resultset('Public::Variant')
        ->find_by_sku($sku,undef,1);

    if ( !defined $variant ) {
        # if no voucher then check for Voucher
        $variant    = $self->result_source
            ->schema
            ->resultset('Voucher::Variant')
            ->find_by_sku($sku,undef,1);
        $var_field  = 'voucher_variant_id';
    }

    die "Cannot find variant record for sku - $sku" if (!$variant);

    return $self->search({
        $var_field              => $variant->id,
    });
}

sub search_by_sku_and_item_status {
    my($self,$sku,$status_id) = @_;

    return $self->search_by_sku($sku)
        ->search({
            shipment_item_status_id => $status_id,
        });
}

sub items_in_container {
    my ($self, $container, $options) = @_;

    my $search = {
        container_id => (
            ref($container) eq "ARRAY" ? { -in => $container } : $container
        ),
    };

    $search->{shipment_id} = {"!=" => $options->{exclude_shipment}}
        if $options->{exclude_shipment};

    return $self->search_rs($search);
}

=head2 check_voucher_code

    $args   = check_voucher_code( {
                                    context     => 'qc' || 'packing',
                                    vcode       => 'voucher code',
                                    chkd_codes  => HASH Ref of codes previously checked,
                                    chkd_items  => HASH Ref of shipment items previously checked,
                                    # for 'packing' only
                                    qced_codes      => HASH Ref of codes which have gone through QC,
                                    shipment_item_id=> Shipment Item Id for Voucher SKU,
                                } );

This checks a voucher code to see if it is valid for the Physical Voucher shipment items. This can be used for the Packing Stage when the Voucher Codes are being QC'd and also when the Vouchers are being Packed.

=cut

sub check_voucher_code {
    my ( $self, $args )     = @_;

    my $context     = $args->{for};
    my $vcode       = $args->{vcode};
    my $chkd_codes  = $args->{chkd_codes};
    my $chkd_items  = $args->{chkd_items};
    my $qced_codes  = $args->{qced_codes};
    my $ship_item_id= $args->{shipment_item_id} || 0;

    my $topack_ship_item;

    my $vouch_code  = $self->result_source->schema
                                ->resultset('Voucher::Code')
                                ->find( { code => $vcode } );

    # check if voucher code exists in the table
    if ( !defined $vouch_code ) {
        return {
                success     => 0,
                err_no      => 1,
                err_msg     => "This code is faulty, please replace voucher and try again",
            };
    }
    # if this is being run for packing then check code
    # against a list of prevously QC'd voucher codes
    if ( $context eq 'packing' ) {
        if ( !grep { $vcode eq $_ } keys %{ $qced_codes } ) {
            return {
                    success     => 0,
                    err_no      => 6,
                    err_msg     => "Gift Card Code was not one of the ones that was QC'd",
                };
        }
    }
    # check if voucher code already assigned
    if ( defined $vouch_code->assigned ) {
        return {
                success     => 0,
                err_no      => 2,
                err_msg     => (
                                $context eq 'qc'
                                ? "Voucher Code found but already assigned"
                                : "Voucher Code has already been assigned"
                               ),
            };
    }

    my @items   = $self->search(
                            {
                                is_physical => 1,
                            },
                            {
                                join    => [ { voucher_variant => 'product' } ],
                                order_by=> 'me.id',
                            } )->all;
    # check voucher code is for one of the shipment item's SKUs
    my @items_match_code    = grep { $_->product_id == $vouch_code->voucher_product_id } @items;
    if ( !@items_match_code ) {
        return {
                success     => 0,
                err_no      => 3,
                err_msg     => "Voucher Code is Valid but not for one of the Shipment Items",
            };
    }
    # if being run for packing then check that the shipment item id
    # supplied matches one for the code supplied
    if ( $context eq 'packing' ) {
        ( $topack_ship_item )   = grep { $ship_item_id == $_->id } @items_match_code;
        if ( !defined $topack_ship_item ) {
            return {
                    success     => 0,
                    err_no      => 7,
                    err_msg     => "This is a Valid Code but for the Wrong SKU",
                };
        }
        if ( defined $topack_ship_item->voucher_code_id
             && $topack_ship_item->voucher_code_id > 0 ) {
            return {
                    success     => 0,
                    err_no      => 8,
                };
        }
    }
    # check if voucher code already been Checked
    if ( grep { $_ eq $vcode } keys %{ $chkd_codes } ) {
        return {
                success     => 0,
                err_no      => 4,
                err_msg     => (
                                $context eq 'qc'
                                ? "Voucher Code has already been QC'd"
                                : "Voucher Code has already been used"
                               ),
            };
    }
    # check if there have been too many codes checked for a particular SKU
    my @items_not_chkd  = grep { !exists( $chkd_items->{ $_->id } ) } @items_match_code;
    if ( !@items_not_chkd ) {
        return {
                success     => 0,
                err_no      => 5,
                err_msg     => (
                                $context eq 'qc'
                                ? "Already QC'd all of these type of Vouchers for the Shipment"
                                : "Already used all of these type of Vouchers for the Shipment"
                               ),
            };
    }

    my $shipment_item;

    if ( $context eq 'packing' ) {
        $shipment_item  = $topack_ship_item;
    }
    else {
        $shipment_item  = $items_not_chkd[0];
    }

    # push back codes & Items for future call to function
    $chkd_codes->{ $vouch_code->code }  = $shipment_item->id;
    $chkd_items->{ $shipment_item->id } = $vouch_code->code;

    return {
            success         => 1,
            voucher_code    => $vouch_code,
            shipment_item   => $shipment_item,
        };
}

=head2 container_ids

Return an unordered but distinct list of container IDs that contain these shipment items.

=cut

sub container_ids {
    my ($self) = @_;

    return uniq ($self->get_column('container_id')->all);
}

=head2 containers

Return a result set of containers that contain these shipment items,
optionally filtered by a container status ID.

=cut

sub containers {
    my ($self,$status_id) = @_;

    my $cond = {};

    if (ref($status_id)) {
        $cond = { status_id => { -in => $status_id } };
    }
    elsif ($status_id) {
        $cond = { status_id => $status_id };
    }

    return $self->search_related('container',
                                 $cond,
                                 { distinct => 1 }
                             );
}

=head2 transfer_shipments

Filter the resultset to only include shipment items that are part of a
shipment with a class of I<Transfer Shipment> (i.e. samples).

=cut

sub transfer_shipments {
    shift->search(
        { 'shipment.shipment_class_id' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT },
        { join => 'shipment' }
    );
}

=head2 is_treated_as_multitote (exclude_container_id, shipment_items)

This function takes a container_id and container's shipments items and works out
if the shipment spans multiple containers. Not only does it look for links from
ShipmentItem to other _existing_ containers, it also looks at whether there are
shipment items which haven't been packed yet, which is an indication that in the
future this shipment item will be part of a multitote shipment.

The user passes in a container id to exclude from the count because a single
container returned does not imply it is a multitote shipment item.

=cut

sub is_treated_as_multitote {
    my ($self, $exclude_container_id, $shipment_items) = @_;

    return 0 unless ($shipment_items);

    my $schema = $self->result_source->schema;

    my $count = $schema->resultset('Public::ShipmentItem')->search({
        '-or' => [ {
                container_id => { '!=' => $exclude_container_id }
            } , {
                'me.shipment_item_status_id' => { '-in' => [
                    $SHIPMENT_ITEM_STATUS__NEW,
                    $SHIPMENT_ITEM_STATUS__SELECTED,
                    $SHIPMENT_ITEM_STATUS__PICKED,
                    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                ]},
                container_id => undef
           }
       ],
       shipment_id => { '-in' => $shipment_items->get_column('shipment_id') }
    })->count;

    return ($count > 0);
}

=head2 filter_prls_without_staging_area() : $shipment_item_rs : @shipment_item_rows

Filter only the ShipmentItems with Allocations in "fast" PRLs, without
a Staging Area.

=cut

sub filter_prls_without_staging_area {
    my $self = shift;

    return $self->search(
        {
            "prl.has_staging_area" => 0,
        },
        {
            join => { "allocation_items" => {"allocation" => "prl"} }
        },
    );
}

=head2 mark_containers_out_of_pack_lane

This function marks the containers for a set of shipment items as no longer
in a pack lane.

=cut

sub mark_containers_out_of_pack_lane {
    my ($self) = @_;

    my @containers = map { $_->container } $self->search( { container_id => { '!=', undef } } );
    for my $container (@containers) {
        $container->remove_from_packlane;
    }
}

=head2 get_shipment_items_with_unique_shipments_rs_contains_shipment_id_only

Only return distinct shipments, no duplicates.

=cut

sub get_shipment_items_with_unique_shipments_rs_contains_shipment_id_only {
    my ($self) = @_;
    return $self->search({}, {
        select   => [ 'shipment_id' ],
        group_by => [ 'me.shipment_id' ],
    });
}

=head2 exclude_vouchers() : $resultset|@rows

Exclude vouchers. Can't think of an affirmative filter_$something equivalent
sadly.

=cut

sub exclude_vouchers {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "${me}.voucher_variant_id" => undef });
}

1;
