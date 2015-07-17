package XT::Text::PlaceHolder::Type::C;

use NAP::policy "tt",     'class';
extends 'XT::Text::PlaceHolder::Type';

=head1 XT::Text::PlaceHolder::Type::C

Config Place Holder.

    P[C.ConfigSection.ConfigSetting]

=cut

use XTracker::Config::Local         qw( config_var );

use MooseX::Types::Moose qw(
    Str
    RegexpRef
);


=head1 ATTRIBUTES

=cut

=head2 part1_split_pattern

Used to get the Config Section.

=cut

has part1_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_config_section>^\w+.*$)/;
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

has _config_section => (
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

Will get the Value for the Place Holder from Config.

=cut

sub value {
    my $self    = shift;

    my $section = $self->_config_section;
    $section    .= '_' . $self->channel->business->config_section
                            if ( $self->_is_channelised );

    return $self->_check_value(
        config_var(
            $section,
            $self->_config_setting,
        )
    );
}

