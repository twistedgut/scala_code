package XT::Net::Seaview::Representation::Customer::JSON;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::Customer /;
with qw/ XT::Net::Seaview::Role::Representation::JSON
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::Customer::JSON

=head1 DESCRIPTION

XT customer objects as Seaview-able JSON representations

=head1 DATA ACCESS METHODS

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Customer methods and the values are the
corresponding Seaview JSON keys

=cut

my $auto_fields = { addresses => 'addresses',
                    accounts  => 'accounts'};

my $manual_fields = {};

with 'XT::Net::Seaview::Role::GenAttrs' => { fields => $auto_fields };

=head1 ATTRIBUTES

=cut

has 'auto_fields' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub { $auto_fields },
);

has 'manual_fields' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub { $manual_fields },
);

=head1 METHODS

=head2 to_rep

Create a JSON representation of this customer

=cut

sub to_rep {
    my $self = shift;

    my $customer = {};

    # Create a JSON-LD document
    return JSON->new->utf8->encode($customer);
}
