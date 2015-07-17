package Test::XT::URLCoverage::Recorder;

=head1 NAME

Test::XT::URLCoverage::Recorder - Capture data from HTTP::Response and call stack

=head1 DESCRIPTION

Interface from Mechanize and the test-script in to the URLCoverage tools.

=head1 SYNOPSIS

 use Test::XT::URLCoverage::Recorder;
 Test::XT::URLCoverage::Recorder->log(
    HTTP::Response
 );

=head1 METHODS

=head2 log

Captures data from the call-stack and the single passed-in argument - a
L<HTTP::Response> object. Calls C<record()> on the class's C<file> attribute with
that data.

=head1 ATTRIBUTES

=head2 file

A class or object with a C<record()> method that we'll pass retrieved data to.

=cut

use strict;
use warnings;
use Moose;
use Test::XT::URLCoverage::File;

has 'file' => ( is => 'rw', default => sub { Test::XT::URLCoverage::File->new() } );

sub log {
    my ( $class, $http_response ) = @_;

    # Grab the whole stack
    my @stack;
    my $i;
    while ( my @call = caller( $i++ ) ) {
        push( @stack, \@call );
    }

    # Simplest implementation is just to grab the last one
    my ( $package, $filename, $line, $subroutine ) = @{ $stack[-1] };

    # Got a title?
    my $title       = '';
    my $is_redirect = $http_response->is_redirect || 0;
    if ( ! $http_response->is_redirect &&
        $http_response->content =~ m~<title>(.+?)</~i ) {
        $title = $1;
    }

    my $uri = $http_response->request->uri;

    return $class->file->record({
        uri        => $uri->path || '',
        title      => $title,
        filename   => $filename,
        line       => $line,
        subroutine => $subroutine,
        redirect   => $is_redirect
    });

}

1;
