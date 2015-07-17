package XT::Service::Designer;
use NAP::policy qw( class tt );

=head1 NAME

XT::Service::Designer

=head1 SYNOPSIS

    use XT::Service::Designer;

    my $channel  = $schema
        ->resultset('Public::Channel')
        ->find( 1 );

    my $designer = $schema
        ->resultset('Public::Designer')
        ->find( { designer => 'Chantecaille' } );

    my $service = XT::Service::Designer->new(
        channel => $channel,
        dataset => 'live',
    );

    my $results = $service->search( id => $designer->id );

    foreach my $result ( @$results ) {
        print 'English Name: ' . $result->{name_en};
    }

=head1 DESCRIPTION

Provides an interface to the Product Designer service, by implementing an XT
based wrapper around L<NAP::Service::Designer::Solr>.

Connection information is stored in the following configuration keys:

    Solr_NAP    -> designer_service_url
    Solr_OUTNET -> designer_service_url
    Solr_MRP    -> designer_service_url
    Solr_JC     -> designer_service_url

At present, there is no difference between I<live> and I<staging>, they both
point to whatever the configuration above returns.

=cut

use Carp;
use Moose::Util::TypeConstraints;
use List::MoreUtils qw(
    uniq
);

use NAP::Service::Designer::Solr;

use XTracker::Logfile;
use XTracker::Config::Local qw(
    config_var
);

=head1 ATTRIBUTES

=head2 channel

A required attribute that must contain an
L<XTracker::Schema::Result::Public::Channel> object.

=cut

has channel => (
    is       => 'rw',
    isa      => 'XTracker::Schema::Result::Public::Channel',
    required => 1,
);

=head2 dataset

An optional attribute that must be a string value of either I<live> or
I<staging> and defaults to 'live' if it's not specified.

As mentioned in the B<DESCRIPTION> section, this attribute will currently not
change the results that will be returned, as both I<live> and I<staging> are the
same thing, so do not use this for now.

=cut

has dataset => (
    is       => 'rw',
    isa      => enum( [ 'live', 'staging' ] ),
    default  => 'live',
);

=head2 service

A read-only attribute that contains the L<NAP::Service::Designer::Solr>
object used to implement the underlying functionality.

=cut

has service => (
    is      => 'ro',
    isa     => 'NAP::Service::Designer::Solr',
    builder => '_build_service',
    lazy    => 1,
);

sub _build_service {
    my $self = shift;

    my $config_section = $self->channel->business->config_section;
    my $config_value   = config_var( "Solr_$config_section", 'designer_service_url' );

    croak  __PACKAGE__ . "::_build_service - Configuration [Solr_$config_section -> designer_service_url] not set"
        unless $config_value;

    # The Designer Service client expects the config in a specific format, so
    # we transform our config to match this.
    return NAP::Service::Designer::Solr->new(
        config => {
            'NAP::Service::Solr' => {
                Designer => {
                    $config_section => {
                        # If we add a new dataset here, we must update the
                        # dataset attribute enum.
                        live    => $config_value,
                        staging => $config_value,
                    },
                },
            },
        }
    );

}

=head2 log

A read-only attribute that contains a L<Log::Log4perl::Logger> object, that
uses the category 'Solr_Client'.

=cut

has log => (
    is      => 'ro',
    isa     => 'Log::Log4perl::Logger',
    default => sub { XTracker::Logfile::xt_logger( 'Solr_Client' ) },
);

=head1 METHODS

=head2 search( $key, $value, \%override )

Search for all documents in the service where the C<$key> exactly matches
C<$value>.

Internally, calls the C<fetch> method on the C<service> object, passing C<$key>
into C<key_fields> and C<$value> into C<keys>. All the other required keys are
set using the object attributes.

You can pass any arbritray keys directly into the C<fetch> method via the
C<%override> parameter.

Returns whatever C<fetch> returns, it should be an ArrayRef of HashRefs.

    # Execute a default search.
    my $result = $service->search( id => $designer->id );

    # .. or ..

    # Only return the single field 'name_en'.
    my $result = $service->search( id => $designer->id, { field_list => [ 'name_en' ]  } );

    foreach my $result ( @$results ) {
        print 'English Name: ' . $result->{name_en};
    }

=cut

sub search {
    my ( $self, $key, $value, $override ) = @_;

    $override //= {};

    croak __PACKAGE__ . "::search  - <key> parameter must not be empty"
        unless defined $key && $key ne '';

    croak __PACKAGE__ . "::search  - <value> parameter is required"
        unless defined $value;

    croak __PACKAGE__ . "::search  - <override> parameter must be a hash"
        unless ref( $override ) eq 'HASH';

    return try {

        return $self->service->fetch(
            business_name    => $self->channel->business->config_section,
            live_or_staging  => $self->dataset,
            key_fields       => [ $key ],
            keys             => [ $value ],
            condition        => { channel_id => $self->channel->id },
            # Allow any field to be overidden if required.
            %$override,
        );

    }

    catch {

        my $error = __PACKAGE__ . "::search - fetch failed due to error: $_";

        $self->log->fatal( $error );
        croak $error;

    };

}

=head2 get_restricted_countries_by_designer_id( $designer_id )

Get a list of all the restricted countries for a particular designer C<$designer_id>.

Returns an ArrayRef of ISO-3166 country codes.

    my $codes = $service->get_restricted_countries_by_designer_id( $designer->id );

    foreach my $code ( @$codes ) {
        print 'Country Code: ' . $code;
    }

=cut

sub get_restricted_countries_by_designer_id {
    my ( $self, $designer_id ) = @_;

    croak __PACKAGE__ . "::get_restricted_countries_by_designer_id - <id> parameter must be numeric"
        unless ( $designer_id // '' ) =~ /\A\d+\Z/;

    my @result;

    # Only request a single field, by also passing field_list.
    my $designers = $self->search( 'id', $designer_id, { field_list => [ 'restricted_countries' ] } );

    if ( ref( $designers ) eq 'ARRAY' ) {

        foreach my $designer ( @$designers ) {

            if (
                ref( $designer ) eq 'HASH' &&
                ref( $designer->{restricted_countries} ) eq 'ARRAY'
            ) {

                push @result, @{ $designer->{restricted_countries} };

            }

        }

    }

    # Because the service makes documents unique using language, channel and
    # designer, we can potentially get back a document for each language (as
    # we've already filtered by channel and designer). In order to get around
    # this 'feature', we only return a unique set of country codes.
    return [ uniq @result ];

}
