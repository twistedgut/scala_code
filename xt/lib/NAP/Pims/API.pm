package NAP::Pims::API;
use NAP::policy qw/class/;

=head1 NAME

NAP::Pims::API

=head1 DESCRIPTION

API module for communicating with the Packaging Inventory Management System

=cut

use JSON;
use MooseX::Params::Validate qw/validated_list/;
use NAP::Pims::API::Exception;

has ua => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    default => sub { LWP::UserAgent->new }
);

=head1 REQUIRED PARAMETERS

=head2 url

Base URL where the Pims instance is located

=cut
has url => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

=head1 PUBLIC METHODS

=head2 get_quantities

Retrieve the box stock levels

return = $box_quantities : An araryref, where each entry is a hashref, with the following keys:
    code - The unique identifier code for the box
    quantity - Number of stock items for this box

=cut
sub get_quantities {
    my ($self) = @_;
    $self->_parse_response({
        http_response   => $self->ua->get($self->url . "/quantity"),
        parse_as_json   => 1,
    });
}

sub _parse_response {
    my ($self, $http_response, $parse_as_json) = validated_list(\@_,
        http_response   => { isa => 'HTTP::Response' },
        parse_as_json   => { isa => 'Bool', default => 0 }
    );

    NAP::Pims::API::Exception->throw(
        status_code => $http_response->code,
        description => $http_response->status_line
    ) unless $http_response->is_success;

    my $decoded_body = $http_response->decoded_content;
    ($parse_as_json
        ? decode_json($decoded_body)
        : $decoded_body
    );
}