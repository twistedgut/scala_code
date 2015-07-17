package XTracker::Document::Role::TempFile;

use NAP::policy 'role';

use File::Temp;

=head1 NAME

XTracker::Document::Role::TempFile - Role to add temp file creation

=head1 SYNOPSIS

package MyPackage;

use NAP::policy 'class';

with 'XTracker::Document::Role::TempFile';

=head1 DESCRIPTION

Sometimes we aren't interested in the files we want to print to persist, this
role allows us to create a temporary file to pass to the C<lp> command that is
deleted when the object falls out of scope by default.

=cut

=head1 REQUIRED METHODS

=head2 content

We require a content method to populate the temporary file.

=cut

requires 'content';

=head1 ATTRIBUTES

=head2 temp_file : File::Temp

Builds a temporary file containing C<content>.

=cut

has temp_file => (
    is => 'ro',
    isa => 'File::Temp',
    builder => '_build_temp_file',
    init_arg => undef,
    lazy => 1,
    handles => ['filename'],
);

sub _build_temp_file {
    my ( $self ) = @_;

    my $fh = File::Temp->new(UNLINK => $self->remove_temp_file);
    binmode $fh;
    print $fh $self->content;
    close $fh;

    return $fh;
}

=head2 remove_temp_file : Bool

Remove the temporary file once the object falls out of scope. Default is true.

=cut

has remove_temp_file => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);
