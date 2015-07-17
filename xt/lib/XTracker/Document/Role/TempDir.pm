package XTracker::Document::Role::TempDir;

use NAP::policy 'role';

use File::Temp;
use XTracker::Config::Local qw(config_var);

=head1 NAME

XTracker::Document::Role::TempDir - Role to place created files in temp dir

=head1 SYNOPSIS

    package MyPackage;

    use NAP::policy 'class';

    with 'XTracker::Document::Role::TempDir';

=head1 DESCRIPTION

Add this role to a document class in order to remove the artifacts after
they've been created. You'll want to use this if we're not interested in
keeping a record of the document on hard disk.

Note that this will create the temporary files in the config value for
C<SystemPaths/document_temp_dir>, which should B<not> be a NFS-ed location, as
in such a location the directory does not get removed cleanly.

=cut

=head1 ATTRIBUTES

=head2 temp_dir : File::Temp::Dir

A temporary directory containing to place the created files.

=cut

has temp_dir => (
    is        => 'ro',
    isa       => 'File::Temp::Dir',
    builder   => '_build_temp_dir',
    init_arg  => undef,
    lazy      => 1,
    reader    => 'directory',
);
sub _build_temp_dir {
    my ( $self ) = @_;
    my $tmp = File::Temp->newdir(
        undef,
        CLEANUP => $self->cleanup,
        DIR => config_var(qw/SystemPaths document_temp_dir/),
    );
}

=head2 cleanup : Bool

Remove the temporary dir once the object falls out of scope. Default is true.

=cut

has cleanup => (
    is => 'ro',
    isa => 'Bool',
    builder => '_build_cleanup',
);
sub _build_cleanup { config_var(qw/Printing delete_temp_file/); }
