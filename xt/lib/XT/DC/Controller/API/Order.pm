package XT::DC::Controller::API::Order;

use NAP::policy qw/class/;

use XT::DC::Model::GenerateXml;

use Try::Tiny;

BEGIN { extends 'NAP::Catalyst::Controller::REST'; }

=head1 NAME

XT::DC::Controller::API::Order

=head1 DESCRIPTION

This catalyst controller provides an interface to create order xml documents to
be imported into XT.

=head1 METHODS

=head2 create
    /api/order

Post JSON order params to this endpoint and it will genereate and write an order
XML document to the /xmlwaiting dir. The response is composed of a string containing
the XML document created, and the file path of this document.

=cut

sub create : Path('/api/order') : ActionClass('REST') : Args(0) { }

sub create_POST {
    my ( $self, $c ) = @_;

    if ( ! $c->check_access() ) {
        $c->status_forbidden();
        return;
    }

    my ($error, $xml_string, $file_name);
    my $xml_generator = XT::DC::Model::GenerateXml->new();

    my $parameters = $c->request->data();

    try {
        ($xml_string, $file_name) = $xml_generator->write_to_file($parameters);
    }
    catch {
        $error = $_;
    };

    $c->stash( rest => {
        ( error      => $error )x!! $error,
        ( file_path  => $file_name, xml => $xml_string)x!! $xml_string
    });
}
