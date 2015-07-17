package Test::NAP::NAPEvents::InTheBox;

=head1 NAME

Test::NAP::NAPEvents::WelcomePacks - Test 'In the Box Marketing' Promotion functionality

=head1 DESCRIPTION

Test 'In the Box Marketing' Promotion functionality.

#TAGS misc promotion loops shouldbecando

=head1 METHODS

=cut

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Data::Designer;
use Test::XTracker::Data::MarketingCustomerSegment;

use DateTime;
use Clone       qw( clone );

use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :country
                                            :department
                                            :promotion_class
                                        );


sub startup : Tests( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    my $framework = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::NAPEvents::IntheBox',
        ],
    );

    $framework->login_with_permissions({
        dept => 'Marketing',
        perms => { $AUTHORISATION_LEVEL__OPERATOR => [
            'NAP Events/In The Box',
        ]},

    });

    $self->{framework}  = $framework;

    my $now             = DateTime->now();
    $self->{past}       = $now - DateTime::Duration->new( days => 2 );
    $self->{future}     = $now + DateTime::Duration->new( days => 2 );
    $self->{now}        = $now;
}


=head2 test_inthebox_basic_functionality

Test Basic functionality of Creating an 'In The Box' Promotion.

    1) Create Promotion
    2) Check Summary page has newly created promotion listed
    3) Check that the promotion is weighted/weightless
    4) Edit promotion
    5) Check Records got updated
    6) Disable promotion
    7) Enable it again
    8) Check for failure when creating a duplicate Promotion
    9) If it's weighted, make sure that changing it to weightless removes
       the associated Promotion Type row

=cut

sub test_inthebox_basic_functionality : Tests {
    my $self    = shift;

    my $schema      = $self->schema;
    my $framework   = $self->framework;

    note "TESTING Create/Edit/Disable/Enable In the box marketing promotion";

    my $channel    = Test::XTracker::Data->channel_for_business(name=>'nap');
    my $now        = $self->{now};
    my $past       = $self->{past};
    my $future     = $self->{future};

    my %tests = (
        'Weighted Promotion' => {
            weighted => 1,
            title    => 'Weighted Dummy promotion' . $$,
        },
        'Weightless Promotion' => {
            weighted => 0,
            title    => 'Weightless Dummy promotion' . $$,
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        my $promotion_hash = {
            channel_id          => $channel->id,
            title               => $test->{title},
            promotion_start     => $now,
            promotion_end       => $now,
            send_once           => 1,
            message             => 'Marketing Promotions - please add promotion pack',
            $test->{weighted} ? (
                is_weighted         => 1,
                weighted_invoice    => 'Test Message',
                weighted_weight     => 0.5,
                weighted_fabric     => 'Test Fabric',
                weighted_country    => $schema->resultset('Public::Country')->first->country,
                weighted_hscode     => $schema->resultset('Public::HSCode')->first->hs_code,
            ) : (
                is_weighted         => 0,
            ),
        };

        # 1) Create Promotion
        $framework->flow_mech__inthebox_summary
                  ->flow_mech__inthebox__create_link
                  ->flow_mech__inthebox__create_promotion_submit( $promotion_hash );

        # -- Get the promotion record.
        my $promotions_row = $schema->resultset('Public::MarketingPromotion')->search({},
                                { order_by   => 'me.id DESC'}
                            )->first;

        # 2) Check Summary page has newly created promotion listed
        my $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};

        my $promotion_id = $promotions_row->id;
        my ( $result ) = grep { $_->{'Promotion Title'}->{value} eq  $test->{title} &&
                        $_->{'Promotion Title'}->{url}   =~ /promotion_id=$promotion_id\&/
                     }
                     @{ $page_data->{'Active Promotion List'} };

        ok( defined $result, "Promotion is Listed in Active Promotion list" );

        # 3) Check that the promotion is weighted/weightless.
        if ( $test->{'weighted'} ) {

            is( $result->{'Weighted'}, 'Yes', 'Promotion is weighted' );
            ok( defined $promotions_row->promotion_type, 'Promotion has a Promotion Type' );
            is( $promotions_row->promotion_type->promotion_class_id, $PROMOTION_CLASS__IN_THE_BOX, 'Promotion Type is class "In The Box"' );

        } else {

            is( $result->{'Weighted'}, 'No', 'Promotion is weightless' );
            ok( !defined $promotions_row->promotion_type, 'Promotion has no Promotion Type' );

        }

        # 4) Edit promotion

        $framework->flow_mech__inthebox_summary
               ->flow_mech__inthebox__edit_promotion_link({
                    promotion_id    => $promotion_id,})
               ->flow_mech__inthebox__edit_form_promotion_submit({
                   title  => "Edited-".$test->{title},
                   promotion_start =>  $past,
                   promotion_end   =>  $future,
                   $test->{'weighted'} ? (
                       weighted_invoice => 'New Value'
                   ) : (),
                });

        # 5) Check Records got updated
        $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};
        my ($record) = grep { $_->{'Promotion Title'}->{value} eq  "Edited-$test->{title}" &&
                          $_->{'Promotion Title'}->{url}   =~ /promotion_id=$promotion_id\&/
                        }
                  @{ $page_data->{'Active Promotion List'} };

        my $expected = {
        title   => "Edited-$test->{title}",
        start_date => $past->dmy,
        end_date => $future->dmy,
        };

        my $got = {
        title => $record->{'Promotion Title'}->{value},
        start_date => $record->{'Start Date'},
        end_date  =>$record->{'End Date'},
        };

        is_deeply($got, $expected, 'All the records were Edited Successfully');

        is( $promotions_row->discard_changes->promotion_type->product_type, 'New Value', 'Weighted value updated OK' )
            if $test->{'weighted'};

        # 6) Disable promotion

        $framework->flow_mech__inthebox_summary
              ->flow_mech__inthebox__enable_disable_promotion_submit({
                promotion_id    => $promotion_id,});

        $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};
        ( $result ) = grep { $_->{'Promotion Title'}->{value} eq  "Edited-$test->{title}" &&
                        $_->{'Promotion Title'}->{url}   =~ /promotion_id=$promotion_id\&/
                      }
                  @{ $page_data->{'Disabled Promotion List'} };

        ok( defined $result, "Promotion is in Disabled Promotion List");

        # 7) Enable it again
        $framework->flow_mech__inthebox_summary
              ->flow_mech__inthebox__enable_disable_promotion_submit({
                promotion_id    => $promotion_id,});

        $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};
        ( $result ) = grep { $_->{'Promotion Title'}->{value} eq  "Edited-$test->{title}" &&
                        $_->{'Promotion Title'}->{url}   =~ /promotion_id=$promotion_id\&/
                      }
                  @{ $page_data->{'Active Promotion List'} };
        ok( defined $result, "Promotion is in Again the Active List ");


        # 8) Check for failure when creating a duplicate Promotion.
        $framework->mech->errors_are_fatal( 0 );

        $framework->flow_mech__inthebox_summary
                  ->flow_mech__inthebox__create_link
                  ->flow_mech__inthebox__create_promotion_submit( { %$promotion_hash, title => "Edited-" . $test->{title} } );

        $framework->mech->has_feedback_error_ok( "The Marketing Promotion 'Edited-$test->{title}' already exists.", 'Cannot create a duplicate Promotion' );

        $framework->mech->errors_are_fatal( 1 );

        # 9) If it's weighted, make sure that changing it to weightless removes
        # the associated Promotion Type row.

        if ( $test->{'weighted'} ) {

            $framework->flow_mech__inthebox_summary
                ->flow_mech__inthebox__edit_promotion_link( {
                    promotion_id => $promotion_id,
                } )
                ->flow_mech__inthebox__edit_form_promotion_submit( {
                    is_weighted => 0,
                } );

            ok( !defined $promotions_row->discard_changes->promotion_type, 'Promotion Type row removed when changing to a weightless Promotion' );

        }

    }
}

=head2 test_assigning_options_to_promotion

Test Assigning Options such as Designers, Shipping Countries etc. to a Promotion.

=cut

sub test_assigning_options_to_promotion : Tests {
    my $self    = shift;

    my $channel = Test::XTracker::Data->any_channel;

    # get some test data to use
    my @designers   = Test::XTracker::Data::Designer->grab_designers( {
        how_many    => 3,
        channel     => $channel,
        want_dbic_recs => 1,
    } );
    my @customer_segments = Test::XTracker::Data::MarketingCustomerSegment->create_customer_segment( {
        how_many    => 3,
        channel_id  => $channel->id,
    } );
    my @countries   = $self->rs('Public::Country')->search( {
        id  => { '!=' => $COUNTRY__UNKNOWN },       # exclude 'Unknown'
    } )->all;
    my @languages     = $self->rs('Public::Language')->all;
    my @product_types = $self->rs('Public::ProductType')->search( {
        id  => { '!=' => 0 },       # exclude 'Unknown'
    } )->all;
    my @titles  = $self->rs('Public::MarketingGenderProxy')->all;
    my @categories = $self->rs('Public::CustomerCategory')->all;


    # general details for all the Promotions
    my $promotion_common = {
        channel_id          => $channel->id,
        promotion_start     => $self->{now}->ymd,
        promotion_end       => $self->{now}->ymd,
        send_once           => 1,
        message             => 'Marketing Promotions - please add promotion pack',
        is_weighted         => 0,
    };

    my %tests   = (
        "Assign Designers to a Promotion" => {
            add => {
                designer    => [ $designers[1] ],
            },
            edit => {
                designer    => [ @designers[0,2] ],
            },
        },
        "Assign Customer Segments to a Promotion" => {
            add => {
                segment     => [ $customer_segments[1] ],
            },
            edit => {
                segment     => [ @customer_segments[0,2] ],
            },
        },
        "Assign Shipping Countries to a Promotion" => {
            add => {
                country     => [ $countries[1] ],
            },
            edit => {
                country     => [ @countries[0,2] ],
            },
        },
        "Assign Languages to a Promotion" => {
            add => {
                language    => [ $languages[1] ],
            },
            edit => {
                language    => [ @languages[0,2] ],
            },
        },
        "Assign Product Types to a Promotion" => {
            add => {
                product_type    => [ $product_types[1] ],
            },
            edit => {
                product_type    => [ @product_types[0,2] ],
            },
        },
        "Assign Titles to a Promotion" => {
            add => {
                gender_proxy    => [ $titles[1] ],
            },
            edit => {
                gender_proxy    => [ @titles[0,2] ],
            },
        },
        "Assign Customer Categories to a Promotion" => {
            add => {
                customer_category => [ $categories[1] ],
            },
            edit => {
                customer_category => [ @categories[0,2] ],
            },
        },
        "Assign All Types of Options" => {
            add => {
                designer        => [ @designers ],
                segment         => [ @customer_segments ],
                country         => [ @countries[0..2] ],
                language        => [ @languages[0..2] ],
                product_type    => [ @product_types[0..2] ],
                gender_proxy    => [ @titles[0..2] ],
                customer_category => [ @categories[0..2] ],
            },
            edit => {
                designer        => [ @designers[0,2] ],
                segment         => [ @customer_segments[0,2] ],
                country         => [ @countries[0,2] ],
                language        => [ @languages[0,2] ],
                product_type    => [ @product_types[0,2] ],
                gender_proxy    => [ @titles[0,2] ],
                customer_category => [ @categories[0,2] ],
            },
        },
    );

    my %default_expect  = (
        ids => {
            designer        => [],
            segment         => [],
            country         => [],
            language        => [],
            product_type    => [],
            gender_proxy    => [],
            customer_category => [],
        },
        # if the Link Relationship between 'marketing_promotion' and an
        # Option is different than the above keys, then use these overrides
        link_overrides => {
            segment     => 'customer_segment',
        },
    );

    my $promo_rs = $self->rs('Public::MarketingPromotion')->search( {}, { order_by => 'id DESC' } );
    my $counter  = ( $promo_rs->count || 0 ) + 1;

    foreach my $label ( keys %tests ) {
        note "Testing: '${label}'";
        my $test = $tests{ $label };

        # clone the Common details to be used to create the Promotion
        my %promotion_details   = %{ $promotion_common };

        # clone the default Expected results
        my %expect  = %{ clone( \%default_expect ) };

        $promotion_details{title} = 'Promotion Test Title - ' . $$ . ' - ' . $counter++;

        note "when Creating a Promotion";
        foreach my $option_type ( keys %{ $test->{add} } ) {
            my @ids                                     = map { $_->id } @{ $test->{add}{ $option_type } };
            $promotion_details{options}{ $option_type } = \@ids;
            $expect{ids}{ $option_type }                = \@ids;
        }

        $self->framework->flow_mech__inthebox_summary
                            ->flow_mech__inthebox__create_link
                                ->flow_mech__inthebox__create_promotion_submit( \%promotion_details );

        # get the last Promotion record created
        my $promo_rec   = $promo_rs->reset->first;
        is( $promo_rec->title, $promotion_details{title},
                "got a Promotion with the Expected Title: '" . $promotion_details{title} . "'" );

        # call the Edit page so that we can check the Options Assigned
        # to the Promotion Record as well as on the Page at the same time
        $self->framework->flow_mech__inthebox__edit_promotion_link( { promotion_id => $promo_rec->id } );
        my $options_on_page = $self->mech->as_data->{options_assigned};

        $self->_check_options_assigned_to_promotion( $promo_rec, \%expect, "Options Assigned after Adding" );

        note "when Editing a Promotion";
        %promotion_details  = ();       # don't need extra info when Editing
        %expect             = %{ clone( \%default_expect ) };
        foreach my $option_type ( keys %{ $test->{edit} } ) {
            my @ids                                     = map { $_->id } @{ $test->{edit}{ $option_type } };
            $promotion_details{options}{ $option_type } = \@ids;
            $expect{ids}{ $option_type }                = \@ids;
        }

        $self->framework->flow_mech__inthebox__edit_form_promotion_submit( \%promotion_details )
                            ->flow_mech__inthebox__edit_promotion_link( { promotion_id => $promo_rec->id } );

        $self->_check_options_assigned_to_promotion( $promo_rec, \%expect, "Options Assigned after Editing" );

        note "when Removing all Options from a Promotion";
        %promotion_details  = ();
        %expect             = %{ clone( \%default_expect ) };
        foreach my $option_type ( keys %{ $test->{add} } ) {
            $promotion_details{options}{ $option_type } = [];   # simulate everything being Unassigned
        }

        $self->framework->flow_mech__inthebox__edit_form_promotion_submit( \%promotion_details )
                            ->flow_mech__inthebox__edit_promotion_link( { promotion_id => $promo_rec->id } );

        $self->_check_options_assigned_to_promotion( $promo_rec, \%expect, "Options Assigned after Removing All of Them" );
    }
}

#------------------------------------------------------------------------------

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub _get_promotion_options {
    my ( $self, $promotion, $option_relationship )  = @_;

    # change 'relation_ship' to 'RelationShip'
    my $link_relationship   = join( '', map { ucfirst( $_ ) } split( /_/, $option_relationship ) );

    return $self->rs( "Public::LinkMarketingPromotion${link_relationship}" )
                    ->search( { marketing_promotion_id => $promotion->id } )
                        ->search_related( $option_relationship )
                            ->all;
}

sub _check_options_assigned_to_promotion {
    my ( $self, $promo_rec, $expect, $mesg ) = @_;

    subtest $mesg => sub {
        $promo_rec->discard_changes;

        my $options_on_page = $self->mech->as_data->{options_assigned};

        # check all the Options have been added to the Promotion
        foreach my $option_relationship ( keys %{ $expect->{ids} } ) {
            my @got         = $self->_get_promotion_options(
                $promo_rec,
                # if there is a specific Link Name to use then use it, else use the default
                $expect->{link_overrides}{ $option_relationship } // $option_relationship
            );
            my @got_ids     = map { $_->id } @got;
            my @expect_ids  = @{ $expect->{ids}{ $option_relationship } };
            cmp_deeply( \@got_ids, bag( @expect_ids ),
                            "All '${option_relationship}' were assigned to the Promotion" );
            cmp_deeply(
                $options_on_page->{ $option_relationship }{assigned_ids},
                bag( @expect_ids ),
                "and all Ids assigned to the Record appear in the Option's Hidden '_list_include' field on the page"
            );
        }
    };

    return;
}

