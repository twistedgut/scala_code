use utf8;
package XTracker::Schema::Result::Public::ShippingAccount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_account");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_account_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "account_number",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_cutoff_days",
  { data_type => "integer", is_nullable => 1 },
  "shipping_number",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "return_account_number",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "from_company_name",
  { data_type => "text", is_nullable => 1 },
  "shipping_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "shipping_account_name_carrier_id_channel_id_key",
  ["name", "carrier_id", "channel_id"],
);
__PACKAGE__->belongs_to(
  "carrier",
  "XTracker::Schema::Result::Public::Carrier",
  { id => "carrier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.shipping_account_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_account__countries",
  "XTracker::Schema::Result::Public::ShippingAccountCountry",
  { "foreign.shipping_account_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipping_class",
  "XTracker::Schema::Result::Public::ShippingClass",
  { id => "shipping_class_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NLViaRDLGvpuqBf167HDeA

use XTracker::Config::Local qw(
    config_var
    dc_address
);

=head2 get_from_address_data

Returns a hash of data detailing the elements of the 'From' address that is supplied
on airway bills and in the manifest for shipments that use this shipping account.
E.g. The address of the sender (Net-A-Porter, or Mr Porter, or Jimmy Choo etc...)

Including:
    Fields that vary based on DC:
        from_addr1
        from_addr2
        from_addr3
        from_country
        origin
        city
        postcode
        alpha-2
    Fields that vary based on Shipping Account:
        from_company

=cut
sub get_from_address_data {
    my ($self) = @_;

    # Grab most of the from address data from config
    my $dc_address = dc_address($self->channel);
    my $from_address_data = { map {
        'from_' . $_ => uc( $dc_address->{$_} // q{} )
    } qw/addr1 addr2 addr3 country city postcode alpha-2/};

    $from_address_data->{from_origin} = uc(config_var('DistributionCentre', 'origin'));

    # Except the 'company name', which is configured per shipping account
    $from_address_data->{from_company} =
        $self->from_company_name()
        # Use this as a last resort (legacy behaviour)
        or $self->channel()->business()->config_section();

    return $from_address_data;
}
1;
