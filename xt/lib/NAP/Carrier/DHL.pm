package NAP::Carrier::DHL;
use Moose;
use XT::Rules::Solve; # YEAH YEAH YEAH!!!!!!!!!!!!!?!
extends 'NAP::Carrier';
with 'NAP::Carrier::DHL::Role::Address';

use MooseX::Types::Moose qw(Bool Str Int Num ArrayRef HashRef Maybe);

has config => (
    is      => 'rw',
    isa     => 'NAP::Carrier::DHL::Config',
);

has manifest_pdf_link => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_manifest_pdf_link',
);

has manifest_txt_link => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_manifest_txt_link',
);

sub _build_manifest_pdf_link {
    my $self = shift;

    # logic from XTracker/Order/Fulfilment/Manifest.pm
    my $pdf_link =
          '/manifest/pdf/'
        . $self->manifest->filename
        . '.pdf';
    return $pdf_link;
}

sub _build_manifest_txt_link {
    my $self = shift;
    my $txt_link;

    my $format = XT::Rules::Solve->solve('Carrier::manifest_format' => {
        # This is pretty ew, but someone decided to strip the data from
        # the class itself o_O
        carrier_id => $self->manifest->carrier->id
    });

    # logic from XTracker/Order/Fulfilment/Manifest.pm
    if ( $format eq 'csv' ) {
        $txt_link =
              '/manifest/txt/'
            . $self->manifest->filename
            . '.csv';
    }
    else {
        $txt_link =
              '/manifest/txt/'
            . $self->manifest->filename
            . '.txt';
    }

    return $txt_link;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use Carp qw<cluck croak>;

use NAP::Carrier::DHL::Config;

sub BUILD {
    my $self = shift;

    # TODO - actually get the config
    # get the configuration for UPS and store in ->config for ease of access
    $self->config(
        NAP::Carrier::DHL::Config->new({})
    );
}

=head2 validate_address() : Bool

Validate the address and return a true value if validation was successful.

=cut

sub validate_address { return shift->role_validate_address; }

=head2 is_autoable() : Bool

Does a call to L<XTracker::Schema::Result::Public::Shipment::can_be_carrier_automated>.

=cut

sub is_autoable {
    # make sure shipment is upto date
    return shift->shipment->discard_changes->can_be_carrier_automated;
}

=head2 deduce_autoable

This sets the RTCB field to true if shipment can be automated

=cut

sub deduce_autoable {
    return 0;
}

=head2 shipping_service descriptions

 Should return an array of carrier service descriptions for the shipment.
 This functionality currently doesn't exist for this carrier, so returns a zero-length array.

=cut

sub shipping_service_descriptions {
    my ($self ) = @_;

    return [];

}



1;
__END__
