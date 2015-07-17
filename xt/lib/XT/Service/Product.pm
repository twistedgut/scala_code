package XT::Service::Product;

=head1 NAME

XT::Service::Product

=head1 SYNOPSIS

    my $product_service = XT::Service::Product->new( channel => $channel );

    my $docs = $product_service->search_and_fetch(
        business_name => 'NAP',
        live_or_staging => 'live',
        condition => { name_en => 'Leather coat', channel_id => 1, visible => 'true' },
        field_list => [ qw{ score channel_id product_id name_en description_en } ]
    );

=head1 DESCRIPTION

This class provides an abstraction class to the APIs for the Product Service.

The class requires a channel parameter which must be a DBIC Channel object.

Currently there is only one API to the Product Service via Solr so this just
implements that. Once the new shiny Product Service native API is avaialble
this module should be able to implement that without any interface changes
elsewhere within XT.

=cut

use NAP::policy "tt", 'class';
use XTracker::Config::Local qw( config_var );
use XTracker::Logfile;
use XTracker::Utilities     qw( :string );

extends 'NAP::Service::Product::Solr';

has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    required    => 1,
);

has log => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    lazy_build  => 1,
);

sub _build_log {
    my $self = shift;
    require XTracker::Logfile;
    return XTracker::Logfile::xt_logger( 'Solr_Client' );
}

has 'default_language' => (
    is          => 'ro',
    isa         => 'Str',
    lazy_build  => 1,
);

=head2 _build_default_language

Retrieves the default language setting from the configuration.

=cut

sub _build_default_language {
    my $self = shift;

    return config_var('Customer', 'default_language_preference');
}

=head2 solr_url

Attribute specifying the URL of the Product Service Solr instance

=cut

has 'solr_url' => (
    is          => 'ro',
    isa         => 'Str',
    lazy_build  => 1,
);

sub _build_solr_url {
    my $self = shift;

    return config_var( 'Solr_'.$self->channel->business->config_section,
                               'product_service_url' );
}

=head2 _build_config_sections

Wraps the superclass's method to add its own class name to the config search
path.

=cut

sub _build_config_sections {
    my ($self) = @_;

    $self->config->{url} = $self->solr_url;

    return [ __PACKAGE__, @{ $self->SUPER::_build_config_sections } ];
}

=head2 localise_product_data_hash

    $product_service->localise_product_data_hash(
        channel => $channel_object,
        data => $hashref_of_items,
        language => $two_letter_language_code
    );

Takes a hashref of items containing product data (typically shipping items
or invoice items), a channel and a language and tries to obtain localised data
for those items. The items are expected to be named one of shipping_item,
shipping_items, invoice_items or product_items and must contain at least the
following fields:

    product_id
    name

This method will attempt to localise all fields passed in so be aware that
if there is a matching field in the Product Service with a translation
for the language data will be replaced with the translation.

=cut

sub localise_product_data_hash {
    my ( $self, $args ) = @_;

    unless ( exists $args->{channel}
             && $args->{channel}->isa('XTracker::Schema::Result::Public::Channel') ) {
        $self->log->warn('localise_product_data_hash called without DBIC Channel');
        return $args;
    }

    unless ( exists $args->{language} && defined $args->{language} ) {
        $self->log->warn('localise_product_data_hash called without language');
        return $args;
    }

    unless ( exists $args->{data} && ref $args->{data} eq 'HASH' ) {
        $self->log->warn('localise_product_data_hash called without data');
        return $args;
    }

    my $data = $args->{data};

    # Do we support the use of Product Service for this channel?
    unless ( $args->{channel}->can_access_product_service ) {
        return $data;
    }

    if ( $self->default_language eq $args->{language} ) {
         return $data
            unless $args->{channel}->can_access_product_service_for_default_language;
    }

    my @item_lists = ( qw( shipment_item
                           shipment_items
                           invoice_items
                           reservations
                           product_items
                         ) );

    my $recurse;
    $recurse = sub {
        my $input = shift;

        if ( ref $input eq 'HASH' ) {
            foreach my $key ( @item_lists ) {
                 if ( exists $input->{$key} ) {
                     $input->{$key} = $self->_localise_product_data(
                                            $input->{$key},
                                            $args->{language},
                                            $args->{channel},
                                            );
                 }
            }
            return $input;
        }
        if ( ref $input eq 'ARRAY' ) {
            foreach my $element ( @$input ) {
                return $recurse->( $element );
            }
        }
        return $input;
    };

    $recurse->( $data );

    return $data;
}

sub _localise_product_data {
    my ( $self, $items, $language, $channel ) = @_;

    my @translate_fields;   # Which fields we will translate
    my %original_fields;    # So we can map those fields back to the source

    # Compile a list of all PIDs in data so we only call PS once
    my %pids;

    # Iterate over the data grabbing all the PIDs and list of fields
    while ( my ( $item, $data ) = each %$items ) {
        # We only localise products with a PID
        next unless exists $data->{product_id};

        $pids{$data->{product_id}} = 1;

        # We do not know which fields may have translation data available
        # so try to localise all of them.
        foreach my $field ( keys %$data ) {
            if ( $field eq 'product_name' ) {
                push @translate_fields, 'name_'.lc $language;
                push @{$original_fields{'name_' . lc $language}}, $field;
            }
            else {
                push @translate_fields, $field . '_' . lc $language;
                push @{$original_fields{$field . '_' . lc $language}}, $field;
            }
        }
        # We specify the minimum fields required. Note that name_en is correct
        # as product service localises English as well as other languages.
        push @translate_fields, ( qw(channel_id product_id name_en) );
    }

    # Now we try and get the data from Product Service
    local $@;
    my $docs;
    eval {
        $docs = $self->fetch(
            url => $self->solr_url,
            business_name => $channel->business->config_section,
            key_fields => [ qw( product_id channel_id ) ],
            keys => [ map { [ $_, $channel->id ] } ( keys %pids ) ],
            field_list => [ @translate_fields ],
        );
    };
    if ( my $err = $@ ) {
        $self->log->warn("Solr Request Died: $err");
    }

    # If we don't get anything back from Product Service just return $items as is
    return $items unless $docs;

    my %product_service_data;
    # Process the returned docs building a hash of returned data per pid
    foreach my $result ( @$docs ) {
        # Ensure that we only process records for the current channel
        next unless $result->{channel_id} == $channel->id;

        $product_service_data{$result->{product_id}} = $result;
    };

    # Go through the items again this time replacing localised data
    while ( my ( $item, $data ) = each %$items ) {
        next unless exists $data->{product_id};

        # Do nothing if we don't have PS data for this product
        next unless exists $product_service_data{$data->{product_id}};

        # Replace any data for which we have a translation from Product Service
        foreach my $field ( @translate_fields ) {
            # Ensure that the data exists and actually contains something
            next unless exists $product_service_data{$data->{product_id}}->{$field}
                && trim($product_service_data{$data->{product_id}}->{$field});

            # also make sure we intend to replace this data
            foreach my $original (@{$original_fields{$field}}) {
                $items->{$item}->{$original} = $product_service_data{$data->{product_id}}->{$field};
            }
        }
    }
    return $items;
}

=head2 get_some_products

    $products = $product_service->get_some_products(
        how_many    => 3,
        channel     => $channel_object,
        name        => $name_to_match_in_english
    );

Returns data about some products.

Parameters:

    Required:
        how_many    (Integer) How many products to return data for
        channel     (Channel DBIC Object) Channel to get products for

    Optional:
        name        (String) text to match in name_en field

Returns:

    Hashref in the form:

    $data->{
        1   => {
            product_id  => 12345,
            name_en     => 'Some text here',
            ...
        },
        2   => {
            product_id  => 12345,
            name_en     => 'Some text here',
            ...
        },
        ...
    }

=cut

sub get_some_products {
    my ( $self, $args ) = @_;

    return unless $args->{how_many} && $args->{channel}
        && $args->{channel}->isa('XTracker::Schema::Result::Public::Channel');

    my $channel = $args->{channel};

    my $condition = {
        channel_id => $channel->id,
        visible => 'true',
    };
    foreach my $field ( qw( name product_id ) ) {
        $condition->{$field} = $args->{$field} if exists $args->{$field};
    }

    # Now we try and get the data from Product Service
    local $@;
    my $docs;
    eval {
        $docs = $self->search_and_fetch(
            url => $self->solr_url,
            business_name => $channel->business->config_section,
            condition => $condition,
            max_results => $args->{how_many},
        );
    };
    if ( my $err = $@ ) {
        $self->log->warn("Solr Request Died: $err");
        return;
    }

    my $return;
    my $count = 1;
    foreach my $product ( @$docs ) {
        $return->{$count} = $product;
        $count++;
    }

    return $return;
}
1;
