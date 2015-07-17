use utf8;
package XTracker::Schema::Result::Public::PackagingAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.packaging_attribute");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "packaging_attribute_id_seq",
  },
  "packaging_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "public_name",
  { data_type => "text", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "public_title",
  { data_type => "text", is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "packaging_attribute_packaging_type_id_channel_id_key",
  ["packaging_type_id", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "packaging_type",
  "XTracker::Schema::Result::Public::PackagingType",
  { id => "packaging_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pR2DMzI3NlUNdOWx90y4gg

use DateTime;
use Moose;
with 'XTracker::Role::WithAMQMessageFactory';

=head2 product_id

Returns the C<product_id> from the L<XTracker::Schema::Result::Public::PackagingType>

=cut

sub product_id {
    my $self = shift;
    return $self->packaging_type->product_id();
}

=head2 size_id

Returns the C<size_id> from the L<XTracker::Schema::Result::Public::PackagingType>

=cut

sub size_id {
    my $self = shift;
    return $self->packaging_type->size_id();
}

=head2 sku

Returns the C<sku> from the L<XTracker::Schema::Result::Public::PackagingType>

=cut

sub sku {
    my $self = shift;
    return $self->packaging_type->sku;
}

=head2 type

Returns the C<type> from the L<XTracker::Schema::Result::Public::PackagingType>

=cut

sub type {
    my $self = shift;
    return $self->packaging_type->name;
}

=head2 business

Returns the L<XTracker::Schema::Result::Public::Business> this belongs to

=cut

sub business {
    my $self = shift;

    return $self->channel->business;
}

=head2 broadcast

Send an AMQ message containing information about this packaging "product".

=cut

sub broadcast {
    my ( $self, $args ) = @_;

    my $transformer_args = {
        packaging_attribute => $self,
    };

    if ( keys %{ $args->{envs} } ) {
        $transformer_args->{envs} = $args->{envs};
    }

    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Packaging',
        $transformer_args,
    );
}

=head2 upload

Send an AMQ message "uploading" this packaging "product".

=cut

sub upload {
    my ( $self ) = @_;

    $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::ProductService::Upload', {
        channel_id => $self->channel_id,
        pids => [ $self->product_id ],
        upload_date => DateTime->now->set_time_zone('UTC')->iso8601,
        upload_timestamp => DateTime->now->set_time_zone('UTC')->iso8601,
    });
}

1;
