package XT::Net::Seaview::Service;

use NAP::policy "tt", 'class';
use XTracker::Config::Local qw(config_var);

use XT::Net::Seaview::Exception::ParameterError;

=head1 NAME

XT::Net::Seaview::Service

=head1 DESCRIPTION

'Seaview' customer service

=head1 ATTRIBUTES

=head2 service_location

The location of our service

=cut

has service_url => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        return config_var('Seaview','service_url')
    },
);

=head1 METHODS

=head2 urn_lookup

Look up an entity location using a URN

=cut

sub urn_lookup {
    my ( $self, $urn ) = @_;

    XT::Net::Seaview::Exception::ParameterError->throw(
      { error => 'URN not supplied' }) unless defined $urn;

    # We use -1 here to ensure we get all the trailing parts as well.
    my @match_urn = split /:/, $urn, -1;
    my $templates = {
        'urn:nap:customer:<id>'             => "/customers/<id>",
        'urn:nap:account:<id>'              => "/accounts/<id>",
        'urn:nap:account:<id>:cardToken'    => "/accounts/<id>/cardToken",
        'urn:nap:account:<id>:bosh:<key>'   => "/bosh/account/<id>/<key>",
        'urn:nap:account:cardToken:<id>'    => "/accounts/<id>/cardToken",
        'urn:nap:address:<id>'              => "/addresses/<id>",
    };

    my @matches = _search_templates( \@match_urn, _translate_template( $templates ) );

    if ( @matches == 0 ) {
        die "[Error] Lookup failed for URN (no matches found): $urn";
    } elsif ( @matches == 1 ) {
        my $match = $matches[0]->[1];
        return $self->service_url . $match;
    } else {
        die "[Error] Lookup failed for URN (multiple matches found): $urn [" . join( ', ', @matches ) . "]";
    }

}

=head2 resource

Service resource locations because we don't yet have these in a
client-discoverable format

=cut

sub resource {
    my ($self, $resource_type) = @_;

    my $resources = {
        account_collection => '/accounts',
        address_collection => '/addresses',
    };

    unless( defined $resources->{$resource_type}){
        die 'Non-Existent Resource';
    }

    return $self->service_url
           . $resources->{$resource_type};
}

=head2 seaview_resource

Seaview-owned resources

=cut

sub seaview_resource {
    my ($self, $ref) = @_;
    my $sv_resource = undef;

    my @resources = qw( account customer address );
    my $res_str = join '|', @resources;
    my $re = qr/^urn:nap:($res_str)/;

    if( $ref =~ /$re/xms ){ $sv_resource = 1 }

    return $sv_resource;
}


=head1 PRIVATE METHODS

=head2 _translate_template( \%template )

Take a HashRef of URN to URL mappings and translates it into a data structure
that can be consumed by C<_search_templates>.

This returns an ArrayRef of ArrayRefs, where the first index is an ArrayRef
of the URN component parts, for example:

'urn:nap:account:xxx' -> [ qw( urn nap account xxx ) ]

The second index is the URL string (the value from the original HashRef, no
translation is done).

=cut

sub _translate_template {
    my ( $template ) = @_;

    return [
        map { [
            # We use -1 here to ensure we get
            # all the trailing parts as well.
            [ split( /:/, $_, -1 ) ],
            $template->{ $_ }
        ] }
        keys %$template
    ];

}

=head2 _search_templates( \@urn, \@template_data )

Takes a C<@urn> that has been split into component parts and some
C<@template_data>, as returned from C<_translate_template> and return an
Array of templates that match the URN.

The general idea is the following: Work your way through the component parts
of a URN, both in the URN we want to match and each URN in each template. If
the component matches (either exactly, or the component in the template is a
placeholder), either continue through the remaining parts of the match URN
(if there are any left), or return the matches found. Exact matches take
priority over placeholder matches. So basically, we match the URN part by
part, with the most precise matches winning.

=cut

sub _search_templates {
    my ( $urn, $template_data ) = @_;

    return () unless
        ref( $urn ) eq 'ARRAY' &&
        ref( $template_data ) eq 'ARRAY';

    my @match     = @$urn;
    my @templates = @$template_data;

    # Get the next part of the URN to match against.
    my $next_match = shift @match;

    my @exact_matches;
    my @placeholder_matches;

    foreach my $template ( @templates ) {

        if ( my $next_template = shift @{ $template->[0] } ) {
        # If there are any more URN components to match against for this template.

            # Add the template to the list of exact matches if both component
            # parts match exactly.
            push( @exact_matches, $template )
                if $next_template eq $next_match;

            # Add the template to the list of placeholder matches if the
            # template is a placeholder.
            if ( $next_template =~ /\A\<.+\>\Z/ ) {
                # Substitute the placeholder in the URL with the matching URN
                # part.
                $template->[1] =~ s/$next_template/$next_match/;
                push( @placeholder_matches, $template )
                    # A placeholder requires there to be something there that
                    # matched, as missing components do not consititute a
                    # match, i.e. placeholders are required.
                    if $next_match;
            }

        }

    }

    if ( @exact_matches ) {
    # Exact matches take priority, so if there are any of those, use them.

        # If there are any URN match components left to check.
        return @match
            # Carry on searching.
            ? _search_templates( \@match, \@exact_matches )
            # Otherwise return what we've found for templates that have no
            # more matches to check.
            : grep { scalar @{ $_->[0] } == 0 } @exact_matches;

    } elsif ( @placeholder_matches ) {
    # If there are no exact matches and some placeholder matches, then it's
    # OK to use them.

        # If there are any URN match components left to check.
        return @match
            # Carry on searching.
            ? _search_templates( \@match, \@placeholder_matches )
            # Otherwise return what we've found for templates that have no
            # more matches to check.
            : grep { scalar @{ $_->[0] } == 0 } @placeholder_matches;

    } else {

        return ();

    }

}

