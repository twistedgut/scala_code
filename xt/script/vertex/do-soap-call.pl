#!/opt/xt/xt-perl/bin/perl
#
# ropey workaround for ten-year-old memory bug in mod_perl/XML::Parser

# given the name of a SOAP document, make the request, *parse it*
# (parsing it what tanks mod_perl), and stash in a matching response document
# the results of the parsing.
#
# return 0 iff we succeed, otherwise return 1 if the request fails,
# and return 2 if the request itself was malformed in some way

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Carp qw( croak );
use Data::Printer;

use XTracker::Vertex;
use SOAP::Vertex '0.0.3';
use SOAP::Vertex::QuotationRequestDoc;

use Data::Serializer;

# expect three arguments, which are the full path names of the 
# request file, the response file and the error file

my ($request_path, $response_path, $error_path) = @ARGV;

die "must provide three path names\n"
    unless $request_path && $response_path && $error_path;

die "Vertex request file '$request_path' not found or empty\n"
    unless $request_path && -f $request_path && -s $request_path;

local $/ = undef;

open(my $request_fd,'<:encoding(UTF-8)',$request_path) 
    or die "Unable to open '$request_path' for reading\n";

my $quotation = <$request_fd>;

close $request_fd;

die "Unable to read anything from '$request_path'\n"
    unless $quotation;

my $vertex = SOAP::Vertex::QuotationRequestDoc->new(
    {
        soap_host   => $ENV{VERTEX_SOAP_HOST},
        soap_port   => $ENV{VERTEX_SOAP_PORT},

        username    => $ENV{VERTEX_SOAP_USER},
        password    => $ENV{VERTEX_SOAP_PASS},

        soap_trace  => ''
    }
);

# shouldn't be there, but who knows?
unlink $error_path    if -f $error_path;
unlink $response_path if -f $response_path;

my $soap_result;

eval {
    $soap_result = $vertex->soap_call_xml( $quotation );
};

if ( my $e = $@ ) {
    die "SOAP call failed: $e\n";
}

if ( $soap_result ) {
    open( my $response_fd, '>:encoding(UTF-8)', $response_path )
        or die "Unable to open '$response_path' for writing\n";

    my $serializer = Data::Serializer->new();
    my $serialized_response = $serializer->freeze( $soap_result );

    print $response_fd $serialized_response
        or die "Unable to write to '$response_path'\n";

    close $response_fd;

    exit 0; # hooray!
}
else {
    my $soap_error = $vertex->get_soap_error();

    if ( $soap_error ) {
        open( my $error_fd, '>:encoding(UTF-8)', $error_path )
            or die "Unable to open '$error_path' for writing\n";

        print $error_fd $soap_error
            or die "Unable to write to '$error_path'\n";

        close $error_fd;

        exit 1;  # oh, well
    }
    else {
        die "Nothing worked and we don't know why\n";
    }
}

