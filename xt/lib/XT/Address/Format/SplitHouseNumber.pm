package XT::Address::Format::SplitHouseNumber;
use NAP::policy 'class';

extends 'XT::Address::Format';

=head1 NAME

XT::Address::Format::SplitHouseNumber

=head2 DESCRIPTION

A formatter that splits out a house number and street name from the
address_line_1 field. The format being used is '<street name> [house number]'.

=cut

sub APPLY_FORMAT {
    my $self = shift;

    $self->address->add_field( street_name => '' );
    $self->address->add_field( house_number => '' );

    if ( $self->address->get_field('address_line_1') =~ /\A\s*(?<street>.+?)(\s+(?<number>\d+))?\s*\Z/ ) {
        $self->address->set_field( street_name => $+{street} // '' );
        $self->address->set_field( house_number => $+{number} // '' );
    }

}
