use utf8;
package XTracker::Schema::Result::Public::ActivemqMessage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.activemq_message");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "activemq_message_id_seq",
  },
  "message_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "entity_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "entity_type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "queue",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "content",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w0K05LX45f1QV96SBZzyEA


use JSON;
use NAP::DC::Barcode::Container;
use Clone 'clone';
use MooseX::Params::Validate qw/validated_list/;

=head2 message() : $content_hashref

Return ->content as a data structure.

=cut

sub message {
    my $self = shift;
    $self->{__message} //= JSON->new->decode( $self->content );
}

=head2 migration_container_id : $container_id | undef

Return the migration_container_id, if it exists in the message
->content, else return undef.

=cut

sub migration_container_id {
    my $self = shift;

    return $self->message->{migration_container_id};
}

=head2 sku() : $sku | undef

Return the sku, if it exists in the message ->content, else return
undef.

=cut

sub sku {
    my $self = shift;
    return $self->message->{sku};
}

=head2 delta_quantity() : $delta_quantity | undef

Return the delta_quantity, if it exists in the message ->content, else
return undef.

=cut

sub delta_quantity {
    my $self = shift;
    return abs( $self->message->{delta_quantity} );
}

=head2 duplicate_message( :field_values | undef, :message_content_values | undef ) : $activemq_message_row

Create a copy of current record. If no arguments are provided
new record will have same values.

Newly created object contains additional field in message body: corrections_at_putaway.

=cut

sub duplicate_message {
    my ($self, $object_fields, $message_content) = validated_list(
        \@_,
        object_fields   => { isa => 'HashRef', default => {}, },
        message_content => { isa => 'HashRef', default => {}, },
    );

    $message_content = {
        # clone message content so we do not amend existing message object
        %{ clone $self->message },
        %$message_content
    };

    # always provide "corrections_at_putaway" flag to message content,
    # so it is obvious to spot "fake" active MQ message records
    $message_content->{corrections_at_putaway} = 1;

    return $self->result_source->schema
        ->resultset('Public::ActivemqMessage')
        ->create({
            message_type => $self->message_type,
            entity_id    => $self->entity_id,
            entity_type  => $self->entity_type,
            queue        => $self->queue,
            content      => JSON->new->utf8->encode($message_content),
            %$object_fields,
        });
}

=head2 is_it_fake_stock_adjust_message : bool

Flag that indicate if current message record was created as a result of cloning other one.

=cut

sub is_it_fake_stock_adjust_message {
    my $self = shift;

    return !! $self->message->{corrections_at_putaway};
}

1;

