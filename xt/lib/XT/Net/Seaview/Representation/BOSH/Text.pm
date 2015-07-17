package XT::Net::Seaview::Representation::BOSH::Text;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::BOSH /;
with qw/ XT::Net::Seaview::Role::Representation::Text
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::BOSH::Text

=head1 DESCRIPTION

XT BOSH objects as Seaview/BOSH-able Text representations.

=cut

my $auto_fields   = { value => 'value' };
my $manual_fields = {};

with 'XT::Net::Seaview::Role::GenAttrs' => { fields => $auto_fields };

=head1 ATTRIBUTES

=cut

has 'auto_fields' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { $auto_fields },
);

has 'manual_fields' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { $manual_fields },
);

=head1 METHODS

=head2 to_rep

As it's just a text representation, no transformation is required and this
just returns the result of C<value>.

=cut

sub to_rep {
    my $self = shift;

    return $self->value;

}
