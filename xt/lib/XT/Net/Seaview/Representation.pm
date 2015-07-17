package XT::Net::Seaview::Representation;

use NAP::policy "tt", 'class';

use XT::Data::Customer::Account;
use XT::Data::Address;
use XT::Data::Customer;

use DateTime::Format::ISO8601;
use DateTime::Format::HTTP;

=head1 NAME

XT::Net::Seaview::Representation

=head1 DESCRIPTION

The Seaview representation classes provide a way of serialising and
deserialising Seaview requests and responses. This is a base representation
class

=head1 ATTRIBUTES

=head2 identity

Resource identity

=cut

has identity => (
    is       => 'ro',
    isa      => 'Any',
    required => 1,
    lazy     => 1,
    builder  => '_build_identity',
);

=head2 src

This representation's source data

=cut

has src => (
    is       => 'ro',
    isa      => 'Any',
    required => 1,
);

=head2

Meta-information about the representation

=cut

has _meta => (
    is => 'ro',
);

=head2 serialised_fields

=cut

has serialised_fields => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub{my %merged = (%{$_[0]->auto_fields},
                                 %{$_[0]->manual_fields}); \%merged},
);

=head1 OPTIONAL ATTRIBUTES

=head2 last_modified

The contents of the Last-Modified header

=cut

has last_modified => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    builder  => '_build_last_modified',
);

sub _build_last_modified {
    my $self     = shift;
    my $last_mod = undef;

    if(ref $self->_meta eq 'HTTP::Headers'){
        $last_mod = $self->_meta->header('Last-Modified');
    }
    unless(defined $last_mod){
        my $zulu_datestr = $self->data->{'lastUpdatedDate'};
        my $dt = DateTime::Format::ISO8601->parse_datetime($zulu_datestr);
        $last_mod = DateTime::Format::HTTP->format_datetime($dt);
    }

    return $last_mod;
}

=head1 METHODS

=head2 as_data_obj

Build an instance of the relevant XT::Data:: object

=cut

sub as_data_obj {
    my $self = shift;

    # build XT::Data:: constructor params from representation attributes
    my $params = { map { $_ => $self->$_ }
                   grep { defined $self->$_ } keys %{$self->serialised_fields}};

    # Identity and last_modified fields are (intentionally) not included in
    # the representation's serialised fields - add them in now
    $params->{urn} = $self->identity;
    $params->{last_modified} = $self->last_modified;

    if($self->can('data_obj_xtra_params')){
        my %params_plus = (%$params, %{$self->data_obj_xtra_params});
        $params = \%params_plus;
    }

    return $self->data_obj_class->new($params);
}

