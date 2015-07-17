use utf8;
package XTracker::Schema::Result::Public::DHLDeliveryFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.dhl_delivery_file");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dhl_delivery_file_id_seq",
  },
  "filename",
  { data_type => "text", is_nullable => 0 },
  "remote_modification_epoch",
  { data_type => "integer", is_nullable => 0 },
  "processed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "failures",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "successful",
  { data_type => "boolean", is_nullable => 1 },
  "created_date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "processed_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("idx_dhl_delivery_file_filename", ["filename"]);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iZMiQ4Mq6U6v2RuXXX5LoQ

use File::Spec::Functions 'catfile';
use XTracker::Config::Local 'config_var';

=head2 get_absolute_local_filename

Returns the filename the file would be on disk, including the full
path from the root. This doesn't imply exists. It is used by components
to work where the file should go in the future.

=cut

sub get_absolute_local_filename {
    my $self = shift;
    return catfile(config_var('SystemPaths', 'dhl_delivery_dir'), $self->filename);
}

=head2 file_exists_locally

returns a boolean denoting if the file is on the disk

=cut

sub file_exists_locally {
    my $self = shift;
    return (-e $self->get_absolute_local_filename());
}

=head2 delete_file

deletes the file from the disk if it exists.

=cut

sub delete_file {
    my $self = shift;

    unlink $self->get_absolute_local_filename() if ($self->file_exists_locally());
}

=head2 mark_to_reprocess

Call this if the epoch changed and you want
another crack at processing the file

=cut

sub mark_to_reprocess {
    my ($self, $new_epoch) = @_;

    $self->update({
        processed                 => 0,
        remote_modification_epoch => $new_epoch,
        failures                  => 0,
        successful                => 0,
        processed_at              => undef,
    });
}

=head2 mark_as_failed

Mark the run as a failure. Increments the failure
count for the file.

=cut

sub mark_as_failed {
    my $self = shift;

    $self->update({
        processed => 0,
        failures => \'failures + 1',
        processed_at => \'now()',
    });
}

=head2 mark_as_processed_ok

Mark this file as processed successfully

=cut

sub mark_as_processed_ok {
    my $self = shift;

    $self->update({
        processed => 1,
        successful => 1,
        processed_at => \'now()',
    });
}

1;
