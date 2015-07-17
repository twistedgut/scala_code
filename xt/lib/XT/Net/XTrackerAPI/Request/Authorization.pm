package XT::Net::XTrackerAPI::Request::Authorization;
use NAP::policy "tt", "class";

=head1 NAME

XT::Net::XTrackerAPI::Request::Authorization - Auth info about the logged in user

=cut

use MooseX::Params::Validate;
use Moose::Util::TypeConstraints;

has auth_level  => (is => "rw", default => 0 );
has is_operator => (is => "rw", default => 0 );
has is_manager  => (is => "rw", default => 0 );


subtype "AuthorizationLevel",
    as "Str",
    where { /^operator|manager$/ };

sub verify_level {
    my $self = shift;
    my ($level, $message) = pos_validated_list( \@_,
        { isa => "AuthorizationLevel" },
        { isa => "Str", default => "This" },
    );
    my $method_name = "is_$level";
    $self->$method_name
        or die("Unauthorized: $message requires '$level' level access.\n");
}

1;
