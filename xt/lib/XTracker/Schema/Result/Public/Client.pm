use utf8;
package XTracker::Schema::Result::Public::Client;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.client");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "client_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "prl_name",
  { data_type => "text", is_nullable => 0 },
  "token_name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("client_name_key", ["name"]);
__PACKAGE__->add_unique_constraint("client_prl_name_key", ["prl_name"]);
__PACKAGE__->add_unique_constraint("unique_token_name", ["token_name"]);
__PACKAGE__->has_many(
  "businesses",
  "XTracker::Schema::Result::Public::Business",
  { "foreign.client_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:08BEDtIkloyJOLENOO3CSA

use NAP::DC::PRL::Tokens;

__PACKAGE__->has_many(
  "businesses",
  "XTracker::Schema::Result::Public::Business",
  { "foreign.client_id" => "self.id" },
  {},
);

=head2 get_client_code

Returns the unique client code that identifies this client
    as defined in warehouse-common (used in XT, PRL and IWS)

=cut
sub get_client_code {
    my ($self) = @_;
    my $client_code = $NAP::DC::PRL::Tokens::dictionary{CLIENT}{$self->token_name()};
    die 'The token_name for client with id: ' . $self->id() . ' appears to be invalid'
        unless defined($client_code);
    return $client_code;
}

1;
