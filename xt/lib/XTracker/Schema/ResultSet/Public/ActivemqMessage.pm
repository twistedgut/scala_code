package XTracker::Schema::ResultSet::Public::ActivemqMessage;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use MooseX::Params::Validate qw( validated_hash );
use JSON;

=head2 log_message(:$entity, :$message_type, :$entity_type, :$queue, :$content) :

Record the ActiveMQ message in a database table. As well as the type and full
content of the message, it's possible to record a relevant entity from
the message for searching on in future.  For example, many messages refer
to a Container by its ID.

To search for logged messages that may contain multiple relevant IDs,
the operator may need to fall back to a full text search of the message content.

* 'entity' is one of the relevant entities used in the message.  It
could be any object that is serialisable (e.g. a Container object), or
a string containing an ID.

* 'message_type' should come from a field in the message class.

* 'entity_type' is the type of entity being passed in the 'entity' field,
e.g. "container" (all lowercase)

* 'queue' should contain the name of the queue to which an outgoing
message is sent.  It will be undef for incoming messages as we don't
know the queue name.

* 'content' is a JSON representation of the message. Pass it in as a
perl data structure and it will be serialised into JSON.

=cut

sub log_message {
    my ( $self, %args ) = validated_hash(
        \@_,
        message_type => { isa => 'Str' },
        entity       => { isa => 'Defined' },
        entity_type  => { isa => 'Str' },
        queue        => { isa => 'Str|Undef' },
        content      => { isa => 'HashRef' },
    );
    my $json = JSON->new->allow_blessed->convert_blessed;
    $args{entity_id} = delete $args{entity}; # rename
    $args{content} = $json->encode( $args{content} ); # encode
    $self->result_source->schema->resultset('Public::ActivemqMessage')->create(\%args);
}

=head2 filter_migration_stock_adjust() : $rs | @rows

Filter by migration stock_adjust messages.

=cut

sub filter_migration_stock_adjust {
    my $self = shift;
    return $self->search({
        message_type => "stock_adjust",
        entity_type  => "migration sku",
    });
}

=head2 migration_container_ids() : \@container_ids

Return arrayref of unique container_ids in the message content key
"migration_container_id" in this resultset.

=cut

sub migration_container_ids {
    my $self = shift;

    my $container_ids = [
        sort keys %{
            +{
                map  { $_ => 1 }
                grep { $_ }
                map  { $_->migration_container_id }
                $self->all
            }
        },
    ];

    return $container_ids;
}

1;
