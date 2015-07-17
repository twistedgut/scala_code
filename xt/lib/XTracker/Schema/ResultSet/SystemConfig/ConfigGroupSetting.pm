package XTracker::Schema::ResultSet::SystemConfig::ConfigGroupSetting;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';


=head2 config_var

  usage        : $value = $schema->resultset('SystemConfig::ConfigGroupSetting')
                            ->config_var(
                                    $group_name,
                                    $group_setting,
                                    $channel_id (optional)
                        );

  description  : This returns the setting for a group. If channel_id is supplied
                 then the group with that channel id will be searched. Will return
                 an Array ref of values if there is more than one value for the
                 setting.

  parameters   : The Name of the Conf Group, The Name of the Conf Group Setting
                 and A Sales Channel Id (optional).
  returns      : The value for setting could be Scalar or an Array Ref.

=cut

sub config_var {
    my $rs              = shift;
    my $group_name      = shift;
    my $group_setting   = shift;
    my $channel_id      = shift;


    my $retval;

    my $cond    = {
            'config_group.name'     => $group_name,
            'config_group.active'   => 1,
            'setting'               => $group_setting,
            'me.active'             => 1,
            'config_group.channel_id'=> $channel_id,
        };

    my $results = $rs->search(
                                $cond,
                                {
                                    join    => 'config_group',
                                    order_by=> 'sequence'
                                }
                            );

    while ( my $rec = $results->next ) {
        push @{ $retval }, $rec->value;
    }

    if ( $retval ) {
        $retval = ( @{ $retval } > 1 ? $retval : $retval->[0] );
    }

    return $retval;
}

=head2 config_vars_by_group

Return a list of config settings where the config_group.name
matches the group name provided.

=cut

sub config_vars_by_group {
    my $rs = shift;
    my $group_name = shift;
    my $channel_id = shift;

    my $retval=[];

    my $cond = {
                'config_group.name'       => $group_name,
                'config_group.active'     => 1,
                'me.active'               => 1,
                'config_group.channel_id' => $channel_id
               };

    my $results=$rs->search( $cond,
                             { join     => 'config_group',
                               order_by => 'sequence'
                             }
                           );

    while (my $result=$results->next) {
        push @{$retval},{ $result->setting => $result->value };
    }

    return $retval;
}


=head2 update_systemconfig

Updates a ConfigGroupSetting given the config_group.name, config_group.channel_id and setting.
Returns the ConfigGroupSetting id, or undef if the setting is not found.

=cut

sub update_systemconfig {
    my ( $self, $parameters ) = @_;

    my $cond = {
                'config_group.name'       => $parameters->{config_group_name},
                'config_group.active'     => 1,
                'me.active'               => 1,
                'me.setting'              => $parameters->{setting},
                'config_group.channel_id' => $parameters->{channel_id},
               };

    my $setting = $self->result_source->resultset->search( $cond,
                             { join     => 'config_group',
                             }
                        )->first
                  or die "Unknown SystemConfig ConfigGroupSetting provided";

    $setting->update( { value => $parameters->{value} } );

    return $setting->id;

};

1;
