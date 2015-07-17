package XT::Text::PlaceHolder::Type::SC;

use NAP::policy "tt",     'class';
extends 'XT::Text::PlaceHolder::Type';

=head1 XT::Text::PlaceHolder::Type::SC

System Config Place Holder.

    P[SC.ConfigGroup.ConfigSetting]

=cut

use XTracker::Config::Local         qw( sys_config_var );
use MooseX::Types::Moose qw(
    Str
    RegexpRef
);


=head1 ATTRIBUTES

=cut

=head2 schema

Schema is required for this Place Holder.

=cut

has '+schema' => (
    required    => 1,
    lazy        => 0,
);

=head2 part1_split_pattern

Used to get the Config Group.

=cut

has part1_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_config_group>^\w+.*$)/;
    },
);

=head2 part2_split_pattern

Used to get the Config Setting.

=cut

has part2_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_config_setting>^\w+.*$)/;
    },
);


#
# These will be populated when the Parts get split up by the
# Parent method: '_split_up_parts' at the point of instantiation
#

has _config_group => (
    is      => 'rw',
    isa     => Str,
);

has _config_setting => (
    is      => 'rw',
    isa     => Str,
);

=head1 METHODS

=head2 value

    $scalar = $self->value;

Will get the Value for the Place Holder from System Config.

=cut

sub value {
    my $self    = shift;

    my $channel_id;
    $channel_id = $self->channel->id        if ( $self->_is_channelised );

    return $self->_check_value(
        sys_config_var(
            $self->schema,
            $self->_config_group,
            $self->_config_setting,
            $channel_id
        )
    );
}

