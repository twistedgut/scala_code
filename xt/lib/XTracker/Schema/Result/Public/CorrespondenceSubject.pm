use utf8;
package XTracker::Schema::Result::Public::CorrespondenceSubject;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.correspondence_subject");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "correspondence_subject_id_seq",
  },
  "subject",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "correspondence_subject_subject_channel_id_key",
  ["subject", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "correspondence_subject_methods",
  "XTracker::Schema::Result::Public::CorrespondenceSubjectMethod",
  { "foreign.correspondence_subject_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:diNfBOVYJB481zKa1kutGg


=head2 get_enabled_methods

    $hash_ref   = $self->get_enabled_methods( { opt_outable_only => 1 } );

This returns a Hash Ref containing the Correspondence Methods that are assigned to the Subject in the
'correspondence_subject_method' table. If you pass in the optional Argument of 'opt_outable_only'
then it will only return those Methods that a Customer can Opt Out of Receiving.

It will NOT return any Methods where the 'enabled' flag is FALSE on either the
'correspondence_method' table or on the 'correspondence_subject_method' table.

Returns:
    {
        correspondence_method_id => {
                        method => 'Public::CorrespondenceMethod',
                        can_opt_out => TRUE or FALSE
                        default_can_use => TRUE or FALSE
                    },
        ...
    }

=cut

sub get_enabled_methods {
    my ( $self, $args )     = @_;

    my $search_args = {
                'me.enabled' => 1,
                'correspondence_method.enabled' => 1,
            };
    if ( exists( $args->{opt_outable_only} ) ) {
        $search_args->{'me.can_opt_out'}    = $args->{opt_outable_only};
    }

    my %methods = map {
                        $_->correspondence_method_id => {
                                    method      => $_->correspondence_method,
                                    can_opt_out => $_->can_opt_out,
                                    default_can_use => $_->default_can_use,
                                    csm_rec     => $_,
                                },
                    } $self->correspondence_subject_methods
                                ->search(
                                            $search_args,
                                            {
                                                join => 'correspondence_method',
                                            }
                                        )->all;

    return ( %methods ? \%methods : undef );
}


1;
