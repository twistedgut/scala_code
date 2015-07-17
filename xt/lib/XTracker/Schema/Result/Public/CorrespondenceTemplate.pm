use utf8;
package XTracker::Schema::Result::Public::CorrespondenceTemplate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.correspondence_templates");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "correspondence_templates_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "operator_id",
  { data_type => "bigint", is_nullable => 1 },
  "access",
  { data_type => "smallint", is_nullable => 0 },
  "content",
  { data_type => "text", is_nullable => 1 },
  "department_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ordering",
  { data_type => "integer", is_nullable => 1 },
  "subject",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "content_type",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "readonly",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "id_for_cms",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "idx_correspondence_templates_name_department_id",
  ["name", "department_id"],
);
__PACKAGE__->has_many(
  "correspondence_templates_logs",
  "XTracker::Schema::Result::Public::CorrespondenceTemplatesLog",
  { "foreign.correspondence_templates_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "department",
  "XTracker::Schema::Result::Public::Department",
  { id => "department_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "order_email_logs",
  "XTracker::Schema::Result::Public::OrderEmailLog",
  { "foreign.correspondence_templates_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_email_logs",
  "XTracker::Schema::Result::Public::PreOrderEmailLog",
  { "foreign.correspondence_templates_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_email_logs",
  "XTracker::Schema::Result::Public::ReturnEmailLog",
  { "foreign.correspondence_templates_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_email_logs",
  "XTracker::Schema::Result::Public::ShipmentEmailLog",
  { "foreign.correspondence_templates_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VYVlFx4PfsGTl3sh4b+e1g

use XTracker::XTemplate;
use XTracker::Config::Local         qw( config_var );


sub render_template {
    my ( $self, $data ) = @_;
    my $content;
    my $template = XTracker::XTemplate->template;
    $template->process( \$self->content, $data , \$content );
    return $content;
}

=head2 in_cms_format

    $hash_ref   = $self->in_cms_format();

This will return the data from the 'correspondence_templates' record in the same format that we get back
when asking the CMS for an Email Template. This then allows us to easily use the 'correspondence_templates'
version of a Template if the CMS doesn't have the Email.

=cut

sub in_cms_format {
    my $self        = shift;

    # set both of these to be empty initially
    my %content = (
            text    => '',
            html    => '',
        );
    # now set the appropriate one to the 'content' of the template
    $content{ $self->content_type } = $self->content;

    return {
            language    => config_var('Customer','default_language_preference'),
            instance    => config_var('XTracker','instance'),
            subject     => $self->subject,
            country     => '',
            channel     => '',
            from_cms    => 0,
            %content,
        };
}

=head2 update_email_template

Update the content of email template to the given C<$content> and log the changes.

=cut

sub update_email_template {
    my $self        = shift;
    my $content     = shift;
    my $operator_id = shift;

    $self->update( { content => $content } );
    $self->create_related('correspondence_templates_logs', {
        operator_id                 => $operator_id
    });

   return;

}

=head2 get_most_recent_log_entry

    my $correspondence_templates_log_obj  = $self->get_most_recent_log_entry;

Returns the most recent Log record from correspondence_templates_log table.

=cut

sub get_most_recent_log_entry {
    my $self = shift;

    return $self->search_related( 'correspondence_templates_logs',
                 undef,
                 {
                    order_by => { -desc => 'id' },
                    rows => 1,
                 } )->single;
}

1;
