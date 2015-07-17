use utf8;
package XTracker::Schema::Result::Voucher::Product;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("voucher.product");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "upload_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "visible",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "landed_cost",
  {
    data_type => "numeric",
    default_value => "1.000",
    is_nullable => 0,
    size => [10, 3],
  },
  "value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_physical",
  { data_type => "boolean", is_nullable => 0 },
  "disable_scheduled_update",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("product_name_key", ["name", "channel_id"]);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "codes",
  "XTracker::Schema::Result::Voucher::Code",
  { "foreign.voucher_product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "stock_orders",
  "XTracker::Schema::Result::Public::StockOrder",
  { "foreign.voucher_product_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { "foreign.voucher_product_id" => "self.id" },
  { join_type => "INNER" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HPG8oaxezPwdNf1uVCzFcg

use XTracker::Constants::FromDB qw(:storage_type);
use XTracker::Image;
use XTracker::WebContent::StockManagement::Broadcast;

use Moose;
  with 'XTracker::Schema::Role::Saleable',
       'XTracker::Schema::Role::Ordered';

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :season );

use feature 'state';

=head1 NAME

XTracker::Schema::Result::Voucher::Product

=head1 METHODS

=head2 get_three_images

Calls XTracler::Image with my product id

=cut

sub get_three_images {
    my ($self, $args) = @_;
    return XTracker::Image::get_images({
        product_id => $self->id,
        schema => $self->result_source->schema,
        ( $args ? %$args : () )
    });
}

=head2 sku

See docs for L<XTracker::Schema::Result::Voucher::Variant::sku>.

=head2 size_id

See docs for L<XTracker::Schema::Result::Voucher::Variant::size_id>.

=head2 size

See docs for L<XTracker::Schema::Result::Voucher::Variant::size>.

=head2 designer_size

See docs for L<XTracker::Schema::Result::Voucher::Variant::designer_size>.

=cut

sub sku           { shift->variant->sku; }
sub size_id       { shift->variant->size_id; }
sub size          { shift->variant->size; }
sub designer_size { shift->variant->designer_size; }

sub variants {
    my $self = shift;
    return $self->search_related("variant");
}

=head2 is_live

Returns true if the voucher is live.

=cut

sub is_live {
    my ($self) = @_;
    return $self->upload_date
        && DateTime->compare($self->upload_date, DateTime->now) <= 0;
}

=head2 live

An alias for is_live

=cut

sub live { return $_[0]->is_live; }

=head2 arrival_date

Return the date when this stock order first arrived

=cut

sub arrival_date {
    my ($self) = @_;
    my $so = $self->stock_orders
                  ->related_resultset('link_delivery__stock_orders')
                  ->related_resultset('delivery')
                  ->order_by_oldest
                  ->slice(0,0)
                  ->single;

    return $so->date if $so;
}

=head2 add_code($code, \%args)

Adds a voucher.code row for this voucher and logs it into the
voucher.credit_log table. \%args accepts keys 'source', 'expiry_date' and
'send_reminder_email'

=cut

sub add_code {
    my ( $self, $code, $args ) = @_;
    delete $args->{send_reminder_email}
        if exists $args->{send_reminder_email}
       and not defined $args->{send_reminder_email};
    $args->{code} = $code;
    my $voucher_code
        = $self->add_to_codes({ map { $_ => $args->{$_} } keys %$args });
    return $voucher_code;
}

# get the weight out of the config file for Physical Vouchers only
sub weight {
    my $self    = shift;
    return ( $self->is_physical ? config_var( 'Voucher', 'weight' ) : 0 );
}

# return the hard coded designer:
# Physical: Gift Card, Virtual: Virtual Gift Card
# TODO: Make this method a Public::Designer row (e.g. see colour below).
sub designer {
    my $self    = shift;
    return ( $self->is_physical ? 'Gift Card' : 'Virtual Gift Card' );
}

=head2 fabric_content

Get the fabric content out of the config file for Physical Vouchers only

=cut

sub fabric_content {
    my $self    = shift;
    return ( $self->is_physical ? config_var( 'Voucher', 'fabric_content' ) : '' );
}

=head2 country_of_origin

Get the country of origin out of the config file

=cut

sub country_of_origin {
    return config_var( 'Voucher', 'country_of_origin' );
}

=head2 hs_code() : hs_code_row

Return an HSCode DBIC row to emulate relationship on regular products.

=cut

sub hs_code {
    my $self    = shift;
    return $self->result_source->schema->resultset('Public::HSCode')->new({
        hs_code => ($self->is_physical ? config_var( 'Voucher', 'hs_code' ) : 'None'),
        active => 1,
    });
}

=head2 shipping_attributes

Contains what would be found by the
Database::Shipment::get_product_shipping_attributes() function for normal
products, a lot of the keys are hard-coded over time these could each be a
method if we know of sensible data to put in there

=cut

sub shipping_attributes {
    my $self    = shift;

    state $country = $self->result_source->schema->resultset('Public::Country')
        ->find({country => $self->country_of_origin});

    # TODO: Should remove rows that aren't in the shipping_attribute table, so
    # we can pass this return value directly to the shipping_attribute method
    # below
    return {
        product_id           => $self->id,
        scientific_term      => q{},
        country_id           => $country->id,
        dangerous_goods_note => q{},
        packing_note         => q{},
        weight               => $self->weight,
        fabric_content       => $self->fabric_content,
        fish_wildlife        => q{0},
        fish_wildlife_source => q{},
        is_hazmat            => q{0},
        country_of_origin    => $self->country_of_origin,
        hs_code              => $self->hs_code->hs_code,
        product_type         => 'Document',
        sub_type             => 'Unknown',
        classification       => 'Unknown',
        length               => $self->is_physical ? config_var(qw/Voucher length/) : 0,
        width                => $self->is_physical ? config_var(qw/Voucher width/) : 0,
        height               => $self->is_physical ? config_var(qw/Voucher height/) : 0,
    };
}

=head2 hs_code() : hs_code_row

Return an ShippingAttribute DBIC row to emulate relationship on regular
products.

=cut

sub shipping_attribute {
    my $self = shift;

    return $self->result_source->schema->resultset('Public::ShippingAttribute')->new({
        map { $_ => $self->shipping_attributes->{$_} } qw{
            product_id
            scientific_term
            country_id
            packing_note
            weight
            fabric_content
            fish_wildlife
            fish_wildlife_source
            is_hazmat
            length
            width
            height
        }
    });
}

sub storage_type_id {
    return $PRODUCT_STORAGE_TYPE__CAGE;
}

sub storage_type {
    my ($self) = @_;
    return $self->result_source->schema->resultset('Product::StorageType')
        ->find($self->storage_type_id);
}

sub is_on_sale { return 0 }

=head2 season_id

returns the Continuity Season Id.

=cut

sub season_id {
    return $SEASON__CONTINUITY;
}

=head2 season

returns the Continuity Season.

=cut

sub season {
    my $self    = shift;

    my $schema  = $self->result_source->schema;
    return $schema->resultset('Public::Season')->find( $self->season_id );
}

=head2 delivery_logs

Get the delivery log for this product.

=cut

sub delivery_logs {
    return $_[0]->stock_orders
                ->related_resultset('link_delivery__stock_orders')
                ->related_resultset('delivery')
                ->related_resultset('log_deliveries');
}


=head2 get_product_channel

Get's the channel where the voucher currently exists
Voucher doesn't have an entry in product_channel
This is for consistency with Result::Public::Product

=cut

sub get_product_channel {
    my ($self) = @_;

    return $self;

}

sub wms_presentation_name {
    return 'Gift Voucher - '.shift->name
}

=head2 send_sku_update_to_prls

    $voucher->send_sku_update_to_prls ({'amq'=>$amq});

If PRLs are turned on, sends a message for the voucher variant to each PRL with
the latest details.

Delegates to the variant method to do it.

=cut

sub send_sku_update_to_prls {
    my ($self, $args) = @_;

    $self->variant->send_sku_update_to_prls($args);
}

sub is_voucher { return 1; }

=head2 broadcast_stock_levels

=cut

sub broadcast_stock_levels {
    my ($self) = @_;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $self->result_source->schema,
        channel_id => $self->channel_id,
    });
    $broadcast->stock_update(
        quantity_change => 0,
        product_id => $self->id,
        full_details => 0,
    );
    $broadcast->commit();

}

=head2 get_client

Return the client associated with this voucher product

=cut
sub get_client {
    my ($self) = @_;
    return $self->channel()->client();
}

=head2 colour() : $colour_row

Returns a C<Public::Colour> DBIC row to keep consistency with
C<Public::Product>. Note that this row does *not* exist in the database. Also
if you can think of a better colour go for it.

=cut

sub colour {
    return shift->result_source
        ->schema
        ->resultset('Public::Colour')
        ->new({colour => 'N/A - Voucher'});
}
1;
