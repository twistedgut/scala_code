package XTracker::Schema::ResultSet::Public::Variant;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp qw/croak/;

use XTracker::Constants::FromDB qw{
    :flow_status
    :return_status
    :shipment_item_status
    :variant_type
};
use XTracker::Constants::Regex qw{ :sku };

sub get_variant_measurements {

    my ( $resultset, $variant_id ) = @_;

    my $variant_measurements
        = $resultset->search_related(
            'variant_measurements',
            { },
            { 'order_by'      => ['variant_id','measurement_id'] },
        );

    return $variant_measurements;
}

sub get_stock_variants_by_product {

    my ( $resultset, $product_id ) = @_;

    my $variants
        = $resultset->search(
            {
                'product_id'    => $product_id,
                'type_id'       => $VARIANT_TYPE__STOCK,
            },
            { 'order_by'        => 'me.id',
              'prefetch'        => [
                'product',
                'size',
                'designer_size',
                'variant_measurements',
              ],
            },
        );

    return $variants;
}


sub _parse_find_by_sku_args {
    if ('HASH' eq ref($_[0])) {
        my %hash = %{$_[0]};
        return @hash{qw(alias dont_die_when_cant_find variant_type_id search_vouchers_too)}
    }
    else {
        return @_;
    }
}

=head2 search_by_sku($sku)

This method performs a search on the public.variant table. Its return value is
the return value for L<DBIx::Class::ResultSet::search>, so be aware as it's
context-sensitive. It B<can> return more than one result. Please don't add two
million options to it!

=cut

sub search_by_sku {
    my ( $self, $sku ) = @_;

    my ($pid,$size_id) = $sku =~ $SKU_REGEX;

    croak "'$sku' is not a valid SKU" unless $size_id and $pid;

    my $alias = $self->current_source_alias;
    return $self->search({
        "$alias.product_id" => $pid,
        "$alias.size_id"    => $size_id,
    });
}

sub find_by_sku {
    my $self = shift;
    my $sku = shift;

    my ($pid,$size_id) = $sku =~ $SKU_REGEX;

    croak "'$sku' is not a valid SKU"
      unless $size_id and $pid;

    my ($alias, $dont_die_when_cant_find,$variant_type_id, $search_vouchers_too)
        = _parse_find_by_sku_args(@_);
    $alias ||= 'me';

    my $variant;

    if (defined($variant_type_id)) {
       $variant = $self->search({
         "$alias.size_id" => $size_id,
         "$alias.product_id" => $pid,
         "$alias.type_id" => $variant_type_id
       })->first;
    } else {
       $variant = $self->search({
         "$alias.size_id" => $size_id,
         "$alias.product_id" => $pid
       })->first;
    }

    if ( !$variant && $search_vouchers_too ) {
        my $voucher_variant =
            $self->result_source->schema->resultset('Voucher::Variant');
        $variant = $voucher_variant->search({
            "$alias.size_id" => $size_id,
            "$alias.product_id" => $pid
        })->first;
    }

    if ( !$dont_die_when_cant_find ) {
        croak "PID $pid does not have a product-variant of '$sku'"
          unless $variant;
    }

    return $variant;
}

=head2 product_size_from_sku($sku) : ( $product_id, $size_id )

Split $sku into $product_id and $size_id and return a two item list
with those ($product_id and $size_id might be undef if $sku is
malformed).

=cut

sub _product_size_from_sku {
    my ($sku) = @_;
    my ($product_id, $size_id) = $sku =~ /^(\d+)-0?(\d+)$/;
    return ($product_id, $size_id);
}

sub product_size_from_sku {
    my $self = shift;
    return _product_size_from_sku(@_);
}

=head2 by_size_id

    $rs = $variant->by_size_id;

Order by Size Id.

=cut

sub by_size_id {
    my $self    = shift;

    my $me  = $self->current_source_alias;
    $self->search( {}, { order_by => "${me}.id" } );
}

=head2 dispatched_sample_quantities

Return a Public::Quantity resultset for dispatched sample shipment items.

=cut

sub dispatched_sample_quantities {
    my ( $self ) = @_;
    my @sample_statuses = (
        $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        $FLOW_STATUS__CREATIVE__STOCK_STATUS,
    );
    my $quantities = $self->search_related( 'quantities',
        {
            'quantities.status_id' => \@sample_statuses,
            'shipment_items.shipment_item_status_id' => [
                $SHIPMENT_ITEM_STATUS__DISPATCHED,
                $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
            ],
            # Note we need to restrict the resultset this way instead of using
            # the stock_transfer relation inner join as DBIC 'optimises' the
            # inner join and drops it from the generated SQL. This is a DBIC
            # bug, whether it's documented or not!
            'link_stock_transfer__shipments.stock_transfer_id' => { q{!=} => undef },
        },
        {
            join => [
                'location',
                { product_variant => {
                    shipment_items => { shipment => 'link_stock_transfer__shipments' },
                }, },
            ],
            order_by => 'location.location',
        }
    )
}

=head2 lost_sample_shipment_items

Return a Public::ShipmentItem resultset for lost sample shipment items.

=cut

sub lost_sample_shipment_items {
    # Two ways to check we have a sample shipment - either the shipment's class
    # is 'Transfer Shipment' (or 'Press' or 'Sample'?) or we check we reference
    # a stock_transfer row
    return shift->search_related( 'shipment_items',
        {
            'shipment_items.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__LOST,
            'link_stock_transfer__shipments.stock_transfer_id' => { q{!=} => undef },
        },
        { join => { shipment => 'link_stock_transfer__shipments' }, },
    );
}

=head2 get_variants_for_designer

    $result_set = $self->get_variants_for_designer( $designer_rec );

Finds all Variants for a Designer by joining to the Product table
and checking against the 'designer_id' field.

=cut

sub get_variants_for_designer {
    my ( $self, $designer ) = @_;

    return $self->search(
        {
            'product.designer_id' => $designer->id,
        },
        {
            join => 'product',
        }
    );
}

=head2 get_variant_ids_for_designer

    $result_set = $self->get_variant_ids_for_designer( $designer_rec );

Use the method 'get_variants_for_designer' to get a Result Set but only
pull out the Variant Id field from it.

=cut

sub get_variant_ids_for_designer {
    my ( $self, @params ) = @_;

    return $self->get_variants_for_designer( @params )
                    ->get_column('me.id');
}


1;
