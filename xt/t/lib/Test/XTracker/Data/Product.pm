package Test::XTracker::Data::Product;
use NAP::policy "tt", 'class';

with 'XTracker::Role::WithSchema';

use MooseX::Params::Validate;
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw/
    :currency
    :season
/;

sub create_product {
    my $self = shift;

    my $product_id = Test::XTracker::Data->next_id([qw{voucher.product product}]);

    my ($world_id, $designer_id, $division_id, $classification_id, $product_type_id,
        $sub_type_id, $colour_id, $style_number, $season_id, $hs_code_id, $colour_filter_id,
        $product_attributes, $shipping_attributes, $product_channel) = validated_list(\@_,

        world_id    => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::World')->first()->id()
        },
        designer_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::Designer')->first()->id()
        },
        division_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::Division')->first()->id()
        },
        classification_id   => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::Classification')->first()->id()
        },
        product_type_id     => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::ProductType')->first()->id()
        },
        sub_type_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::SubType')->first()->id()
        },
        colour_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::Colour')->first()->id()
        },
        style_number => { isa => 'Str', optional => 1,
            default => "STYNUM$product_id",
        },
        season_id => { isa => 'Int', optional => 1,
            default => $SEASON__CONTINUITY,
        },
        hs_code_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::HSCode')->first()->id(),
        },
        colour_filter_id => { isa => 'Int', optional => 1,
            default => $self->schema->resultset('Public::ColourFilter')->first()->id(),
        },
        product_attributes => { isa => 'HashRef', optional => 1, default => {} },
        shipping_attributes => { isa => 'HashRef', optional => 1, default => {} },
        product_channel => { isa => 'HashRef', optional => 1, default => {} },
    );

    # Create the product
    my $product_row = $self->schema->resultset('Public::Product')->create({
        id                      => $product_id,
        world_id                => $world_id,
        designer_id             => $designer_id,
        division_id             => $division_id,
        classification_id       => $classification_id,
        product_type_id         => $product_type_id,
        sub_type_id             => $sub_type_id,
        colour_id               => $colour_id,
        style_number            => $style_number,
        season_id               => $season_id,
        hs_code_id              => $hs_code_id,
        colour_filter_id        => $colour_filter_id,
    });

    # Create the product_attribute
    $self->add_product_attributes({
        product => $product_row,
        %$product_attributes,
    });

    # Create shipping_attribute
    $self->add_shipping_attributes({
        product => $product_row,
        %$shipping_attributes,
    });

    # Create product_channel
    $self->add_product_channel({
        product => $product_row,
        %$product_channel,
    });

    return $product_row;
}

sub add_product_attributes {
    my ($self, $product, $description, $designer_colour) = validated_list(\@_,
        product     => { isa => 'XTracker::Schema::Result::Public::Product' },
        description => { isa => 'Str', optional => 1, default => 'blah, blah, blah' },
        designer_colour => { isa => 'Str', optional => 1, default => 'Waterloo Sunset' },
    );

    # TODO: Flesh out as required
    return $product->create_related('product_attribute', {
        description     => $description,
        designer_colour => $designer_colour,
    });
}

sub add_shipping_attributes {
    my ($self, $product) = validated_list(\@_,
        product     => { isa => 'XTracker::Schema::Result::Public::Product' },
    );

    # TODO: Flesh out as required
    return $product->create_related('shipping_attribute', {});
}

sub add_product_channel {
    my $self = shift;
    my ($product, $channel) = validated_list(\@_,
        product     => { isa => 'XTracker::Schema::Result::Public::Product' },
        channel     => { isa => 'XTracker::Schema::Result::Public::Channel', optional => 1,
            # Default to an enabled channel that is not 3rd party
            default => $self->schema->resultset('Public::Channel')
                ->fulfilment_only(0)->enabled_channels()->first(),
        },
    );

    # TODO: Flesh out as required
    return $product->create_related('product_channel', {
        channel_id  => $channel->id(),
    });
}

sub get_non_existant_product_id {
    my ($self) = @_;
    return Test::XTracker::Data->next_id([qw{voucher.product product}]);
}

1;
