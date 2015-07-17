package NAP::Template::Plugin::PrintDocs;

use strict;
use warnings;

use base 'Template::Plugin';

use XTracker::PrintFunctions ();

=head2 document_path( $filename ) : $print_docs_relative_path

Returns the absolute path for the specified document name. This is used by
templates to include resources in printed documents without having to know
anything about the layout.

=cut

sub document_path {
    my ( $self, $filename ) = @_;
    return XTracker::PrintFunctions::path_for_print_document(
        XTracker::PrintFunctions::document_details_from_name( $filename ),
    );
}

=head2 relative_document_path( $filename ) : $print_docs_relative_path

Returns the path for the specified document name, relative to the print_docs
base directory. This is so templates can find the files they need without
having to know anything about the directory layout.

=cut

sub relative_document_path {
    my ( $self, $filename ) = @_;
    return '/print_docs/' . XTracker::PrintFunctions::path_for_print_document({
        %{ XTracker::PrintFunctions::document_details_from_name( $filename ) },
        relative => 1,
    });
}

1;
