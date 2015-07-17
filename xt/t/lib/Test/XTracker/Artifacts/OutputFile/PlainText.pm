package Test::XTracker::Artifacts::OutputFile::PlainText;

use NAP::policy "tt",     qw( class test );
extends 'Test::XTracker::Artifacts::OutputFile';

=head1 NAME

Test::XTracker::Artifacts::OutputFile::PlainText

=head2 DESCRIPTION

Plugin for C<Test::XTracker::Artifacts::OutputFile> Used to parse Plain Text data files produced by the system such as 'csv'.

This extends C<Test::XTracker::Artifacts::OutputFile>.

=head2 SYNOPSIS

    my $dir = Test::XTracker::Artifacts::OutputFile->new( {
                                                # required
                                                file_type               => 'PlainText',
                                                read_directory          => '/some/path/where/files/appear',
                                                filter_regex            => qr/filenames to look out for/,
                                                record_delimiter        => "\n",
                                                field_delimiter         => ",",

                                                # optional
                                                file_id_regex           => qr/filename_(id)/,
                                                first_row_has_headings  => 0,           # default TRUE
                                                primary_key             => 'ORDER_NR',  # field to act as a Primary Key
                                        } );

    my @files   = $dir->new_files;      # will return an Array of "Test::XTracker::Artifacts::OutputFile::PlainText::File"
                                        # objects which provides methods to return the contents of the file.

This will Parse text files using the record and field delimiters supplied.

=cut

use File::Slurp;

=head1 ATTRIBUTES

This inherits Attributes from C<Test::XTracker::Artifacts::OutputFile>.

=cut

=head2 record_delimiter

The delimiter to divide the contents of the file up into records.

=cut

has record_delimiter => (
    is      => 'rw',
    isa     => 'Str',
    required=> 1,
);

=head2 field_delimiter

The delimiter used to divide each record up into fields.

=cut

has field_delimiter => (
    is      => 'rw',
    isa     => 'Str',
    required=> 1,
);

=head2 first_row_has_headings

Indicates if the first record of the file contains filed headings. Defaults to TRUE.

=cut

has first_row_has_headings => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

=head2 field_headings

If the first record doesn't have field headings then they can be passed in using this attribute.

WARNING: This will NOT contain the headings (if they exist) in the first record of the file to
         access those you should use the 'headings' method on the C<Test::XTracker::Artifacts::OutputFile::PlainText::File>
         class.


TODO: This Attribute exists but its use has NOT been implemented yet.

=cut

has field_headings => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

=head2 primary_key

This is the heading of the field to use as the primary key in the 'as_data_by_pkey' method
on the C<Test::XTracker::Artifacts::OutputFile::PlainText::File> class.

=cut

has primary_key => (
    is      => 'rw',
    isa     => 'Str',
);

=head1 METHODS

=head2 process_file

A method that is called when files are found and shouldn't be called 'manually'.

This will return an instance of C<Test::XTracker::Artifacts::OutputFile::PlainText::File>.

=cut

sub process_file {
    my ( $self, $event_type, $full_path, $rel_path ) = @_;

    my $file_id;
    if ( my $filter = $self->file_id_regex ) {
        my $filename    = $rel_path;
        $filename       =~ qr/$filter/;
        $file_id        = $1;
    }

    my $object = Test::XTracker::Artifacts::OutputFile::PlainText::File->new(
        content   => read_file( $full_path, { binmode => ':utf8' } ) || '', # From File::Slurp
        filename  => $rel_path,
        full_path => $full_path,
        artifact  => $self,
        file_id   => $file_id,
    );

    return $object;
}

#---------------------------------------------------------------------------------

=head1

=head1 ============

=head1 PARSER CLASS

=head1 ============

=head1

=cut

#---------------------------------------------------------------------------------

package Test::XTracker::Artifacts::OutputFile::PlainText::File; ## no critic(ProhibitMultiplePackages)

use NAP::policy "tt",     qw( class test );

=head1 NAME

Test::XTracker::Artifacts::OutputFile::PlainText::File

=head2 DESCRIPTION

Used by C<Test::XTracker::Artifacts::OutputFile::PlainText> to parse the contents of a file.

=cut

=head1 ATTRIBUTES

=head2 content

File content as string.

=head2 filename

Relative filename.

=head2 full_path

Full Path of the filename.

=head2 file_id

Contains the Id of the file if a 'file_id_regex' was specified when
building a C<Test::XTracker::Artifacts::OutputFile::PlainText> object.

=head2 artifact

The C<Test::XTracker::Artifacts::OutputFile::PlainText> object.

=cut

has 'content'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'filename'      => ( is => 'ro', isa => 'Str'  );
has 'full_path'     => ( is => 'ro', isa => 'Str'  );
has 'file_id'       => ( is => 'ro', isa => 'Str|Undef' );
has 'artifact'      => ( is => 'ro', required => 1 );

=head1 METHODS

These methods can be used on objects returned by the 'new_files' and 'wait_for_new_files' methods on the
C<Test::XTracker::Artifacts::OutputFile> class which are inherited by '*::OutputFile::PlainText'.

    my $dir = Test::XTracker::Artifacts::OutputFile->new( ... );

    my ( $file )    = $dir->new_files;

    $file->as_rows;
    $file->headings;
    $file->as_rows_of_data;
    $file->as_data_by_pkey;

All of the methods use the '$file->artifact' attribute to access the record & field delimiters and other attributes
passed into the the C<Test::XTracker::Artifacts::OutputFile> class at the point of construction.

=head2 as_rows

    $array_ref  = $file->as_rows;

Returns every row found in the file (including the first row even if it is the headings) in an ArrayRef of ArrayRefs.

    [
        [ Field1, field2, etc. ],
        [ Field1, field2, etc. ],
        [ Field1, field2, etc. ],
        ...
    ]

=head2 headings

    $array_ref  = $file->headings;
            or
    @array      = $file->headings;

If the 'first_row_has_headings' attribute is TRUE then this will return a list of the heagings found on the
first record of the file. Will return either an Array Ref or Array depending on the context it was called.

    [
        'ORDER_NR',
        'CUSTOMER_NR',
        ...
    ]

=head2 as_rows_of_data

    $array_ref  = $file->as_rows_of_data;

This will return an Array Ref of Hash Refs containing the data from the file using the field headings found on
the first row as keys for the values. If there are NO field headings in the first row of the file then simply
'FIELD_1', 'FIELD_2' etc. will be used as the keys for the data in the Hash Ref.

    [
        { FIELD_1 => 'value', FIELD_2 => 'value', etc. },
        { FIELD_1 => 'value', FIELD_2 => 'value', etc. },
        { FIELD_1 => 'value', FIELD_2 => 'value', etc. },
        ...
    ]


TODO: Implement the use of the attribute 'field_headings' from the C<Test::XTracker::Artifacts::OutputFile::PlainText>
      class as an alternative if there are NO field headings in the first record of the file.

=head2 as_data_by_pkey

    $hash_ref   = $file->as_data_by_pkey( { force_array => 1 # optional, defaults to FALSE } );
            or
    $hash_ref   = $file->as_data_by_pkey( { use_field_as_pkey => 'ALTERNATIVE_PRIMARY_KEY' } );

This will use the 'primary_key' attribute (which is a field heading) from the C<Test::XTracker::Artifacts::OutputFile::PlainText> class to return the
data in a Hash Ref using the value of the Primary Key as the keys with the values being another
Hash Ref containing the data using the field headings as its keys. If there is more than one record in the file with the
same primary key then this value will be an Array Ref of Hash Refs. If the optional argument 'force_array' is set to TRUE
then all values will be an Array Ref even if there is only one record for the Primary Key.

If you want to use a different Primary Key to the one originally specified then use the 'use_field_as_pkey' argument but
this won't persist for future calls.

If NO Primary Key was set and 'use_field_as_pkey' is NOT passed then this method will return 'undef'.

    {
        12323213    => {
                    FIELD_1 => 'value',
                    FIELD_2 => 'value',
                    ...
                },
        23534552    => [
                {
                    FIELD_1 => 'value',
                    FIELD_2 => 'value',
                    ...
                },
                {
                    FIELD_1 => 'value',
                    FIELD_2 => 'value',
                    ...
                },
                ...
            ],
        ...
    }

=cut

sub as_rows {
    my $self    = shift;

    my @out;

    my @headings= $self->_heading_row;
    my $data    = $self->_data_rows;

    push @out, @headings    if ( @headings );
    push @out, @{ $data };

    return \@out;
}

sub headings {
    my ( $self )    = shift;

    my @headings    = $self->_heading_row;

    return ( wantarray ? @headings : \@headings );
}

sub as_rows_of_data {
    my $self    = shift;

    my @data    = @{ $self->_data_rows };
    my @headings= $self->_heading_row;

    my @out;
    foreach my $row ( @data ) {
        my $rec;
        foreach my $idx ( 0..$#{ $row } ) {
            $rec->{ $headings[ $idx ] || 'FIELD_' . ( $idx + 1 ) }   = $row->[ $idx ];
        }
        push @out, $rec;
    }

    return \@out;
}

sub as_data_by_pkey {
    my ( $self, $args )     = @_;

    my $pkey    = delete $args->{use_field_as_pkey} || $self->artifact->primary_key;
    return      if ( !$pkey );

    my $force_array = delete $args->{force_array};
    my @data        = @{ $self->as_rows_of_data };

    my %out;
    foreach my $row ( @data ) {
        if ( exists( $row->{ $pkey } ) ) {
            my $pkey_val    = $row->{ $pkey };

            if ( $out{ $pkey_val } || $force_array ) {
                if ( $out{ $pkey_val } && ref( $out{ $pkey_val } ) ne 'ARRAY' ) {
                    $out{ $pkey_val }   = [ $out{ $pkey_val } ];
                }
                push @{ $out{ $pkey_val } }, $row;
            }
            else {
                $out{ $pkey_val }   = $row;
            }
        }
    }

    return \%out;
}

sub _heading_row {
    my $self    = shift;

    return ()       if ( !$self->artifact->first_row_has_headings );

    my $headings    = ( $self->_splitup_records( $self->content ) )[0];

    return $self->_splitup_fields( $headings );
}

sub _data_rows {
    my $self    = shift;

    my @out;

    my @rows    = $self->_splitup_records( $self->content );
    shift @rows     if ( $self->artifact->first_row_has_headings );

    foreach my $row ( @rows ) {
        my @fields  = $self->_splitup_fields( $row );
        push @out, \@fields;
    }

    return \@out;
}

sub _splitup_fields {
    my ( $self, $str )  = @_;

    my $delim   = $self->artifact->field_delimiter;

    return split( qr/$delim/s, $str );
}

sub _splitup_records {
    my ( $self, $str )  = @_;

    my $delim   = $self->artifact->record_delimiter;

    return split( qr/$delim/s, $str );
}


1;
