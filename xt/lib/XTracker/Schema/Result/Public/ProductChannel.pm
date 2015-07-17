use utf8;
package XTracker::Schema::Result::Public::ProductChannel;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_channel");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_channel_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "live",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "staging",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "visible",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "disable_update",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "cancelled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "arrival_date",
  { data_type => "timestamp", is_nullable => 1 },
  "upload_date",
  { data_type => "timestamp", is_nullable => 1 },
  "transfer_status_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "transfer_date",
  { data_type => "timestamp", is_nullable => 1 },
  "pws_sort_adjust_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "product_channel_product_id_key",
  ["product_id", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->might_have(
  "stock_summary",
  "XTracker::Schema::Result::Product::StockSummary",
  {
    "foreign.channel_id" => "self.channel_id",
    "foreign.product_id" => "self.product_id",
  },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TItuHs9Hgb4GS3qJ8JVw/A

__PACKAGE__->has_many(
    recommended_product_children => 'XTracker::Schema::Result::Public::RecommendedProduct',
    { 'foreign.product_id' => 'self.product_id',
      'foreign.channel_id' => 'self.channel_id', }
);
__PACKAGE__->has_many(
    recommended_product_parents => 'XTracker::Schema::Result::Public::RecommendedProduct',
    { 'foreign.recommended_product_id' => 'self.product_id',
      'foreign.channel_id' => 'self.channel_id', }
);
__PACKAGE__->many_to_many(
    'recommendations', recommended_product_children => 'recommended_product_channel'
);
__PACKAGE__->many_to_many(
    'recommended_with', recommended_product_parents => 'product_channel'
);

use DateTime;

=head2 is_first_arrival

Return true if this is the product has no arrival date on its channel.

=cut

sub is_first_arrival {
    return !$_[0]->arrival_date;
}

=head2 uploading_soon

Returns true if product on channel is to be uploaded within the next 3 days
(or if the product should have already been uploaded).

=cut

sub uploading_soon {
    my ( $self ) = @_;
    return unless $self->upload_date;
    my $interval = DateTime->now->subtract(days => 3);
    return DateTime->compare( $self->upload_date, $interval ) >= 0;
}

=head2 get_recommended_with_live_products

Return a Resultset::Public::RecommendedProduct object for products that are
recommended with live products.

=cut

sub get_recommended_with_live_products {
    my ( $self ) = @_;
    return $self->recommended_product_parents
                ->get_recommendations
                ->search(
        { 'product_channel.live' => 1 },
        { join => [ 'product_channel' ] }
    );
}

=head2 is_live

Return true if the product is live on this channel.

=cut

sub is_live {
    return $_[0]->live;
}


1;
