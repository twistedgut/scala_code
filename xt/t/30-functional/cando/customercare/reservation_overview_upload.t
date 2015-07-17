#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

reservation_overview_upload.t - Tests the Reservation Overview Upload page

=head1 DESCRIPTION

This will test the Reservation Overview Upload functionality, which generates a PDF of Products for an
Upload Date for a Sales Channel. This is accessed from the 'Stock Control->Reservation' Main Nav option
using the Left Hand Menu option 'Upload' under the 'Overview' heading.

It will test generating the data by using and not using the Filter page.

#TAGS inventory reservation cando

=cut

use DateTime;

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :department
                                        );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "Sanity check" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
    ],
);


#-------------------------------------------------
_test_channel_tabs_and_upload_dates( $schema, $framework, 1 );
_test_filter_upload_pdf( $schema, $framework, 1 );
_test_non_filter_upload_pdf( $schema, $framework, 1 );
#-------------------------------------------------

done_testing();


=head1 METHODS

=head2 _test_channel_tabs_and_upload_dates

    _test_channel_tabs_and_upload_dates( $schema, $framework, $ok_to_do_flag );

Tests the Correct Sales Channel tabs are shown on the Overview - Upload page and also checks
that the correct Upload Dates are shown in the Drop-Down box.

=cut

sub _test_channel_tabs_and_upload_dates {
    my ( $schema, $framework, $oktodo )     = @_;

    SKIP: {
        skip '_test_check_channel_tabs', 1          if ( !$oktodo );

        note "Test Which Sales Channel Tabs are Visible";

        my $mech    = $framework->mech;

        my $date_now    = DateTime->now();
        $date_now->set( hour => 0, minute => 0, second => 0, nanosecond => 0 );     # Upload Dates should start at the beginning of the day
        my $upload_date = $date_now->clone->add( years => 1 );                      # get clear of the current dates
        my %channel_upload_dates;
        my @product_channels;       # store 'product_channel' records to update
                                    # their Upload Dates to 'now' to be more sane
                                    # for future uses of these Products.

        # create some Products for all Channels
        my $channel_rs      = $schema->resultset('Public::Channel')->enabled_channels;
        my %all_channels    = map { $_->id => $_ } $channel_rs->all;
        my %upload_channels = map { $_->id => $_ } $channel_rs->get_channels_for_action('Reservation/Upload')->all;

        foreach my $channel ( values %all_channels ) {
            my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
                                                                channel     => $channel,
                                                                how_many    => 3,
                                                            } );
            # adjust the Upload Date for the Products, set the
            # first 2 Products to one date and then the last to
            # the day after, store these dates in reverse order
            # to mirror how they should be displayed on the page
            $upload_date->add( days => 1 );
            $channel_upload_dates{ $channel->id }[0]    = $upload_date->clone;
            foreach my $idx ( 0..1 ) {
                $pids->[ $idx ]{product_channel}->update( { upload_date => $upload_date } );
                push @product_channels, $pids->[ $idx ]{product_channel};
            }
            $upload_date->add( days => 1 );
            unshift @{ $channel_upload_dates{ $channel->id } }, $upload_date->clone;
            $pids->[2]{product_channel}->update( { upload_date => $upload_date } );
            push @product_channels, $pids->[2]{product_channel};
        }

        my $operator    = Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
        $framework->login_with_permissions( {
            perms => {
                    $AUTHORISATION_LEVEL__MANAGER => [
                        'Stock Control/Reservation',
                    ]
                }
            } );

        $framework->mech__reservation__summary
                    ->mech__reservation__overview_click_upload;
        my $pg_data = $mech->as_data()->{page_data};

        # check correct Channel Tabs are shown on the page
        _check_channel_tabs( $mech, \%upload_channels, "Correct Channel Tabs shown on 'Overview - Upload' page" );

        # check correct Upload Dates shown in Drop Downs
        foreach my $channel ( values %upload_channels ) {
            my @dates_set   = @{ $channel_upload_dates{ $channel->id } };
            my @upload_dates= @{ $pg_data->{ uc( $channel->name ) }{upload_selection}{'Upload Date'}[0]{select_values} };

            # ignore the first option - just a prompt - and only
            # interested in the first 2 & they should be in the
            # 'DD-MM-YYYY' format for both Value & Option
            my @got_dates       = map { { $_->[0] => $_->[1] } } @upload_dates[1,2];
            my @expected_dates  = map { { $_->dmy('-') => $_->dmy('-') } } @dates_set;
            is_deeply( \@got_dates, \@expected_dates, $channel->name . ": Upload Dates in Drop Down as Expected" );
        }

        note "Check 'Overview - Pending' and 'Overview - Waiting List', show the Correct Sales Channel Tabs";
        $framework->mech__reservation__overview_click_pending;
        _check_channel_tabs( $mech, \%all_channels, "Correct Channel Tabs shown on 'Overview - Pending' page" );
        $framework->mech__reservation__overview_click_waiting_list;
        _check_channel_tabs( $mech, \%all_channels, "Correct Channel Tabs shown on 'Overview - Waiting List' page" );


        # Set all Upload Dates to be 'now'
        foreach my $pc ( @product_channels ) {
            $pc->discard_changes->update( { upload_date => $date_now } );
        }
    };

    return;
}

=head2 _test_filter_upload_pdf

    _test_filter_upload_pdf( $schema, $framework, $ok_to_do_flag );

Tests the Filter page which is used to refine the Products that get
produced in the Upload PDF.

Will test filtering on Designer & PIDs.

=cut

sub _test_filter_upload_pdf {
    my ( $schema, $framework, $oktodo )     = @_;

    SKIP: {
        skip '_test_filter_upload_pdf', 1           if ( !$oktodo );

        note "Test Generating an Upload PDF using the Filter Page";

        my $mech    = $framework->mech;

        my %upload_channels = map { $_->id => $_ } $schema->resultset('Public::Channel')
                                                            ->enabled_channels
                                                              ->get_channels_for_action('Reservation/Upload')
                                                                ->all;

        my $operator    = Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
        $framework->login_with_permissions( {
            perms => {
                    $AUTHORISATION_LEVEL__MANAGER => [
                        'Stock Control/Reservation',
                    ]
                }
            } );

        note "Check 'Filter' Button is on the page for each Channel";
        $framework->mech__reservation__summary
                    ->mech__reservation__overview_click_upload;

        my $pg_data = $mech->as_data()->{page_data};
        foreach my $channel ( values %upload_channels ) {
            # the buttons should be in the 2nd part of the Array
            my $buttons = $pg_data->{ uc( $channel->name ) }{upload_selection}{'Upload Date'}[1]{inputs};
            my @expected= (
                    { input_name => "channel_upload", input_type => "hidden", input_value => $channel->name, input_readonly => 0 },
                    { input_name => undef,            input_type => "submit", input_value => re("Generate PDF"), input_readonly => 0 },
                    { input_name => undef,            input_type => "button", input_value => re("Apply Filter to PDF"), input_readonly => 0 },
                );
            cmp_deeply( $buttons, \@expected, $channel->name . ": All Buttons & Hidden Fields are present" );
        }

        # go to the Filter Page
        foreach my $channel ( values %upload_channels ) {
            my $channel_name    = $channel->name;
            note "Testing Filter Page for Sales Channel: (" . $channel->id . ") " . $channel_name;

            my $data        = _create_designers_and_get_pids( $channel );
            my @designers   = @{ $data->{designers} };
            my $upload_date_str = $data->{upload_date}->dmy('-');

            $framework->mech__reservation__summary
                        ->mech__reservation__overview_click_upload
                            ->mech__reservation__overview_upload__filter_pdf_submit( $channel_name, $upload_date_str );

            $mech->client_parse_cell_deeply(1);     # will show whether a checkbox is actually ticked
            my $pg_data = $mech->as_data();
            $mech->client_parse_cell_deeply(0);
            my %expected_designers  = map { $_->id => $_->designer }
                                            @designers;
            my %got_designers       = map { $pg_data->{designer_list}->{ $_ }->{input_value} => $_ }
                                            keys %{ $pg_data->{designer_list} };
            is_deeply( \%got_designers, \%expected_designers, "Expected Designers are shown on the Page" );
            %got_designers          = map { $pg_data->{designer_list}->{ $_ }->{input_value} => $_ }
                                            grep { $pg_data->{designer_list}->{ $_ }->{input_checked} }
                                                keys %{ $pg_data->{designer_list} };
            is_deeply( \%got_designers, \%expected_designers, "and all of them are 'checked'" );
            ok( exists( $pg_data->{product_id_entry} ), "Product ID Entry box shown on the Page" );

            # Exclude 2 Designers and some Products
            my @exclude_designers   = @designers[1,3];
            my @exclude_products    = @{ $data->{designer_pids}{ $designers[0]->id } };
            my $exclude_product_txt = join(
                                            "\n",
                                            ( map { $_->id } @exclude_products )
                                        );
            $framework->errors_are_fatal(0);
            $framework->mech__reservation__overview_upload__apply_filter_pdf_submit( {
                                                                    exclude_designer_ids=> [
                                                                                        map { $_->id } @exclude_designers
                                                                                    ],
                                                                    exclude_product_ids => $exclude_product_txt
                                                                                           . " 142342342",   # a Non-Existent PID
                                                            } );
            $framework->errors_are_fatal(1);
            like( $mech->app_error_message, qr/Excluded Product Id.*142342342/i,
                                        "Found Error Message alerting of the Bad PID being Excluded" );
            like( $mech->app_info_message, qr/PDF for the $upload_date_str upload for $channel_name/i,
                                        "Found Info Message telling the User the PDF is being generated" );
            like( $mech->app_status_message, qr/Upload PDF has been Filtered/i, "Found Success Message" );

            my $excluded    = $mech->as_data()->{excluded};
            is_deeply(
                        [ sort { $a <=> $b } keys %{ $excluded->{designers} } ],
                        [ sort { $a <=> $b } map { $_->id } @exclude_designers ],
                        "Expected Excluded Designers shown on page"
                    );
            is_deeply(
                        [ sort { $a <=> $b } keys %{ $excluded->{products} } ],
                        [ sort { $a <=> $b } map { $_->id } @exclude_products ],
                        "Expected Excluded Products shown on page"
                    );


            note "Now Re-Filter the PDF";
            $framework->mech__reservation__overview_upload__re_filter_submit;
            $mech->client_parse_cell_deeply(1);     # will show whether a checkbox is actually ticked
            $pg_data    = $mech->as_data();
            $mech->client_parse_cell_deeply(0);

            %got_designers  = map { $pg_data->{designer_list}->{ $_ }->{input_value} => $_ }
                                        keys %{ $pg_data->{designer_list} };
            is_deeply( \%got_designers, \%expected_designers, "All Designers are STILL shown on the Page" );
            my @unchecked_designers = map { $pg_data->{designer_list}->{ $_ }->{input_value} }
                                        grep { !$pg_data->{designer_list}->{ $_ }->{input_checked} }
                                            keys %{ $pg_data->{designer_list} };
            is_deeply(
                        [ sort { $a <=> $b } @unchecked_designers ],
                        [ sort { $a <=> $b } map { $_->id } @exclude_designers ],
                        "Already Excluded Designers are 'unchecked' on page"
                    );
            my $got_excluded_pid_box= $pg_data->{product_id_entry}{'Enter a list of Product IDs'};
            $exclude_product_txt    =~ s/\n/ /g;
            like( $got_excluded_pid_box, qr/$exclude_product_txt/, "Exclude PID Text Box has Excluded PIDs in it" );

            # submit again expecting NO Errors as the Bad PID won't be there this time
            $framework->mech__reservation__overview_upload__apply_filter_pdf_submit();
            like( $mech->app_status_message, qr/Upload PDF has been Filtered/i, "Found Success Message" );
            $excluded   = $mech->as_data()->{excluded};
            is_deeply(
                        [ sort { $a <=> $b } keys %{ $excluded->{designers} } ],
                        [ sort { $a <=> $b } map { $_->id } @exclude_designers ],
                        "Expected Excluded Designers STILL shown on page"
                    );
            is_deeply(
                        [ sort { $a <=> $b } keys %{ $excluded->{products} } ],
                        [ sort { $a <=> $b } map { $_->id } @exclude_products ],
                        "Expected Excluded Products STILL shown on page"
                    );

            # just check that you can click on the 'Upload' link to take you back
            $framework->mech__reservation__overview_upload__filter_backto_upload_click();


            note "Now Just get a PDF via the Filter page but without any Filtering";
            $framework->mech__reservation__summary
                        ->mech__reservation__overview_click_upload
                            ->mech__reservation__overview_upload__filter_pdf_submit( $channel_name, $upload_date_str )
                                ->mech__reservation__overview_upload__apply_filter_pdf_submit();
            like( $mech->app_info_message, qr/PDF for the $upload_date_str upload for $channel_name/i,
                                        "Found Info Message telling the User the PDF is being generated" );
            like( $mech->app_status_message, qr/Upload PDF has been Filtered/i, "Found Success Message" );
            $excluded   = $mech->as_data()->{excluded};
            ok( !exists( $excluded->{designers} ), "No Designers are Listed as being Excluded" );
            ok( !exists( $excluded->{products} ), "No Products are Listed as being Excluded" );


            _reset_data_to_normal( $data );
        }
    };

    return;
}

=head2 _test_non_filter_upload_pdf

    _test_non_filter_upload_pdf( $schema, $framework, $ok_to_do_flag );

This tests generating the Upload PDF without going via the Filter Page.

=cut

sub _test_non_filter_upload_pdf {
    my ( $schema, $framework, $oktodo )     = @_;

    SKIP: {
        skip '_test_filter_upload_pdf', 1               if ( !$oktodo );

        note "Test Generating an Upload PDF WITHOUT using the Filter Page";

        my $mech    = $framework->mech;

        my %upload_channels = map { $_->id => $_ } $schema->resultset('Public::Channel')
                                                            ->enabled_channels
                                                                ->get_channels_for_action('Reservation/Upload')
                                                                    ->all;

        my $operator    = Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
        $framework->login_with_permissions( {
            perms => {
                    $AUTHORISATION_LEVEL__MANAGER => [
                        'Stock Control/Reservation',
                    ]
                }
            } );

        # go to the Filter Page
        foreach my $channel ( values %upload_channels ) {
            my $channel_name    = $channel->name;
            note "Testing for Sales Channel: (" . $channel->id . ") " . $channel_name;

            my $pid_data        = _create_designers_and_get_pids( $channel );
            my $upload_date_str = $pid_data->{upload_date}->dmy('-');

            my $data    = Test::XT::Flow->new_with_traits(
                                 traits => [
                                       'Test::XT::Data::ReservationSimple',
                                   ],
                             );
            $data->channel( $channel );
            $data->variant( $pid_data->{pids}[0]{variant} );

            my $reservation     = $data->reservation;
            my $product_used    = $data->product;

            $framework->mech__reservation__summary
                        ->mech__reservation__overview_click_upload
                            ->mech__reservation__overview_upload__generate_pdf_submit( $channel_name, $upload_date_str );
            like( $mech->app_info_message, qr/PDF for the $upload_date_str upload for $channel_name/i,
                                        "Found Info Message telling the User the PDF is being generated" );

            my $seasons_shown   = $mech->as_data()->{page_data}{ $channel_name }{seasons};
            ok( defined $seasons_shown, "There are Seasons shown on the Page" );
            ok( exists( $seasons_shown->{ $product_used->season->season } ),
                                        "and the Season for the Product Reserved is shown" );
            ok( grep( { $_->{'Product ID'}{value} == $product_used->id } @{ $seasons_shown->{ $product_used->season->season } } ),
                                        "and the Product Reserved is listed for that Season" );


            _reset_data_to_normal( $pid_data );
        }
    };

    return;
}

#---------------------------------------------------------------------------

=head2 _check_channel_tabs

    _check_channel_tabs( $mech_object, $array_ref_of_channels, $test_message );

Used to test that the expected Sales Channel tabs are shown on the page.

=cut

sub _check_channel_tabs {
    my ( $mech, $channels, $message )   = @_;

    my $pg_data = $mech->as_data()->{page_data};
    my %expected    = map { uc( $_->name ) => 1 } values %{ $channels };
    my %got         = map { $_ => 1 } keys %{ $pg_data };
    is_deeply( \%got, \%expected, $message );

    return;
}

=head2 _create_designers_and_get_pids

    $hash_ref_of_data = _create_designers_and_get_pids( $dbic_channel );

Creates new Designers and assigns them to PIDs.

Returns a Hash Ref with the following data:

    {
        now_date            => $now,
        upload_date         => $upload_date,
        designers           => \@designers,
        pids                => $pids,
        existing_designer   => $existing_designer,
        designer_pids       => \%designer_pids,
    }

=cut

sub _create_designers_and_get_pids {
    my $channel     = shift;

    my $schema      = $channel->result_source->schema;
    my $designer_rs = $schema->resultset('Public::Designer');

    my $existing_designer   = $designer_rs->search( {}, { order_by => 'id ASC' } )->first;

    my @designers;
    foreach my $designer_name ( (
                         'My First Designer',
                         'Designers R Us',
                         'Couldn\'t think of a name',
                         'This is a long Designer Name to see How it Looks on the Page',
                     ) ) {
        my $url_key = lc( $designer_name );
        $url_key    =~ s/[^a-z,0-9,\s]//g;
        $url_key    =~ s/\s/_/g;
        push @designers, $designer_rs->update_or_create( {
                                    designer    => $designer_name,
                                    url_key     => $url_key,
                                } );
    }

    my $now = DateTime->now();
    $now->set( hour => 0, minute => 0, second => 0, nanosecond => 0 );
    my $upload_date = $now->clone->add( years => 1 );

    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
                                                    channel     => $channel,
                                                    how_many    => 7,
                                                } );

    # array to cycle round Designers when applying them to Products
    my @use_designers   = @designers;
    foreach my $pid ( @{ $pids } ) {
        my $designer    = shift @use_designers;     # take designer off the beginning
        $pid->{product}->update( { designer_id => $designer->id } );
        push @use_designers, $designer;             # add designer to the end
        $pid->{product_channel}->update( { upload_date => $upload_date } );
    }

    # get a list of Products for Designers
    my %designer_pids;
    foreach my $pid ( @{ $pids } ) {
        push @{ $designer_pids{ $pid->{product}->designer_id } }, $pid->{product};
    }

    return {
            now_date    => $now,
            upload_date => $upload_date,
            designers   => \@designers,
            pids        => $pids,
            existing_designer => $existing_designer,
            designer_pids => \%designer_pids,
        };
}

=head2 _reset_data_to_normal

    _reset_data_to_normal( $hash_of_data );

This Resets the Data (Products & Designers) used to normal, to limit impact on future test files.

=cut

sub _reset_data_to_normal {
    my $data    = shift;

    # reset the Upload Dates to be 'now' rather than leave them in the future
    # and update the Designer to be for an Existing One
    foreach my $pid ( @{ $data->{pids} } ) {
        $pid->{product_channel}->discard_changes->update( { upload_date => $data->{now_date} } );
        $pid->{product}->discard_changes->update( { designer_id => $data->{existing_designer}->id } );
    }

    # delete all of the Designers created
    # if they aren't attached to any other PIDs
    foreach my $designer ( @{ $data->{designers} } ) {
        if ( !$designer->discard_changes->products->count ) {
            $designer->delete;
        }
    }

    return;
}
