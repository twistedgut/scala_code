package XT::JQ::DC::Receive::Product::Update;
use Moose;

extends 'XT::JQ::Worker';

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw(Bool Str Int Num ArrayRef HashRef Maybe);
use MooseX::Types::Structured qw(Dict Optional);
use MooseX::Types -declare => ['Price','Weight','Percentage'];
use XTracker::Database::Product::JQUpdate;

use namespace::clean -except => 'meta';

subtype Price,
  as Num,
  where { $_ > 0 },
  message { "Prices must be greater than 0" };

subtype Percentage,
    as Num,
    where { $_ >= 0 && $_ <= 100 },
    message { "Percentages must be 0 to 100 inclusive" };

subtype Weight,
    as Num,
    where { $_ > 0 },
    message { "Weight must be greater than 0" };


has payload => (
    is  => 'rw',
    isa => ArrayRef[
        Dict[
            product_id  => Int,
            operator_id => Optional[Int],

            ### Details
            designer_colour_code => Optional[Str],
            designer_colour      => Optional[Str],
            fish_wildlife_source => Optional[enum(['', 'Farmed', 'Wild'])],
            dangerous_goods_note => Optional[Str],
            hs_code              => Optional[Int],
            manufacturer_id      => Optional[Str],
            packing_note         => Optional[Str],
            restriction          => Optional[
                Dict[
                    add    => Optional[ArrayRef[Str]],
                    remove => Optional[ArrayRef[Str]],
                ],
            ],
            restriction_code     => Optional[
                Dict[
                    add    => Optional[ArrayRef[Str]],
                    remove => Optional[ArrayRef[Str]],
                ],
            ],
            scientific_term      => Optional[Str],
            style_number         => Optional[Str],
            weight_kgs           => Optional[Weight],
            fabric_content       => Optional[Str],
            canonical_product_id => Optional[Maybe[Int]],

            ### Classification
            classification     => Optional[Str],
            colour             => Optional[Str],
            designer           => Optional[Str],
            division           => Optional[enum([qw/Women Men Girls Boys/])],
            product_department => Optional[Str],
            product_type       => Optional[Str],
            season_act         => Optional[enum([qw/Main Pre-Collection Unknown/])],
            season             => Optional[Str],
            sub_type           => Optional[Str],
            world              => Optional[Str],

            ### Editorial
            description     => Optional[Str],
            editorial_notes => Optional[Str],
            fit_notes       => Optional[Str],
            name            => Optional[Str],
            style_notes     => Optional[Str],
            use_fit_notes   => Optional[Bool],

            channel => Optional[
                ArrayRef[
                    Dict[
                        channel_id => Int,

                        ### Shipping Attribute
                        origin_country_id  => Optional[Int],

                        ### Editorial
                        editorial_approved  => Optional[Bool],
                        editors_comments    => Optional[Str],
                        keywords            => Optional[Str],
                        long_description    => Optional[Str],
                        outfit_links        => Optional[Bool],
                        size_fit            => Optional[Str],
                        size_fit_delta      => Optional[Int],
                        related_facts       => Optional[Str],
                        sub_editor_approved => Optional[Bool],
                        pre_order           => Optional[Bool],

                        ### Visibility
                        visible            => Optional[Bool],
                        disableupdate      => Optional[Bool],
                        pws_sort_adjust_id => Optional[Int],

                        ### Hierarchy attributes
                        hierarchy        => Optional[ArrayRef[Str]],

                        ### Pricing
                        exchange_rate    => Optional[enum(['Product Season', 'Upload Season'])],
                        pricing_complete => Optional[Bool],
                        pricing          => Optional[
                            ArrayRef[
                                Dict[
                                    action       => enum([qw/update delete insert/]),
                                    currency     => enum([qw/UNK GBP USD EUR AUD HKD JPY CNY KRW/]),
                                    price        => Num,
                                    price_type   => enum([qw/default country region/]),
                                    region_id    => Optional[Int],
                                    country_code => Optional[Str],
                                ],
                            ],
                        ],

                        # DSC-1000 - margins/landing proce
                        landing_price    => Optional[
                            Dict[
                                payment_term_id             => Int,
                                payment_deposit             => Percentage,
                                payment_settlement_discount => Percentage,

                                original_wholesale          => Price,
                                trade_discount              => Percentage,
                                uplift                      => Percentage,
                                unit_landed_cost            => Price,
                                currency_id                 => Int,
                            ],
                        ],

                        ### Navigation
                        navigation_classification => Optional[Maybe[Str]],
                        navigation_product_type   => Optional[Maybe[Str]],
                        navigation_sub_type       => Optional[Maybe[Str]],

                    ],
                ],
            ],
        ],
    ],
    required => 1,
);

has 'updater' => (
    is => 'ro',
    isa => 'XTracker::Database::Product::JQUpdate',
    lazy => 1,
    default => sub {
        my ($self) = @_;
        return XTracker::Database::Product::JQUpdate->new(
            dbh     => $self->dbh(),
            schema  => $self->schema(),
        );
    },
);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub do_the_task {
    my ($self, $job) = @_;
    return $self->updater->update_product($self->payload());
}

sub check_job_payload {
    my ($self, $job) = @_;

    my $payload = $self->payload;
    foreach my $record ( @$payload ) {
        my $channels = $record->{channel};
        foreach my $channel (@$channels){
            # fail job if got one but not all navigation category
            # TODO - extend to test if the category is valid too!
            if (
                    (exists $channel->{navigation_classification} or
                     exists $channel->{navigation_product_type} or
                     exists $channel->{navigation_sub_type})
                    and
                    (not exists $channel->{navigation_classification} or
                     not exists $channel->{navigation_product_type} or
                     not exists $channel->{navigation_sub_type})
                ){
                die 'Incomplete navigation category definition';
            }

            if (
                exists($channel->{restriction})
                && exists($channel->{restriction_code})
                ) {
                die 'restriction and restriction_code can not be both defined. Just use restriction_code.';
            }

        }
    }

    return ();
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::Update - Notification of changes to product data from
Fulcrum to DC

=head1 DESCRIPTION

Data within payload crosses over multiple tables in XT so payload fields are mapped into
relevant DC groupings depending on what update function to call before any updates are performed.

After updating locally we also need to work out if a web update is required based on the fields
changed and the live status of the products 'active' channel.
