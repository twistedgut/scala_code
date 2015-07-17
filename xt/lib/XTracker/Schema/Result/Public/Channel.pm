use utf8;
package XTracker::Schema::Result::Public::Channel;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.channel");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "channel_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "business_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "distrib_centre_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "web_name",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "is_enabled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "timezone",
  {
    data_type     => "text",
    default_value => "Europe/London",
    is_nullable   => 1,
    original      => { data_type => "varchar" },
  },
  "company_registration_number",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "default_tax_code",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "colour_detail_override",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "idx",
  { data_type => "integer", is_nullable => 1 },
  "has_public_website",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("channel_name_key", ["name"]);
__PACKAGE__->has_many(
  "boxes",
  "XTracker::Schema::Result::Public::Box",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "bulk_reimbursements",
  "XTracker::Schema::Result::Public::BulkReimbursement",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "business",
  "XTracker::Schema::Result::Public::Business",
  { id => "business_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "carrier_box_weights",
  "XTracker::Schema::Result::Public::CarrierBoxWeight",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_brandings",
  "XTracker::Schema::Result::Public::ChannelBranding",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_from_channel_ids",
  "XTracker::Schema::Result::Public::ChannelTransfer",
  { "foreign.from_channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_to_channel_ids",
  "XTracker::Schema::Result::Public::ChannelTransfer",
  { "foreign.to_channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "config_groups",
  "XTracker::Schema::Result::SystemConfig::ConfigGroup",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "correspondence_subjects",
  "XTracker::Schema::Result::Public::CorrespondenceSubject",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_shipment_types",
  "XTracker::Schema::Result::Public::CountryShipmentType",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_shipping_charges",
  "XTracker::Schema::Result::Public::CountryShippingCharge",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_tax_codes",
  "XTracker::Schema::Result::Public::CountryTaxCode",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "credit_hold_thresholds",
  "XTracker::Schema::Result::Public::CreditHoldThreshold",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_credits",
  "XTracker::Schema::Result::Public::CustomerCredit",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customers",
  "XTracker::Schema::Result::Public::Customer",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "designer_attributes",
  "XTracker::Schema::Result::Designer::Attribute",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "designer_channels",
  "XTracker::Schema::Result::Public::DesignerChannel",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "distrib_centre",
  "XTracker::Schema::Result::Public::DistribCentre",
  { id => "distrib_centre_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "fraud_archived_rules",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_live_rules",
  "XTracker::Schema::Result::Fraud::LiveRule",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_staging_rules",
  "XTracker::Schema::Result::Fraud::StagingRule",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "hotlist_values",
  "XTracker::Schema::Result::Public::HotlistValue",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "inner_boxes",
  "XTracker::Schema::Result::Public::InnerBox",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_manifest__channels",
  "XTracker::Schema::Result::Public::LinkManifestChannel",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_designer_descriptions",
  "XTracker::Schema::Result::Public::LogDesignerDescription",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_locations",
  "XTracker::Schema::Result::Public::LogLocation",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_putaway_discrepancies",
  "XTracker::Schema::Result::Public::LogPutawayDiscrepancy",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_pws_reservation_corrections",
  "XTracker::Schema::Result::Public::LogPwsReservationCorrection",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_pws_stocks",
  "XTracker::Schema::Result::Public::LogPwsStock",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_rtv_stocks",
  "XTracker::Schema::Result::Public::LogRtvStock",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_rule_engine_switch_positions",
  "XTracker::Schema::Result::Fraud::LogRuleEngineSwitchPosition",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_sample_adjustments",
  "XTracker::Schema::Result::Public::LogSampleAdjustment",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_stocks",
  "XTracker::Schema::Result::Public::LogStock",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_website_states",
  "XTracker::Schema::Result::Designer::LogWebsiteState",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_customer_segments",
  "XTracker::Schema::Result::Public::MarketingCustomerSegment",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_promotions",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "operator_preferences",
  "XTracker::Schema::Result::Public::OperatorPreference",
  { "foreign.pref_channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "packaging_attributes",
  "XTracker::Schema::Result::Public::PackagingAttribute",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pages",
  "XTracker::Schema::Result::WebContent::Page",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "postcode_shipping_charges",
  "XTracker::Schema::Result::Public::PostcodeShippingCharge",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_attributes",
  "XTracker::Schema::Result::Product::Attribute",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_channels",
  "XTracker::Schema::Result::Public::ProductChannel",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_type_measurements",
  "XTracker::Schema::Result::Public::ProductTypeMeasurement",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_types",
  "XTracker::Schema::Result::Public::PromotionType",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pws_sort_orders",
  "XTracker::Schema::Result::Product::PWSSortOrder",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "quantities",
  "XTracker::Schema::Result::Public::Quantity",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "quarantine_processes",
  "XTracker::Schema::Result::Public::QuarantineProcess",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "recommended_products",
  "XTracker::Schema::Result::Public::RecommendedProduct",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_consistencies",
  "XTracker::Schema::Result::Public::ReservationConsistency",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "returns_charges",
  "XTracker::Schema::Result::Public::ReturnsCharge",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rma_requests",
  "XTracker::Schema::Result::Public::RmaRequest",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "routing_exports",
  "XTracker::Schema::Result::Public::RoutingExport",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_shipments",
  "XTracker::Schema::Result::Public::RTVShipment",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_classification_default_sizes",
  "XTracker::Schema::Result::Public::SampleClassificationDefaultSize",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_product_type_default_sizes",
  "XTracker::Schema::Result::Public::SampleProductTypeDefaultSize",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_size_scheme_default_sizes",
  "XTracker::Schema::Result::Public::SampleSizeSchemeDefaultSize",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_account__countries",
  "XTracker::Schema::Result::Public::ShippingAccountCountry",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_accounts",
  "XTracker::Schema::Result::Public::ShippingAccount",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_charges",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "state_shipping_charges",
  "XTracker::Schema::Result::Public::StateShippingCharge",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_consistencies",
  "XTracker::Schema::Result::Public::StockConsistency",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_summaries",
  "XTracker::Schema::Result::Product::StockSummary",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_transfers",
  "XTracker::Schema::Result::Public::StockTransfer",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "super_purchase_orders",
  "XTracker::Schema::Result::Public::SuperPurchaseOrder",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "transfers",
  "XTracker::Schema::Result::Upload::Transfer",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_products",
  "XTracker::Schema::Result::Voucher::Product",
  { "foreign.channel_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_purchase_orders",
  "XTracker::Schema::Result::Voucher::PurchaseOrder",
  { "foreign.channel_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cYxVQX8gBKbOwpAgMCKuSw

__PACKAGE__->has_many(
  "config_group",
  "XTracker::Schema::Result::SystemConfig::ConfigGroup",
  { "foreign.channel_id" => "self.id" },
);
__PACKAGE__->many_to_many(
    designers => 'designer_channels' => 'designer',
);

use XTracker::SchemaHelper qw(:records);
use Carp;

use XTracker::Constants qw(:prl_type);
use XTracker::Constants::FromDB qw{
    :business
    :distrib_centre
    :flow_status
    :reservation_status
    :shipment_item_status
    :variant_type
};
use XTracker::WebContent::StockManagement;
use XTracker::Database;

=head2 prl_client

Returns the PRL token appropriate for the implied PRL concept of client, for
this channel.

=cut

sub prl_client {
    my $self = shift;
    return $self->business->id == $BUSINESS__JC ?
        $PRL_TYPE__CLIENT__JC  :
        $PRL_TYPE__CLIENT__NAP;
}

sub lc_web_name {
    my($self) = @_;

    if (not defined $self) {
        die __PACKAGE__ .":\$self in lc_web_name is not defined";
    }

    return lc($self->web_name);
}


sub web_queue_name_part {
    my ($self) = @_;

    my $name = $self->web_name;
    # Bite me
    $name =~ s/OUTNET/OUT/;

    return join'-', map { lc } split /\W+/, $name;
}

# Use this when sending a channel name in an AMQ message
sub website_name {
    my $self = shift;
    my $channel_name = $self->web_name;
    $channel_name =~ s/OUTNET/OUT/;
    $channel_name =~ s/-/_/g;
    return $channel_name;
}

=head2 web_brand_name

    my $brand = $channel->web_brand_name();

    Returns string  nap/out/mrp/jc
=cut
sub web_brand_name {
    my $self = shift;

    my $name = lc( $self->business->config_section );
    $name =~ s/outnet/out/;

    return $name;
}


# this just returns the current value
# of the Carrier Automation State for
# the Sales Channel.
sub carrier_automation_state {
    my $self    = shift;

    my $retval  = '';

    my $group   = $self->config_group->search( { name => 'Carrier_Automation_State' } )->first;
    if ( defined $group ) {
        my $setting = $group->config_group_settings_rs->search( { setting => 'state' } )->first;
        if ( defined $setting ) {
            $retval = $setting->value;
        }
    }

    return $retval;
}

=head2 update_carrier_automation_state

 update_carrier_automation_state( $state );

This updates the Carrier Automation State for the channel

=cut

sub update_carrier_automation_state {
    my ( $self, $state )  = @_;

    my $schema = $self->result_source->schema;

    my $args = {
                    config_group_name  => 'Carrier_Automation_State',
                    setting            => 'state',
                    channel_id         => $self->id,
                    value              => $state,
    };

    return $schema->resultset("SystemConfig::ConfigGroupSetting")->update_systemconfig( $args );
}

# this returns TRUE (1) or FALSE (0) depending
# on the 'Carrier_Automation_State' setting in
# the System Config tables. This is on when
# the setting is set to 'On'.
sub carrier_automation_is_on {
    my $self    = shift;

    # default to being FALSE
    my $retval  = 0;

    # get the system config group and settings for
    my $group   = $self->config_group->search( { name => 'Carrier_Automation_State' } )->first;
    if ( defined $group ) {
        my $setting = $group->config_group_settings_rs->search( { setting => 'state' } )->first;
        if ( defined $setting ) {
            if ( $setting->value =~ /^(On||Import_Off_Only)$/i ) {
                $retval = 1;
            }
        }
    }

    return $retval;
}

# this returns TRUE (1) or FALSE (0) depending
# on the 'Carrier_Automation_State' setting in
# the System Config tables. This is on when
# the setting is set to 'Off'.
sub carrier_automation_is_off {
    my $self    = shift;

    # default to being TRUE
    my $retval  = 1;

    # get the system config group and settings for
    my $group   = $self->config_group->search( { name => 'Carrier_Automation_State' } )->first;
    if ( defined $group ) {
        my $setting = $group->config_group_settings_rs->search( { setting => 'state' } )->first;
        if ( defined $setting ) {
            if ( $setting->value !~ /^Off$/i ) {
                $retval = 0;
            }
        }
    }

    return $retval;
}

# this returns TRUE (1) or FALSE (0) depending
# ON the 'Carrier_Automation_State' setting in
# the System Config tables. This is on when
# the setting is set to 'Off' or 'Import Off Only'.
sub carrier_automation_import_off {
    my $self    = shift;

    # default to being TRUE
    my $retval  = 1;

    # get the system config group and settings for
    my $group   = $self->config_group->search( { name => 'Carrier_Automation_State' } )->first;
    if ( defined $group ) {
        my $setting = $group->config_group_settings_rs->search( { setting => 'state' } )->first;
        if ( defined $setting ) {
            if ( $setting->value !~ /^(Off||Import_Off_Only)$/i ) {
                $retval = 0;
            }
        }
    }

    return $retval;
}

=head2 is_on_mrp

Returns a true value if the channel is on Mr Porter.

=cut

sub is_on_mrp {
    return $_[0]->business_id == $BUSINESS__MRP;
}

=head2 is_on_nap

Returns a true value if the channel is on Net-A-Porter.

=cut

sub is_on_nap {
    return $_[0]->business_id == $BUSINESS__NAP;
}

=head2 is_on_outnet

Returns a true value if the channel is on the Outnet.

=cut

sub is_on_outnet {
    return $_[0]->business_id == $BUSINESS__OUTNET;
}

=head2 is_on_jc

Returns a true value if the channel is on the Outnet.

=cut

sub is_on_jc {
    return $_[0]->business_id == $BUSINESS__JC;
}

=head2 has_welcome_pack

    $boolean = $self->has_welcome_pack( 'fr' # language code );

Returns a true value if the 'Welcome Pack' promotion is enabled on this
channel and there are 'Welcome Pack%' promotion_types for the supplied
Language Code.

=cut

sub has_welcome_pack {
    my ( $self, $language_code )    = @_;

    croak "No Language Code passed to '" . __PACKAGE__ . "->has_welcome_pack'"
                    if ( !$language_code );

    # check if the System Config has an option
    # for a Welcome Pack for the Language Code
    # or has a 'DEFAULT' Welcome Pack
    my $conf_setting = $self->_get_active_config_group_setting(
                            'Welcome_Pack',
                            $language_code
                        ) // $self->_get_active_config_group_setting(
                            'Welcome_Pack',
                            'DEFAULT'
                        );
    return 0    if ( lc( $conf_setting // 'off' ) eq 'off' );

    # check to see if there are actually any
    # Welcome Packs defined for the Channel
    my $count   = $self->search_related( 'promotion_types', {
        'me.name' => { ILIKE => 'Welcome Pack %' },
    } )->count;
    return 0    if ( !$count );

    # has a Welcome Pack!
    return 1;
}

=head2 is_config_group_active( $config_name )

Returns the value of active for config group C<$config_name> on this channel.
Dies if it can't find it.

=cut

sub is_config_group_active {
    my ( $self, $name ) = @_;
    my $row = $self->config_groups->search({name=>$name})->slice(0,0)->single;
    croak "Config group $name not found for channel " . $self->name
        unless $row;
    return $row->active;
}

=head2 is_on_dc1

This is now deprecated, please use is_on_dc instead.

Returns true if the channel is on DC1.

=cut

sub is_on_dc1 {
    Carp::carp('This is now deprecated, please use is_on_dc instead.');
    return $_[0]->distrib_centre_id == $DISTRIB_CENTRE__DC1
}

=head2 is_on_dc2

This is now deprecated, please use is_on_dc instead.

Returns true if the channel is on DC2.

=cut

sub is_on_dc2 {
    Carp::carp('This is now deprecated, please use is_on_dc instead.');
    return $_[0]->distrib_centre_id == $DISTRIB_CENTRE__DC2
}

=head2 is_on_dc3

This is now deprecated, please use is_on_dc instead.

Returns true if the channel is on DC3.

=cut

sub is_on_dc3 {
    Carp::carp('This is now deprecated, please use is_on_dc instead.');
    return $_[0]->distrib_centre_id == $DISTRIB_CENTRE__DC3
}

=head2 is_on_dc

Returns true if the channel is on the specified DC.

Accepts either a DC name (DC1, DC2, etc) or a database
id from the distrib_centre table, usually passed in using
a constant from XTracker::Constants::FromDB (for example
$DISTRIB_CENTRE__DC1).

    print $channel->is_on_dc( 'DC1' )                ? 'On DC1' : 'Not On DC1';
    print $channel->is_on_dc( $DISTRIB_CENTRE__DC1 ) ? 'On DC1' : 'Not On DC1';

=cut

sub is_on_dc {
    my ( $self, $dc ) = @_;

    return 0 unless $dc;

    if ( $dc =~ /^\d+$/ ) {
    # We've been passed a number, so we'll assume it's a constant.

        return $self->distrib_centre_id == $dc;

    } elsif ( $dc =~ /^DC\d+$/i ) {
    # We've been passed a DC name.

        return uc( $self->distrib_centre->name ) eq uc( $dc );

    } else {

        return 0;

    }

}

sub find_promotion_type_for_country {
    my($self,$cond) = @_;
    my $schema = $self->result_source->schema;
    my $countries = $schema->resultset('Public::Country')->search( $cond );
    return if ( (!$countries) || ($countries->count == 0) );

    # find all the ids of the countries that match
    my @ids = $countries->get_column('id')->all;
    # do we need an order by?
    my $promos = $self->search_related('promotion_types', {
        'country_promotion_type_welcome_packs.country_id' => {
            in => \@ids,
        },
    },{
        join => qw/country_promotion_type_welcome_packs/,
    });

    return if ( (!$promos) || ($promos->count == 0) );

    return $promos->first;
#    my $pack = $country_rs->search({country => $country_str})
#    ->single
#    ->country_promotion_type_welcome_pack;

}

=head2 find_welcome_pack_for_language

    $promotion_type_rec = $self->find_welcome_pack_for_language( 'fr' # language code );

Will find a Welcome Pack Promotion Type for a given Language.

=cut

sub find_welcome_pack_for_language {
    my ( $self, $language_code )    = @_;

    return $self->find_promotion_types_for_language( $language_code )
                    ->search( { 'me.name' => { ILIKE => 'Welcome Pack %' } } )
                        ->first;
}

=head2 find_promotion_types_for_language

    $promotion_type_rs = $self->find_promotion_types_for_language( 'fr' # language code );

Returns a ResultSet of 'promotion_type' records joined to a passed in Language Code.

=cut

sub find_promotion_types_for_language {
    my ( $self, $language_code )    = @_;

    croak "No Language Code passed to '" . __PACKAGE__ . "->find_promotion_type_for_language'"
                    if ( !$language_code );

    return $self->search_related( 'promotion_types',
        {
            # explicitly joining to the 'language__promotion_type' table because
            # it is a 'LEFT JOIN' and we only want records that DO actually join
            'me.id'         => { '=' => \'language__promotion_types.promotion_type_id' },
            'language.code' => lc( $language_code ),
        },
        {
            join => { language__promotion_types => 'language' }
        }
    );
}


=head2 short_name

A wrapper method to use instead of using an incorrectly named db field

=cut

sub short_name {
    my($self) = @_;
    return $self->web_name;
}

=head2 config_name

Returns the business' C<config_section> which is often used when selecting
configuration values.

e.g., C<NAP>, C<OUTNET> etc.

=cut

sub config_name {
    my ($self) = @_;
    return $self->business->config_section;
}

=head2 is_fulfilment_only

Return true if its a fulfilment only channel.

=cut

sub is_fulfilment_only {
    return $_[0]->business->fulfilment_only;
}

=head2 is_above_no_delivery_signature_threshold

    $boolean    = $channel->is_above_no_delivery_signature_threshold( $amount, $currency );

This will return TRUE or FALSE if the supplied Amount for the Currency is past the Threshold limit for the Sales Channel
in regards to the 'No_Delivery_Signature_Credit_Hold_Threshold' System Config Group.

Currency can either be a Currency Code like 'USD' or 'GBP' or it can be a 'Public::Currency' object;

=cut

sub is_above_no_delivery_signature_threshold {
    my ( $self, $amount, $currency )    = @_;

    if ( !defined $amount ) {
        croak "'is_above_no_delivery_signature_threshold' has been passed an undefined Amount";
    }
    if ( !defined $currency ) {
        croak "'is_above_no_delivery_signature_threshold' has been passed an undefined Currency";
    }

    my $retval  = 0;

    my $currency_code   = $currency;
    # if passed a 'Public::Currency' object then get the Currency Code
    if ( ref( $currency ) ) {
        $currency_code  = $currency->currency;
    }

    # get the threshold
    my $group   = $self->config_groups->search( { name => 'No_Delivery_Signature_Credit_Hold_Threshold', active => 1 } )->first;
    if ( defined $group ) {
        my $setting = $group->config_group_settings->search( { setting => $currency_code, active => 1 } )->first;
        if ( defined $setting ) {
            if ( $amount >= $setting->value ) {
                # equal or above the Threshold counts as above
                $retval = 1;
            }
        }
    }

    return $retval;
}

=head2 can_auto_upload_reservations

    $boolean    = $channel->can_auto_upload_reservations;

This will return either TRUE or FALSE to indicate whether the Sales Channel can Automatically Upload Reservations to the Web-Site when items are put into stock. Uses the 'Automatic_Reservation_Upload_Upon_Stock_Updates' section in the 'system_config' tables.

=cut

sub can_auto_upload_reservations {
    my $self    = shift;

    my $value   = lc( $self->_get_active_config_group_setting( 'Automatic_Reservation_Upload_Upon_Stock_Updates', 'state' ) || 'Off' );

    return ( $value eq 'on' ? 1 : 0 );
}

=head2 is_pre_order_active

    $boolean    = $channel->is_pre_order_active;

This will return either TRUE or FALSE to indicate whether this channel allows pre orders

=cut

sub is_pre_order_active {
    my $self = shift(@_);
    return $self->_get_active_config_group_setting('PreOrder', 'is_active');
}

=head2 branding

    $scalar     = $channel->branding( $BRANDING__??? );
    $hash_ref   = $channel->branding( $BRANDING__???, $BRANDING__??? ... $BRANDING__??? );
    @array      = $channel->branding( $BRANDING__???, $BRANDING__??? ... $BRANDING__??? );
    $hash_ref   = $channel->branding;       # return all Branding for the Sales Channel

This gets the 'channel_branding' for the Sales Channel. It's used to return the appropriate values
to put in Customer Documentation or Customer Emails for the Sales Channel based on the 'branding'
Id's passed in. Use the ':branding' constants to help you to pass in the Id's to this method to
return the value for that Branding.

It can be called in multiple ways:
    * Pass in a single :branding constant and just the value will be returned.
    * Called in Scalar context with 2 or more :branding constants will return
      a Hash Ref containing the values with the branding id as the key.
    * Called in List context with :branding Id's will return an array of
      values in the same order as the parameters passed in.
    * Called with NO paramters will return all of the 'channel_branding' values
      for the Sales Channel in a Hash Ref with the 'branding' id as the key.

=cut

sub branding {
    my ( $self, @params )   = @_;

    my $search_args = {};
    if ( @params ) {
        $search_args    = {
                branding_id => { 'IN' => \@params },
            };
    }

    # get the brandings
    my @brandings   = $self->channel_brandings->search( $search_args )->all;

    if ( @brandings == 1 && @params == 1 ) {
        # if there is only one result and
        # only one parameter passed in
        return $brandings[0]->value;
    }
    elsif ( @brandings > 1 ) {
        # build up a hash of the
        # brandings and their values
        my %brandings   = map { $_->branding_id => $_->value } @brandings;

        # if not called in list context or there were no
        # params passed in then return with a Hash Ref
        return \%brandings          if ( !wantarray || !@params );

        # if called in list context then return
        # an array of values in the same order the
        # the parameters were passed in

        my @values;
        foreach my $brand_id ( @params ) {
            push @values, $brandings{ $brand_id };
        }

        return @values;
    }

    return;
}

=head2 can_communicate_to_customer_by

    $boolean = $self->can_communicate_to_customer_by('SMS');

Pass in a Communication Method for Customers and this will return whether the Sales Channel
can send communications using that method for the system as a whole.

Current Methods Supported:
    * SMS
    * Email

If the Method can't be found then the DEFAULT is FALSE.

Checks the 'Customer_Communication' group in the 'system_config' tables.

=cut

sub can_communicate_to_customer_by {
    my ( $self, $method )   = @_;

    my $setting = $self->_get_active_config_group_setting( 'Customer_Communication', $method ) || 'Off';

    return ( lc( $setting ) eq 'on' ? 1 : 0 );
}

=head2 can_premier_send_alert_by

    $boolean = $self->can_premier_send_alert_by('SMS');

Pass in a Communication Method for Customers and this will return whether the Sales Channel
can send an Alert for Premier Deliveries using it, this also uses the method '$self->can_communicate_to_customer_by'
which checks the global setting for the System as a whole, which will override the Premier Delivery setting.

Current Methods Supported:
    * SMS
    * Email

If the Method can't be found then the DEFAULT is FALSE.

Checks the 'Premier_Delivery' group in the 'system_config' tables.

=cut

sub can_premier_send_alert_by {
    my ( $self, $method )   = @_;

    # if can't do it globally then can't do it at all
    if ( !$self->can_communicate_to_customer_by( $method ) ) {
        return 0;
    }

    # append ' Alert' to the Method
    my $setting = $self->_get_active_config_group_setting( 'Premier_Delivery', $method . ' Alert' ) || 'Off';

    return ( lc( $setting ) eq 'on' ? 1 : 0 );
}

=head2 premier_hold_alert_threshold

    my $integer = $self->premier_hold_alert_threshold;

This returns the number of failed attempts to Deliver a Shipment before the 'Hold Order' Alert is sent.

=cut

sub premier_hold_alert_threshold {
    my ( $self )    = @_;

    return $self->_get_active_config_group_setting( 'Premier_Delivery', 'send_hold_alert_threshold' );
}

=head2 can_access_product_service

    call_product_service() if $channel->can_access_product_service();

Checks whether Product Service is available for channel

=cut

sub can_access_product_service {
    my $self = shift;

    my $setting = $self->_get_active_config_group_setting( 'Product_Service', 'access_product_service' ) || 'Off';

    return ( lc( $setting ) eq 'on' ? 1 : 0 );
}

=head2 can_access_product_service_for_default_language

    call_product_service() if $channel->can_access_product_service_for_default_language();

Checks whether Product Service should be used for the default language

=cut

sub can_access_product_service_for_default_language {
    my $self = shift;

    my $setting = $self->_get_active_config_group_setting( 'Product_Service',
        'access_product_service_for_default_language' ) || 'Off';

    return ( lc( $setting ) eq 'on' ? 1 : 0 );
}


=head2 can_access_product_service_for_email

    call_product_service() if $channel->can_access_product_service_for_email();

Checks whether access to Product Service should be attempted when building data
for emails. Returns 1 if true or undef.

=cut

sub can_access_product_service_for_email {
    my $self = shift;

    my $setting = $self->_get_active_config_group_setting( 'Product_Service', 'access_product_service_for_email' ) || 'Off';

    return ( lc( $setting ) eq 'on' ? 1 : 0 );
}

=head2 get_correspondence_subject

    $correspondence_subject_rec = $channel->get_correspondence_subject( 'Subject Name' );

This will look in the 'correspondence_subject' table where the field 'subject' matches the passed
in 'Subject Name' and returns the DBIC record if found.

=cut

sub get_correspondence_subject {
    my ( $self, $subject )  = @_;

    return $self->correspondence_subjects->find( { subject => $subject } );
}

=head2 get_reservation_upload_footer_pdf

    my $text = $self->get_reservation_upload_footer

This returns footer text to be used in the pdf for Reservation->Upload pdf functionality

=cut

sub get_reservation_upload_pdf_footer {
    my ($self ) = @_;

    return $self->_get_active_config_group_setting( 'Reservation', 'upload_pdf_footer' );

}

=head2 get_active_config_group_setting

    Wrapper to return whether or not XT can send shipment updates to Mercury.

=cut

sub get_can_send_shipment_updates {
    my ($self, $group_name, $setting) = @_;
    my $can_send = $self->_get_active_config_group_setting('SendToMercury', 'can_send_shipment_updates');
    return lc($can_send) eq 'on' ? 1 : 0;
}

# $setting = _get_active_config_group_setting( $group_name, [ $setting ] );
# this is a helper method to return an active group's setting or all settings
# if no 'setting' has been passed in

sub _get_active_config_group_setting {
    my ( $self, $group_name, $setting )  = @_;

    my $retval;

    my $group   = $self->config_groups->search( { name => $group_name, active => 1 } )->first;
    if ( defined $group ) {
        my @settings    = $group->config_group_settings
                                    ->search(
                                            {
                                                active  => 1,
                                                $setting ? ( setting => $setting ) : (),
                                            },
                                            { order_by => 'id' } )->all;
        if ( @settings ) {
            $retval = ( $setting ? $settings[0]->value : \@settings );
        }
    }

    return $retval;
}

# $array_ref = _get_config_group_setting_values( $group_name, $setting );
# helper to return an Array Ref of Values for a Setting for a Config Group
sub _get_config_group_setting_values {
    my ( $self, $group_name, $setting ) = @_;

    my $schema = $self->result_source->schema;
    my $values = $schema->resultset('SystemConfig::ConfigGroupSetting')
                            ->config_var(
                                $group_name,
                                $setting,
                                $self->id,
                            );

    return      if ( !defined $values );
    return ( ref( $values ) eq 'ARRAY' ? $values : [ $values ] );
}

=head2 pws_dbh

Get the website database handle for this channel. Type defaults to 'readonly'
if undefined.

=cut

sub pws_dbh {
    my ( $self, $type ) = @_;
    $type //= 'readonly';
    croak qq{argument must be 'readonly' or 'transaction', not '$type'}
        unless $type =~ m{^(?:readonly|transaction)$};

    return XTracker::Database::get_database_handle({
        name => 'Web_Live_' . $self->business->config_section,
        type => $type,
    });
}

=head2 generate_reservation_discrepancy_rows_to_insert( [$stock_manager] ) : \@discrepancies, \@errors

Queries the pws for this channel and returns a list of two arrayrefs. The first
of these contains the rows that are to be inserted into the reservation_consistency
table, while the second contains any errors that we want to flag but we don't
want to rollback on.

This method will create a stock manager if we don't already have one.

=cut

sub generate_reservation_discrepancy_rows_to_insert {
    my ( $self, $stock_manager ) = @_;

    $stock_manager ||= $self->stock_manager;

    # Get reservations
    my $xt_reservation = $self->reservations_by_sku;

    my %old_discrepancy;
    for my $discrepancy (
        $self->reservation_consistencies->all
    ) {
        $old_discrepancy{$discrepancy->variant_id} = {
            $discrepancy->customer_number => {
                diff => $discrepancy->web_quantity - $discrepancy->xt_quantity,
                reported => $discrepancy->reported,
            },
            %{$old_discrepancy{$discrepancy->variant_id}||{}},
        },
    }

    my (@new_discrepancies,@errors);
    my $pws_reservations = $stock_manager->get_outstanding_reservations_by_sku;
    while ( my ( $sku, $c_quantity ) = each %$pws_reservations ) {
        while ( my ( $pws_customer_id, $pws_quantity ) = each %$c_quantity ) {
            # If there are any Reservations for Pre-Orders then skip them
            next    if ( $xt_reservation->{$sku}{$pws_customer_id}{is_for_preorder} );

            # Set xt's quantity to 0 if there's no value for it
            my $xt_quantity = $xt_reservation->{$sku}{$pws_customer_id}{quantity} || 0;

            # Next if we don't have a discrepancy
            next if $xt_quantity == $pws_quantity;

            # default num times discrep reported to 1
            my $reported = 1;

            my $variant_id
                = $xt_reservation->{ $sku }{$pws_customer_id}{variant_id};

            # If we don't have a variant id check if it exists in the db
            unless ( $variant_id ) {
                my $schema = $self->result_source->schema;
                my @args = ($sku, q{}, 'dont_die_when_cant_find', $VARIANT_TYPE__STOCK);

                my $variant
                    = $schema->resultset('Public::Variant')->find_by_sku(@args);

                # Flag if sku doesn't exist at all in backend db
                unless ( $variant ) {
                    # it's a voucher... we don't care about discrepancies
                    next if $schema->resultset('Voucher::Variant')->find_by_sku(@args);

                    # Can't find the sku, flag an error
                    push @errors, {
                        sku             => $sku,
                        customer_number => $pws_customer_id,
                        xt_quantity     => 'Unknown',
                        pws_quantity    => $pws_quantity,
                        error           => "Could not find sku in XTracker's database\n",
                    };
                    next;
                }
                $variant_id = $variant->id;
                $xt_quantity = 0;
            }

            # If discrepancy has been reported before increase it
            if ( $old_discrepancy{$variant_id}{$pws_customer_id}
                && $old_discrepancy{$variant_id}{$pws_customer_id}{diff}
                    == ( $pws_quantity - $xt_quantity )
            ) {
                $reported = $old_discrepancy{$variant_id}{$pws_customer_id}{reported} + 1;
            }
            push @new_discrepancies, {
                variant_id      => $variant_id,
                customer_number => $pws_customer_id,
                web_quantity    => $pws_quantity,
                xt_quantity     => $xt_quantity,
                reported        => $reported,
            };
        }
    }
    return ( \@new_discrepancies, \@errors );
}

=head2 refresh_reservation_consistency( @row_updates )

Update the reservation consistency table with the given rows.

=cut

sub refresh_reservation_consistency {
    my ( $self, @rows ) = @_;

    return unless @rows;

    $self->result_source->storage->txn_do(sub{
        $_->delete && $_->populate(\@rows)
            for $self->reservation_consistencies_rs;
    });
    return;
}

=head2 reservations_by_sku : { $sku => { $pws_customer_id => { variant_id => $variant_id, quantity => $quantity } } }

Return a hashref of reservations for this channel.

=cut

sub reservations_by_sku {
    my ( $self ) = @_;
    my %h;
    # Note that _uploaded_reservations guarantees uniqueness across
    # sku/pws_customer_number - if this weren't the case this loop wouldn't
    # work
    for my $reservation ( $self->_uploaded_reservations->all ) {
        $h{$reservation->variant->sku} = {
            $reservation->customer->is_customer_number => {
                variant_id => $reservation->variant_id,
                quantity   => $reservation->get_column('reservation_count'),
                # find out if any of the Reservations for
                # this Customer & SKU are for Pre-Orders
                is_for_preorder => $self->reservations->search(
                                                        {
                                                            'me.customer_id'    => $reservation->customer_id,
                                                            'me.variant_id'     => $reservation->variant_id,
                                                            'me.status_id'      => $RESERVATION_STATUS__UPLOADED,
                                                            'pre_order_items.id'=> { 'IS NOT' => undef },
                                                        },
                                                        {
                                                            join => 'pre_order_items',
                                                        } )->count,
            },
            %{$h{$reservation->variant->sku}||{}},
        };
    }
    return \%h;
}

sub _uploaded_reservations {
    my ( $self ) = @_;
    my @cols = (qw{
        me.variant_id
        variant.product_id
        variant.size_id
        customer.is_customer_number
        me.customer_id
    });
    return $self->search_related('reservations',
        { 'me.status_id' => $RESERVATION_STATUS__UPLOADED, },
        {
            columns   => \@cols,
            '+select' => [{ count => q{*} }],
            '+as'     => ['reservation_count'],
            join      => [qw{variant customer}],
            group_by  => \@cols,
        }
    );
}

=head2 generate_stock_discrepancy_rows_to_insert( $pws_stock, \%pids_to_ignore ) : \@rows, \@errors

This method returns a list of two arrayrefs. The first of these
contains the rows that are to be inserted into the stock_consistency
table, while the second contains any errors that we want to flag but
we don't want to rollback on.

C<$pws_stock> comes from L</stock_manager>'s
L<XTracker::WebContent::StockManagement::OurChannels/get_all_stock_levels>.

C<\%pids_to_ignore> is a hashref with PIDs as keys, and true values
(e.g. C<< { 1234 => 1, 354678 => 1 } >>); discrepancies for variants
of those PIDs will be ignored.

=cut

sub generate_stock_discrepancy_rows_to_insert {
    my ( $self, $pws_stock, $pids_to_ignore ) = @_;
    $pids_to_ignore //= {};

    # Get saleable inventory for all stock
    my %xt_stock = %{$self->saleable_stock_by_sku};

    # Create hash with existing discrepancies for this channel
    my %old_discrepancy = map {;
        $_->variant_id => {
            diff => $_->web_quantity - $_->xt_quantity,
            reported => $_->reported,
        },
    } $self->stock_consistencies->all;

    my (@new_discrepancies, @errors);
    while ( my ( $sku, $pws_quantity ) = each %$pws_stock ) {
        my ($variant_id,$xt_quantity);
        unless ( $xt_stock{ $sku } ) {
            my $schema = $self->result_source->schema;
            my @args = ($sku, q{}, 'dont_die_when_cant_find', $VARIANT_TYPE__STOCK);

            my $variant
                = $schema->resultset('Public::Variant')->find_by_sku(@args);

            unless ( $variant ) {
                # it's a voucher... we don't care about discrepancies
                next if $schema->resultset('Voucher::Variant')->find_by_sku(@args);

                # Flag missing sku in backend
                push @errors, {
                    sku          => $sku,
                    xt_quantity  => 'Unknown',
                    pws_quantity => $pws_quantity,
                    error        => "Could not find in XTracker's database\n",
                };
                next;
            }

            next if $pids_to_ignore->{$variant->product_id};

            $variant_id = $variant->id;
            $xt_quantity = 0;
        }

        $xt_quantity //= $xt_stock{$sku}{quantity};

        # We don't have a stock discrepancy
        next if $pws_quantity == $xt_quantity;

        $variant_id //= $xt_stock{$sku}{variant_id};

        # default num times discrep reported to 1
        my $reported = 1;

        # check is same discrep as before
        if ( $old_discrepancy{$variant_id}
          && $old_discrepancy{$variant_id}{diff} == ( $pws_quantity - $xt_quantity )
        ) {
            $reported = $old_discrepancy{$variant_id}{reported} + 1;
        }
        push @new_discrepancies, {
            variant_id   => $variant_id,
            web_quantity => $pws_quantity,
            xt_quantity  => $xt_quantity,
            reported     => $reported,
        };
    }
    return \@new_discrepancies, \@errors;
}

=head2 refresh_stock_consistency( @row_updates )

Update the stock consistency table with the given rows.

=cut

sub refresh_stock_consistency {
    my ( $self, @rows ) = @_;

    return unless @rows;

    # Refresh stock consistency table
    $self->result_source->storage->txn_do(sub{
        $_->delete && $_->populate(\@rows) for $self->stock_consistencies_rs;
    });
    return;
}

=head2 saleable_stock_by_sku : { sku => { quantity => $quantity, variant_id => $variant_id } }

A wrapper around L<saleable_inventory_for_all_stock>.

=cut

sub saleable_stock_by_sku {
    my ( $self ) = @_;
    return { map {;
        $_->{sku} => {
            quantity => $_->{quantity},
            variant_id => $_->{variant_id},
        },
    } @{$self->saleable_inventory_for_all_stock} };
}

=head2 saleable_inventory_for_all_stock : [ { variant_id => Int, sku => Str, quantity => Int } ]

Return an arrayref with saleable inventory information for all skus with non-zero
stock on this channel.

=cut

sub saleable_inventory_for_all_stock {
    my ( $self ) = @_;
    my $stock_levels = $self->result_source->storage->dbh_do(
        sub {
            my ( $storage, $dbh, $channel_id ) = @_;
            $dbh->selectall_arrayref(
                $self->_saleable_inventory_for_all_stock_qry,
                { Slice => {}, },
                ( $channel_id ) x 4, # channel_id for query placeholders
            );
        },
        $self->id,
    );
    return $stock_levels;
}

sub _saleable_inventory_for_all_stock_qry {
    return qq{
    SELECT      variant_id, sku, COALESCE( SUM(quantity), 0 ) AS quantity FROM (
        SELECT v.id AS variant_id,
                COALESCE( SUM( q.quantity ), 0 ) AS quantity,
                v.product_id || '-' || sku_padding(v.size_id) AS sku
        FROM variant v
        LEFT JOIN quantity q ON ( q.variant_id = v.id AND q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS AND q.channel_id = ?)
        WHERE v.type_id = $VARIANT_TYPE__STOCK
        GROUP BY v.id, v.product_id, v.size_id
    UNION ALL
        SELECT variant_id,
                -COUNT(*) AS quantity,
                v.product_id || '-' || sku_padding(v.size_id) AS sku
        FROM shipment_item si,
                variant v,
                link_orders__shipment los,
                orders o
        WHERE si.variant_id = v.id
        AND v.type_id = $VARIANT_TYPE__STOCK
        AND si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED )
        AND si.shipment_id = los.shipment_id
        AND los.orders_id = o.id
        AND o.channel_id = ?
        GROUP BY variant_id, product_id, size_id
    UNION ALL
        SELECT si.variant_id,
                -COUNT(*) AS quantity,
                v.product_id || '-' || sku_padding(v.size_id) AS sku
        FROM shipment_item si,
                variant v,
                link_stock_transfer__shipment lsts,
                stock_transfer st
        WHERE si.variant_id = v.id
        AND v.type_id = $VARIANT_TYPE__STOCK
        AND si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED )
        AND si.shipment_id = lsts.shipment_id
        AND lsts.stock_transfer_id = st.id
        AND st.channel_id = ?
        GROUP BY si.variant_id, product_id, size_id
    UNION ALL
        SELECT r.variant_id,
            -count(r.*) as quantity,
            v.product_id || '-' ||sku_padding(v.size_id) AS sku
        FROM reservation r, variant v
        WHERE r.variant_id = v.id
            AND r.status_id = $RESERVATION_STATUS__UPLOADED
            AND r.channel_id = ?
        GROUP BY r.variant_id, product_id, size_id
    ) AS saleable
    GROUP BY variant_id, sku
    HAVING COALESCE( SUM(quantity), 0 ) <> 0
    };
}

=head2 stock_manager

Get the stock manager for this channel's PWS.

=cut

sub stock_manager {
    my ( $self ) = @_;
    return XTracker::WebContent::StockManagement->new_stock_manager({
        schema => $self->result_source->schema,
        channel_id => $self->id,
    });
}

=head2 has_nominated_day_shipping_charges

Checks if we have any shipping charges that support nominated days for this
channel.

=cut

sub has_nominated_day_shipping_charges {
    return !!$_[0]->count_related('shipping_charges', {
        latest_nominated_dispatch_daytime => { q{!=} => undef }
    });
}

=head2 has_customer_facing_premier_shipping_charges

Returns true if the channel has any enabled shipping charges that support
premier deliveries and is customer facing (excludes Staff Shipping and
Courier Special Delivery).

=cut

sub has_customer_facing_premier_shipping_charges {
    return !!$_[0]->count_related('shipping_charges', {
        premier_routing_id => { q{!=} => undef },
        is_enabled         => 1,
        is_customer_facing => 1,
    });
}

=head2 get_fraud_rules_engine_switch_state

    $string = $self->get_fraud_rules_engine_switch_state;

Will Return either 'On', 'Off' or 'Parallel' depending on the current state of the
Fraud Rules Engine Switch.

=cut

sub get_fraud_rules_engine_switch_state {
    my $self    = shift;
    return lc( $self->_get_active_config_group_setting( 'Fraud Rules', 'Engine' ) || '' );
}

=head2 is_fraud_rules_engine_on

    $boolean = $self->is_fraud_rules_engine_on;

Returns TRUE or FALSE based on the state of the Fraud Rules Engine Switch in the System Config.

=cut

sub is_fraud_rules_engine_on {
    my $self    = shift;
    return ( $self->get_fraud_rules_engine_switch_state eq 'on' ? 1 : 0 );
}

=head2 is_fraud_rules_engine_off

    $boolean = $self->is_fraud_rules_engine_off;

Returns TRUE or FALSE based on the state of the Fraud Rules Engine Switch in the System Config.

=cut

sub is_fraud_rules_engine_off {
    my $self    = shift;
    return ( $self->get_fraud_rules_engine_switch_state eq 'off' ? 1 : 0 );
}

=head2 is_fraud_rules_engine_in_parallel

    $boolean = $self->is_fraud_rules_engine_in_parallel;

Returns TRUE or FALSE based on the state of the Fraud Rules Engine Switch in the System Config.

=cut

sub is_fraud_rules_engine_in_parallel {
    my $self    = shift;
    return ( $self->get_fraud_rules_engine_switch_state eq 'parallel' ? 1 : 0 );
}

=head2 client

Returns the client for this channel

=cut
sub client {
    my ($self) = @_;
    return $self->business()->client();
}

=head2 should_not_recalc_shipping_cost_for_customer_class

    $boolean = $self->should_not_recalc_shipping_cost_for_customer_class( $customer_class_rec );

Given a 'Public::CustomerClass' object this will return TRUE or FALSE based on whether its
'class' is in the 'Customer' section in the 'no_shipping_cost_recalc_customer_category_class'
setting.

=cut

sub should_not_recalc_shipping_cost_for_customer_class {
    my ( $self, $customer_class ) = @_;

    if ( !$customer_class || ref( $customer_class ) !~ m/Public::CustomerClass/ ) {
        croak "Must pass a 'Public::CustomerClass' object to '" . __PACKAGE__ . "->should_not_recalc_shipping_cost_for_customer_class'";
    }

    # get all the Settings for the 'Customer' config group
    my $all_settings = $self->_get_active_config_group_setting( 'Customer' );

    my $found = scalar grep {
        lc( $_->setting ) eq 'no_shipping_cost_recalc_customer_category_class'
            &&
        lc( $_->value ) eq lc( $customer_class->class )
    } @{ $all_settings };

    return $found;
}

=head2 welcome_pack_product_type_exclusion

    $array_ref = $self->welcome_pack_product_type_exclusion;

Return an Array Ref. of Product Types that are exlcuded from getting
Welcome Packs if an Order is made up entirely of these types.

=cut

sub welcome_pack_product_type_exclusion {
    my $self = shift;

    return $self->_get_config_group_setting_values( 'Welcome_Pack', 'exclude_on_product_type' );
}

=head2 supports_language

    $boolean = $channel->supports_language( $two_letter_language_code );

Given a two letter language code returns true if that language is supported for
that channel.

=cut

sub supports_language {
    my $self = shift;
    my $language = shift;

    my $setting = $self->_get_active_config_group_setting( 'Language', uc($language) ) || 'Off';

    return lc($setting) eq 'on' ? 1 : 0;
}

=head2 update_customer_language_on_every_order

    $boolean = $channel->update_customer_language_on_every_order();

Returns true if the customer language preference should be updated on every new
order on this channel that contains a valid language preference.

=cut

sub update_customer_language_on_every_order {
    my $self = shift;

    my $setting = $self->_get_active_config_group_setting( 'Language', 'update_customer_language_on_every_order' ) || 'Off';

    return lc($setting) eq 'on' ? 1 : 0;
}

=head2 can_apply_pre_order_discount

    $boolean = $self->can_apply_pre_order_discount;

Returns TRUE or FALSE depending on whether the Channel can Apply
Pre-Order Discounts to Customers (if the Customer has a Discount).

=cut

sub can_apply_pre_order_discount {
    my $self = shift;

    my $setting = $self->_get_active_config_group_setting( 'PreOrder', 'can_apply_discount' ) // 0;

    return ( $setting eq '1' ? 1 : 0 );
}

=head2 get_customer_category_pre_order_discount

    $number = $self->get_customer_category_pre_order_discount( $category_obj );

Returns the Pre-Order Discount that has been assigned to a Customer Category.

If the Category provided is not in the 'PreOrderDiscountCategory' config settings
for the Channel then 'undef' will be returned.

=cut

sub get_customer_category_pre_order_discount {
    my ( $self, $customer_category ) = @_;

    if ( !$customer_category || ref( $customer_category ) !~ m/Public::CustomerCategory/ ) {
        croak "Must pass a 'Public::CustomerCategory' object to '" . __PACKAGE__ . "->get_customer_category_pre_order_discount'";
    }

    my $category = $customer_category->category;
    return $self->_get_active_config_group_setting( 'PreOrderDiscountCategory', $category );
}

=head2 get_pre_order_system_config

    $hash_ref = $self->get_pre_order_system_config;

Returns a Hash Ref. of the System Config options for the 'PreOrder' group.

=cut

sub get_pre_order_system_config {
    my $self = shift;

    my $settings = $self->_get_active_config_group_setting('PreOrder');

    return      if ( !defined $settings );
    return {
        map { $_->setting => $_->value } @{ $settings },
    };
}

=head2 get_active_boxes

    $active_boxes_rs = $channel->get_active_boxes

Returns the active boxes for this channel

=cut

sub get_active_boxes {
    my $self = shift;

    return $self->boxes->search( { active => 1 } );
}

=head2 get_active_inner_boxes

    $active_inner_boxes_rs = $channel->get_active_inner_boxes

Returns the active inner boxes for this channel

=cut

sub get_active_inner_boxes {
    my $self = shift;

    return $self->inner_boxes->search( { active => 1 } );
}

1;
