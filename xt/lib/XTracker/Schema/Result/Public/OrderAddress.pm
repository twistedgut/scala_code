use utf8;
package XTracker::Schema::Result::Public::OrderAddress;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.order_address");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "order_address_id_seq",
  },
  "first_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "last_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "address_line_1",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "address_line_2",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "address_line_3",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "towncity",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "county",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "country",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "postcode",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "address_hash",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "urn",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
  "last_modified",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "title",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "address_change_log_change_froms",
  "XTracker::Schema::Result::Public::AddressChangeLog",
  { "foreign.change_from" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "address_change_log_change_toes",
  "XTracker::Schema::Result::Public::AddressChangeLog",
  { "foreign.change_to" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_address_log_changed_froms",
  "XTracker::Schema::Result::Public::OrderAddressLog",
  { "foreign.changed_from" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_address_log_changed_toes",
  "XTracker::Schema::Result::Public::OrderAddressLog",
  { "foreign.changed_to" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { "foreign.invoice_address_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_invoice_address_ids",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.invoice_address_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_shipment_address_ids",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.shipment_address_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_receivers",
  "XTracker::Schema::Result::Public::SampleReceiver",
  { "foreign.address_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_address_log_changed_froms",
  "XTracker::Schema::Result::Public::ShipmentAddressLog",
  { "foreign.changed_from" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_address_log_changed_toes",
  "XTracker::Schema::Result::Public::ShipmentAddressLog",
  { "foreign.changed_to" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.shipment_address_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:135mFrUvJT15aG4S5bu7lw

=head1 NAME

XTracker::Schema::Result::Public::OrderAddress

=cut

__PACKAGE__->belongs_to(
    'country_table' => 'Public::Country',
    { 'foreign.country' => 'self.country' },
);

use XTracker::Constants::FromDB qw( :sub_region );
use XTracker::Config::Local qw( config_var get_required_address_fields_for_preorder );
use XTracker::SchemaHelper qw(:records);
use XTracker::DBEncode qw(decode_db encode_db);
use XT::Data::Address;
use XTracker::Logfile qw( xt_logger );

__PACKAGE__->load_components('FilterColumn');
foreach (qw[first_name last_name
            address_line_1 address_line_2 address_line_3
            towncity county country postcode]) {
    __PACKAGE__->filter_column($_ => {
        filter_from_storage => sub { decode_db($_[1]) },
        filter_to_storage => sub {
            my $input = $_[1];

            if ( defined($input) ) {
                # We want to replace all non printable characters,
                # including unicode whitespace characters with ASCII
                # space and then strip leading and trailing
                # whitespace.
                $input =~ s/\P{Print}+/ /g; # replace non printable characters with space
                $input =~ s/\s{2,}/ /g;     # remove duplicate spaces in string
                $input =~ s/^\s+//;         # strip any leading whitespace
                $input =~ s/\s+$//;         # strip any trailing whitespace
                $input =~ s/℅/C\/O/g;       # Replace ℅  character with C/O
            }

            return encode_db($input)
        },
    });
}

=head1 METHODS

=cut

# This is to fake a link between this table and country (we should use
# country_id!)
sub country_ignore_case {
    my ( $self ) = @_;
    my $country_rs
        = $self->result_source->schema->resultset('Public::Country');
    my $country = $country_rs->search({country => { ilike => $self->country }})
                             ->slice(0,0)
                             ->single;
    return $country;
}

sub is_eu_member_states {
    my($self) = @_;

    if ($self->country_table->sub_region_id == $SUB_REGION__EU_MEMBER_STATES) {
        return 1;
    }

    return 0;
}

=head2 comma_seperated_str

    $str    = $order_address->comma_seperated_str

Returns a Comma Seperated string of the Address with only entries that are not empty so you shouldn't get consecutive commas (',,'),
includes country. This was used first for the 'XTracker::Order::Functions::Order::OrderView' module for use in Google Maps.

=cut

sub comma_seperated_str {
    my $self    = shift;

    my @fields  = (
            $self->address_line_1,
            $self->address_line_2,
            $self->address_line_3,
            $self->towncity,
            $self->county,
            $self->postcode,
            $self->country,
        );

    my $seperator   = "";
    my $str         = "";

    foreach my $field ( @fields ) {
        if ( $field ne "" ) {
            $str    .= $seperator.$field;
            $seperator  = ",";
        }
    }

    return $str;
}

sub as_string {
    my $self = shift;
    return join(
        ", ",
        join(" ", grep { $_ } $self->first_name, $self->last_name),
        join(
            ", ",
            grep { $_ ne "" }
            map { $self->$_ }
            qw/
                address_line_1
                address_line_2
                address_line_3
                towncity
                county
                postcode
                country
            /,
        ),
    );
}

=head2 as_carrier_string

Returns the address as a single string suitable for use with carrier
validation.

=cut

sub as_carrier_string {
    my $self = shift;

    return join( ", ",
        join(" ", grep { $_ } $self->first_name, $self->last_name),
        join(", ",
            grep { $_ ne "" }
            map { $self->$_ }
            qw/
                address_line_1
                address_line_2
                towncity
                county
                postcode
                country
            /,
        ),
    );
}

=head2 has_non_latin_1_characters() : Bool

Returns true if the shipment has characters outside of the Latin-1 range.

=cut

sub has_non_latin_1_characters {
    return !!($_[0]->as_carrier_string =~ /[^\x00-\xFF]/g);
}

=head2 in_vertex_area

Returns true iff the address is in a Vertex area, based on its country and county.

=over 4

=item
   For countries with only some counties attracting tax, there will be multiple rows in the vertex_area table listing the country and county combinations.  Only those listed are Vertex areas; any county not explictly listed is a non-Vertex area.

=item For countries with all counties attracting tax, only one row will exist in the vertex_area table, with a NULL in the county column. Every county is a Vertex area.

=back

So, to return true, the address must either match both country and
county, or the address must match on country only to a row with a NULL
county.

=cut

sub in_vertex_area {
    my $self = shift;

    my $country = $self->country;

    return 0 unless $country;

    my $resultset=$self->result_source
                       ->schema
                       ->resultset('Public::VertexArea');

    my $county  = $self->county;

    # technically, these could be finds, but searches here protect us from wonkiness in the DB

    if ( $county ) {
        # if we have a county, true if *either* the country and county combination exists
        # *or* the country exists in the DB with no county (meaning "county doesn't matter")

        return 1 if $resultset->search({
            -or => [
                { country => $country, county => $county },
                { country => $country, county => undef   },
            ],
        })->count;
    }
    else {
        # if we don't have a county, true iff the country exists with no county in the DB

        return 1 if $resultset->search( { country => $country, county => undef } )->count;
    }

    return 0;
}

=head2 as_data_obj

=cut

sub as_data_obj {
    my ($self) = @_;

    # We always have a schema
    my $input = { schema => $self->result_source->schema };

    # DB and DO Names match
    for my $field (qw/title first_name last_name county
                      postcode urn last_modified/){
        if(defined $self->$field){ $input->{$field} = $self->$field }
    }

    # Address lines don't match
    for my $field (qw/line_1 line_2 line_3/){
        my $method = 'address_' . $field;
        if(defined $self->$method){
            $input->{$field} = $self->$method
        }
    }

    if(defined $self->towncity){ $input->{town} = $self->towncity }

    # Country wrangling and country mangling
    if(defined $self->country_ignore_case
         && defined $self->country_ignore_case->code){
        $input->{country_code} = $self->country_ignore_case->code
    }

    return XT::Data::Address->new($input);
}

=head2 is_equivalent_to

=cut

sub is_equivalent_to {
    my ($self, $other_address) = @_;

    my $full_match = 0;
    my $matches = 0;

    # Fields which define an equivalent address
    my @checked_fields = qw/title
                            first_name
                            last_name
                            address_line_1
                            address_line_2
                            address_line_3
                            towncity
                            county
                            postcode
                            country/;

    # Check each input field against the checked field list
    for my $field (@checked_fields){
        if(!defined $self->$field && !defined $other_address->$field){
            $matches++;
        }
        elsif(defined $self->$field
                && defined $other_address->$field
                && $self->$field eq $other_address->$field){
            $matches++;
        }
        else{
            # no match
        }
    }

    # Full match if number of matched fields equals the number of keys in the
    # checked field hash
    $full_match = scalar @checked_fields == $matches ? 1 : 0;

    return $full_match;
}

=head2 full_name() : $full_name

Return the full name of the addressee.

=cut

sub full_name {
    my $self = shift;
    return join q{ }, $self->first_name, $self->last_name;
}

=head2 is_valid_for_pre_order

Returns TRUE if this address is valid for use with a Pre-Order, FALSE
otherwise.

An address is only classed as valid to be used for a Pre-Order, if all of the
fields specified in the configuration value (currently) 'field_required' of
'PreOrderAddress', are not empty. This is because the exporter throws an
expection if any of them are.

=cut

sub is_valid_for_pre_order {
    my $self = shift;

    my $result = 1;
    my $fields = get_required_address_fields_for_preorder();

    foreach my $field ( @$fields ) {

        if ( $self->can( $field ) ) {

            $result = 0
                unless defined $self->$field && $self->$field ne '';

        } else {

            my $id = $self->id;
            xt_logger->warn( "Address field '$field' defined in config, does not exist in the Public::OrderAddress class for Address ID $id" );

        }

    }

    return $result;

}

1;
