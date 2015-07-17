use utf8;
package XTracker::Schema::Result::SystemConfig::ConfigGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("system_config.config_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "system_config.config_group_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("config_group_uniq", ["name", "channel_id"]);
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
__PACKAGE__->has_many(
  "config_group_settings",
  "XTracker::Schema::Result::SystemConfig::ConfigGroupSetting",
  { "foreign.config_group_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HgrNUpqbdwYhRgJjeEJfbw

sub setting {
    my ( $self, $setting_name ) = @_;
    return
        $self->find_related('config_group_settings', { setting => $setting_name } );
}

sub setting_value {
    my ( $self, $setting_name ) = @_;
    my $setting = $self->setting( $setting_name );
    return unless $setting;
    return $setting->value;
}

=head2 premier_sla_interval

Return the interval for premier SLAs for this config setting.

=cut

sub premier_sla_interval { return shift->_sla_interval('sla_premier'); }

=head2 standard_sla_interval

Return the interval for standard SLAs for this config setting.

=cut

sub standard_sla_interval { return shift->_sla_interval('sla_standard'); }

=head2 transfer_sla_interval

Return the interval for transfer SLAs for this config setting.

=cut

sub transfer_sla_interval { return shift->_sla_interval('sla_transfer'); }

=head2 sale_sla_interval

Return the interval for sale SLAs for this config setting.

=cut

sub sale_sla_interval { return shift->_sla_interval('sla_sale'); }

=head2 staff_sla_interval

Return the interval for staff SLAs for this config setting.

=cut

sub staff_sla_interval { return shift->_sla_interval('sla_staff'); }

=head2 exchange_creation_sla_interval

Return the interval for exchange creation SLAs for this config setting.

=cut

sub exchange_creation_sla_interval {
    return shift->_sla_interval('sla_exchange_creation');
}

sub _sla_interval {
    my ( $self, $sla_type ) = @_;
    my $setting = $self->config_group_settings->search(
        { setting => $sla_type, active => 1 },
        { rows => 1 }
    )->single;
    return unless $setting;
    return $setting->value;
}
1;
