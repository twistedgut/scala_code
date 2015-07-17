package Test::XT::URLCoverage::File;

use strict;
use warnings;
use Moose;
use List::MoreUtils qw/mesh/;

=head1 NAME

Test::XT::URLCoverage::File - Interface to the file we store raw URLCoverage
data to

=head1 DESCRIPTION

Interface to the file we store raw URLCoverate to.

=head1 ATTRIBUTES

=head2 filename

Filename we're interface. Defaults to C<t/tmp/url_coverage.data>.

=cut

=head2 line_delimiter

Line separator - defaults to C<\n>

=cut

=head2 field_delimiter

Field separator - defaults to C<\0>.

=cut

my @str = ( is => 'rw', isa => 'Str' );
has 'filename'        => ( @str, default => 't/tmp/url_coverage.data' );
has 'line_delimiter'  => ( @str, default => "\n" );
has 'field_delimiter' => ( @str, default => "\0" );

=head1 FIELDS

All strings:

 uri
 title
 filename
 line
 subroutine
 redirect

=cut

my @fields = qw( uri title filename line subroutine redirect );
my %fields = map { $_ => 1 } @fields;

=head1 METHODS

=head2 record

Passes its arguments to C<serialize()> and writes them to the file whose filename
is returned by C<filename()>.

=cut

sub record {
    my ( $class, $args ) = @_;
    my $line = $class->serialize( $args );

    open( my $fh, '>>', $class->filename ) ||
        die "Couldn't open for writing: [" . $class->filename . "]: $!";
    print $fh $line;
    close $fh;
}

=head2 fetch_all

Retrieves all records in the file C<filename()>, deserializing them and returning
an arrayref of that.

=cut

sub fetch_all {
    my ( $class ) = @_;

    open( my $fh, '<', $class->filename ) ||
        die "Couldn't open for writing: [" . $class->filename . "]: $!";
    local $/ = $class->line_delimiter;
    my @lines = grep {$_} map { $class->deserialize( $_ ) } (<$fh>);
    close $fh;

    return @lines;
}

=head2 serialize

Turns a hashref corresponding to B<FIELDS> above in to a string suitable for
writing

=cut

sub serialize {
    my ( $self, $data ) = @_;

    # Only keys we know...
    for ( keys %$data ) {
        die "Unknown field $_" unless exists $fields{ $_ };
    }

    # But also /all/ the keys we know
    for ( @fields ) {
        die "You must provide a $_" unless exists $data->{ $_ };
    }

    my $field_delim = $self->field_delimiter;
    my $line_delim  = $self->line_delimiter;

    my $string =
        join $field_delim,
        map { defined( $data->{$_} ) ? $data->{$_} : '' }
        @fields;

    $string .= $line_delim;
    return $string;
}

=head2 deserialize

Turns a string created by C<serialize()> in to a hashref

=cut

sub deserialize {
    my ( $self, $data ) = @_;

    my $field_delim = $self->field_delimiter;
    my $line_delim  = $self->line_delimiter;

    return unless $data =~ m/$field_delim/;

    # Remove the line-terminator if it's still there
    $data =~ s/$line_delim$//;

    # Grab the fields
    my @returned_fields = split( /$field_delim/, $data );

    # Check we have the right number of fields
    die "Incorrect number of fields in [$data]"
        unless @fields == @returned_fields;

    # Map the keys and values using List::MoreUtils handy 'mesh' function
    my %return_hash = mesh( @fields, @returned_fields );

    return \%return_hash;
}

1;
