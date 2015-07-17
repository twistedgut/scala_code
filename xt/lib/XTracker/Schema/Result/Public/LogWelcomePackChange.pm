use utf8;
package XTracker::Schema::Result::Public::LogWelcomePackChange;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_welcome_pack_change");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_welcome_pack_change_id_seq",
  },
  "welcome_pack_change_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "affected_id",
  { data_type => "integer", is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "welcome_pack_change",
  "XTracker::Schema::Result::Public::WelcomePackChange",
  { id => "welcome_pack_change_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WWL1O/QuVLgQGkmdh7y1aQ


use feature     qw( switch );

use XTracker::Config::Local             qw( config_var );
use XTracker::Constants::FromDB         qw( :welcome_pack_change );


=head2 affected

    $rec = $self->affected;

Returns the Record that was affected by the change.

=cut

sub affected {
    my $self    = shift;

    my $schema  = $self->result_source->schema;

    my $rec;
    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $self->welcome_pack_change_id ) {
            when ( $WELCOME_PACK_CHANGE__CONFIG_GROUP ) {
                $rec    = $schema->resultset('SystemConfig::ConfigGroup')
                                    ->find( $self->affected_id );
            }
            when ( $WELCOME_PACK_CHANGE__CONFIG_SETTING ) {
                $rec    = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                    ->find( $self->affected_id );
            }
        }
    }

    return $rec;
}

=head2 channel

    $rec = $self->channel;

Returns the Sales Channel DBIC record that is associated with the Affected record.

=cut

sub channel {
    my $self    = shift;

    my $affected    = $self->affected;
    return          if ( !$affected );

    my $channel;
    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $self->welcome_pack_change_id ) {
            when ( $WELCOME_PACK_CHANGE__CONFIG_GROUP ) {
                $channel    = $affected->channel;
            }
            when ( $WELCOME_PACK_CHANGE__CONFIG_SETTING ) {
                $channel    = $affected->config_group->channel;
            }
        }
    }

    return $channel;
}

=head2 description

    $string = $self->description;

Will return the Description of the change.

=cut

sub description {
    my $self    = shift;

    my $affected    = $self->affected;
    return          if ( !$affected );

    my $language_rs = $self->result_source->schema
                            ->resultset('Public::Language');

    my $description;
    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $self->welcome_pack_change_id ) {
            when ( $WELCOME_PACK_CHANGE__CONFIG_GROUP ) {
                $description    = 'All Packs';
            }
            when ( $WELCOME_PACK_CHANGE__CONFIG_SETTING ) {
                if ( uc( $affected->setting ) eq 'DEFAULT' ) {
                    $description    = $affected->setting;
                }
                else {
                    my $language    = $language_rs->find( { code => $affected->setting } );
                    $description    = $language->description;
                }
            }
        }
    }

    return $description;
}

=head2 change_value

    $string = $self->change_value;

Will return a Value relevant to the change.

=cut

sub change_value {
    my $self    = shift;

    my $value;
    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $self->welcome_pack_change_id ) {
            when ( $WELCOME_PACK_CHANGE__CONFIG_GROUP ) {
                $value  = ( $self->value ? 'Enabled' : 'Disabled' );
            }
            when ( $WELCOME_PACK_CHANGE__CONFIG_SETTING ) {
                $value  = $self->value;
            }
        }
    }

    return $value;
}

1;
