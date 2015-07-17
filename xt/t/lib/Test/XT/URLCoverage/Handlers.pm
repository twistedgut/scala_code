package Test::XT::URLCoverage::Handlers;

=head1 NAME

Test::XT::URLCoverage::Handlers - Map URLs to Handlers and Templates

=head1 DESCRIPTION

Search through the xt locations file to map URLs to Handlers, and occasionally
to templates

=head1 SYNOPSIS

 use Test::XT::URLCoverage::Handlers;

 my $obj = Test::XT::URLCoverage::Handlers->new();
 $obj->load();

 my $location = $obj->search('/URL/Goes/Here');
 print( 'Match: ' . $location->{'location'} );
 print( 'Class: ' . $location->{'handler'} );
 print( 'Path : ' . $location->{'lib_path'} );

 my @templates = $obj->templates( $location );

=cut

use strict;
use warnings;
use Moose;
use File::Slurp;
use PPI;
use Storable qw/dclone/;

has 'entries' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'cache'   => ( is => 'rw', isa => 'HashRef',  default => sub { {} } );

=head1 METHODS

=head2 load

Parses C<conf/xt_location.conf>. Also nukes the cache. You need to call this
before you do any searching.

=cut

sub load {
    my ( $self, $filename ) = @_;
    $self->cache({});

    my @locations;
    my $current_location;

    for my $line (read_file( $filename || 'conf/xt_location.conf' )) {

        # Opening line
        if ( $line =~ m/^<Location(.+)/ ) {
            my $specification = $1;

            my $is_regex   = $specification =~ s/^\s*\~\s*//;
            my ($location) = $specification =~ m/([^" >]+)/;

            $current_location = {
                is_regex => $is_regex || '0',
                location => $location
            };
        }

        # Closing line
        if ( $line =~ m!</Location>! ) {
            push(@locations, $current_location);
            undef $current_location;
        }

        # Save handler name
        if ( $line =~ m/PerlHandler .*?([\w:]+)\s*$/ ) {
            $current_location->{'handler'} = $1;
            my $lib_path = $current_location->{'handler'};
            $lib_path =~ s!::!/!g;
            $current_location->{'lib_path'} = 'lib/' . $lib_path . '.pm';
        }
    }

    $self->entries( \@locations );
}

=head2 search

See what we can find for a given URL. Returns a hashref containing:

 location <- the entry in the Locations file we matched on
 class    <- the implementing classname
 lib_path <- where that class is on the filesystem

=cut

sub search {
    my ( $self, $path ) = @_;

    # Cache-able
    return $self->cache->{'search'}->{ $path } if $self->cache->{ $path };

    for my $location ( reverse @{ $self->{'entries'} } ) {
        if (
            $location->{'is_regex'} ?
                $path =~ m/$location->{'location'}/ :
                $path =~ m/^$location->{'location'}/
        ) {
            $self->cache->{'search'}->{ $path } = dclone($location);
            return $location;
        }
    }
}

=head2 templates

Returns a list of template names from a filename, specified as the C<lib_path>
key of a hashref. This means you just pass in the result of C<search()>. As this
looks in the file itself for anything that looks like a template name, it can
return several results.

=cut

sub templates {
    my ( $self, $location ) = @_;
    my $handler = $location->{'lib_path'} || return;

    # Cache-able
    return @{ $self->cache->{'templates'}->{ $handler } }
        if $self->cache->{'templates'}->{ $handler };

    # Turn the handler we found into a PPI doc
    my $ppi = PPI::Document->new( $handler );
    my $sub_nodes = $ppi->find('PPI::Token::Quote');

    my @found;

    my $default_base = 'root/base/';
    for my $node ( @$sub_nodes ) {
        if ($node->string =~ m/.*\/.*[a-z]+\.(tt|inc)$/i) {
            if ( -f ($default_base . 'stocktracker/' . $node->string)) {
                push( @found, $default_base . 'stocktracker/' . $node->string );
            }
            else {
                push( @found, $default_base . $node->string );
            }
        }
    }

    $self->cache->{'templates'}->{ $handler } = dclone( \@found );

    return @found;
}

1;
