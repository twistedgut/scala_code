package XT::DC::Messaging::Role::Producer;
use NAP::policy "tt", 'role';
with 'NAP::Messaging::Role::Producer' => {
    -alias => {
        '_build_preprocessor' => '_build_base_preprocessor',
    },
    -excludes => ['_build_preprocessor'],
};

=head1 NAME

XT::DC::Messaging::Role::Producer - XT specific Producer / Transformer role

=head1 DESCRIPTION

Use it the same way as L<NAP::Messaging::Role::Producer>. Thins will
give you a XT-specific C<preprocessor>.

=cut

use Data::Visitor::Callback;

use DateTime;
use NAP::DC::Barcode::Container;
use XTracker::DBEncode 'decode_it';

=head2 _build_preprocessor() : Data::Visitor::Callback $obj

Return a Callback object that contains appropriate serializations for
all objects that may appear in an AMQ message payload.

=cut

sub _build_preprocessor {
    my $self = shift;

    # Construct a new Callback object based on the one created by
    # NAP::Messaging::Role::Producer

    my $base_preprocessor = $self->_build_base_preprocessor;

    my $callbacks = $base_preprocessor->callbacks;
    $callbacks->{"NAP::DC::Barcode::Container"} = sub { "$_" };
    $callbacks->{plain_value} = sub { scalar decode_it($_) };

    return Data::Visitor::Callback->new($callbacks);
}
