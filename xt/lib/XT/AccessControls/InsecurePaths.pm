package XT::AccessControls::InsecurePaths;

use NAP::policy qw( exporter );
use Perl6::Export::Attrs;

=head1 NAME

XT::AccessControls::InsecurePaths

=head1 DESCRIPTION

Used to tell if a supplied 'path' is a permitted insecure path.

This uses the Config Section '<ACL>' and then within that the
settings in '<insecure_paths>'.

=cut

use XTracker::Config::Local             qw( acl_insecure_paths );


=head1 METHODS

=head2 permitted_insecure_path

    $boolean = permitted_insecure_path( 'Some/Path' );

Returns TRUE or FALSE based on whether the Supplied Path matches
one of the acceptable paths in the 'insecure_paths' part of the
'ACL' Config.

=cut

sub permitted_insecure_path : Export() {
    my $request_path = shift;

    die "permitted_insecure_path called without request_path" unless $request_path;

    # get the paths from the config
    my $paths = acl_insecure_paths() // [];

    foreach my $path ( @{ $paths } ) {
        if ( ( scalar caller() ) =~ qr{\APlack::Middleware} ) {
            # Prepend / onto path for Plack::Middleware
            $path = '/'.$path;
        }

        return 1 if $request_path =~ /\A$path/i;
    }

    return 0;
}

