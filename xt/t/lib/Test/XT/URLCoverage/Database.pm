package Test::XT::URLCoverage::Database;

use strict;
use warnings;
use Storable qw/nstore retrieve dclone/;
use Moose;
use Test::XT::URLCoverage::Handlers;

=head1 NAME

Test::XT::URLCoverage::Database - Interface to indexed, searchable coverage db

=head1 DESCRIPTION

This class provides the interface to the eventual db that we build up based on
the coverage files from Hudson

=head1 SYNOPSIS

 my $db = Test::XT::URLCoverage::Database->new();

 # You probably don't need to do any of the writing by hand, ever...
 # Just use generate_db.pl for that.
 $db->record({ request_data });
 $db->write_file( 'foobar.db' );

 # You may well want to do actual searches though
 $db->read_file( 'foobar.db' );

 # Do an exact-match search on an index. This would struggle to be a more naive
 # implementation, and is intended to perhaps guide you in writing your much
 # better, much more powerful searches as you need them...
 my ( $result_count, $matches_by_key ) = $db->key_search(
   url => '/GoodsIn/VendorSampleIn'
 );

=head1 ATTRIBUTES

=head2 database

A hashref that represents the DB in memory. C<read_file()> and C<write_file()>
perform serialization. C<record()> writes to this, and C<key_search()> read
from it. You don't need to access it directly B<ever> unless you're writing a
new search.

=cut

has 'database' => ( is => 'rw', isa => 'HashRef', default => sub {
    return {
        seen     => {},
        records  => [],
        indicies => {}
    };
} );

=head2 handler_search

Local copy of L<Test::XT::URLCoverage::Handlers> so that we can take advantage
of its caching mechanism. You don't need to access this directly.

=cut

has 'handler_search' => (
    is => 'rw',
    isa => 'Test::XT::URLCoverage::Handlers',
    default => sub {
        my $obj = Test::XT::URLCoverage::Handlers->new();
        $obj->load;
        $obj;
    }
);

=head1 INDICIES

Search happens via a collection of indicies that are created at C<record()>
time. That is, when you're searching for a record, you'll be searching for it
via at least one index, eg:

 # Search the url index for all records who returned '/bla/' as they were being
 # added.
 my @records = $self->key_search( url => '/bla/' );

All indicies defined in C<our %indicies> are attempted on record.

=cut

our %indicies;

=head2 url

Returns a copy of C<uri> from your input record

=cut

$indicies{'url'} = sub { return ( $_[1]->{'uri'} ) };

=head2 section

Returns a list of page-title atoms, with increasing specificity,
double-pipe-delimited. What this means a record with the title of
"Vendor Sample In - Goods In" gets indexed as:

 Goods In
 Goods In || Vendor Sample In

Which means you can search for all tests to do with Goods In, or just those
that are in 'Goods In / Vendor Sample In'. Title comes from C<title> in your
input record.

=cut

$indicies{'section'} = sub {
    my ( $class, $record ) = @_;

    # Split the page title on the appropriate part
    my @atoms = split(/&#8226;/, $record->{'title'});
    return unless @atoms > 1;

    my @sections = grep {! /XT\-DC/ } reverse @atoms;
    my @indicies;
    while ( @sections ) {
        push( @indicies, join ' || ', @sections );
        pop( @sections );
    }

    return @indicies;
};

=head2 handler_name

Returns the classname for the Handler which handles that URL. Uses the same
mechanism as the C<find_handler> script, which is via
L<Test::XT::URLCoverage::Handlers>.

=cut

$indicies{'handler_name'} = sub {
    my $self = shift;
    my $location = $self->_location( @_ ) || return;

    return $location->{'handler'} || ();
};

=head2 handler_file

Like C<handler_name>, but returns the file the class is implemented in

=cut

$indicies{'handler_file'} = sub {
    my $self = shift;
    my $location = $self->_location( @_ ) || return;

    return $location->{'lib_path'} || ();
};

=head2 template

Attempts to return the name of the template used to render a URL. Uses some
source introspection hack, so will give false-positives for any handler which
uses more than one template.

=cut

$indicies{'template'} = sub {
    my $self = shift;
    my $location = $self->_location( @_ ) || return;

    return $self->handler_search->templates( $location );
};

=head2 Writing your own index

The indicies are coderefs which accept C<self> and a copy of whatever you're
trying to record, and return a list of strings which are then saved and point
to the record. So for example:

 $self->record( $data );

Does something like:

 @keys = $indicies{'url'}->( $self, $data );

 for my $key (@keys) {
    push( @{ $self->database->{'indicies'}->{'url'}->{$key} }, $record );
 }

Probably best to look at the source for inspiration

=cut

# Caching here is all handled by the handler_search
sub _location {
    my ( $class, $record ) = @_;
    my $url = $record->{'uri'};

    # Look up the location object
    my $location = $class->handler_search->search( $url );

    return $location || ();
}

=head1 METHODS

=head2 read_file

Given a filename, reads the contents of it and replaces C<database> with the
values in it.

=cut

# Holy Moly It's Storable ALL THE WAY DOWN!!!!
sub read_file {
    my ( $self, $filename ) = @_;
    # This will die if it doesn't work. I hope.
    $self->database( retrieve( $filename ) );
}

=head2 write_file

Writes the contents of C<database> to the filename you provide.

=cut

sub write_file {
    my ( $self, $filename ) = @_;
    nstore $self->database, $filename;
}

=head2 record

Adds a record to C<database>, and adds links to it to the indicies. Note that we
will ignore functionally identical attempts to record the same record twice.

See L<Test::XT::URLCoverage::File> for a reasonable list of keys that most calls
to C<record()> will make.

=cut

sub record {
    my ( $self, $record ) = @_;

    # Have we seen this record before? If so, 'fraid we're going to ignore it
    return if $self->database->{'seen'}->{ $self->record_hash( $record ) }++;

    # Take a copy of the record
    push( @{ $self->database->{'records'} }, $record );

    # Then push a link to it in to each index
    for my $index ( keys %indicies ) {
        my @keys = $indicies{ $index }->( $self, $record );

        for my $key ( @keys ) {
            my $index_point =
                $self->database->{'indicies'}->{ $index }->{ $key } ||= [];
            push( @$index_point, $record );
        }
    }
}

=head2 key_search

Given an index and a key-value for it, returns the number of records that that
points to, and a hashref containing the key-value pointing to an arrayref of
those records

=cut

sub key_search {
    my ( $self, $index, $term ) = @_;
    die "No index in this database called [$index]"
        unless $self->database->{'indicies'}->{$index};

    my @records = @{ $self->database->{'indicies'}->{ $index }->{ $term } || [] };

    # dclone because do we trust the user not to screw with the returned data?
    # I think not...
    return( scalar(@records), { $term => dclone( \@records ) } );
}

sub fuzzy_search { die "Left as an exercise for the reader" }

sub record_hash {
    my ( $self, $record ) = @_;

    my $hash = '';
    while ( my ( $key, $value ) = each %$record ) {
        $hash .= "[$key|$value]";
    }

    return $hash;
}

1;
