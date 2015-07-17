package Test::Comms::DataTransfer;

use NAP::policy "tt", 'test';
use base 'Test::Class';

use Data::Dump qw(pp);
use Test::Exception;

use FindBin::libs;

use Test::XTracker::Data;

BEGIN { use_ok('XTracker::Comms::DataTransfer', qw<
    get_transfer_sink_handle
    transfer_navigation_data
    transfer_product_data
>); };

sub startup : Test(startup => 2) {
    can_ok('XTracker::Comms::DataTransfer', qw<
        get_transfer_sink_handle
        transfer_navigation_data
        transfer_product_data
        is_valid_region
    >);
    isa_ok(
        $_[0]->{schema} = Test::XTracker::Data->get_schema,
        'XTracker::Schema'
    );
}

sub test_replace_comment_tokens : Tests {
    my ( $self ) = @_;

    my @link_texts = ( q{XTracker's apostrophe test}, q{Multiple tags}, q{+SpecialREChars*****} );
    my $create_input = sub { return "[$_[0] id$_[1]]"; };

    # Expected output patterns for tests
    my %pattern_for = (
        mrp => {
            visible => [ map {
                qq{<a href="/product/\$product_id" class="product-item">$_</a>}
            } @link_texts ],
            invisible => [ map {
                qq{<a href="/product/\$product_id" class="product-item">$_</a>}
            } @link_texts ],
        },
        out => {
            visible => [ map {
                qq{<a href="/product/\$product_id">$_</a>}
            } @link_texts ],
            invisible => [ map {
                qq{<a href="javascript:ri('\$designer', '\$product_id');">$_</a>}
            } @link_texts ],
        },
        nap => {
            visible => [ map {
                qq{<a href="/product/\$product_id">$_</a>}
            } @link_texts ],
            invisible => [ map {
                qq{<a href="javascript:ri('\$designer', '\$product_id');">$_</a>}
            } @link_texts ],
        },
    );
    # Update hashrefs for tests
    my %update_fields = (
        visible => { live => 1, visible => 1, },
        invisible => { live => 1, visible => 0, staging => 0 },
    );
    for my $web_name ( keys %pattern_for ) {
        my $channel = Test::XTracker::Data->channel_for_business(name=>$web_name);

        my $pids = Test::XTracker::Data->find_or_create_products({
            how_many => 4,
            channel_id => $channel->id,
            dont_ensure_stock => 1,
            dont_ensure_live_or_visible => 1,
        });
        # Get the pid that we want to set the links for
        my $source_pid = shift @$pids;

        # Tie the link_texts to the pids, so we match them appropriately
        my %link_to_pid = map { $_ => shift @$pids } @link_texts;

        # Create our input string
        my $input = join q{ }, map {
            $create_input->($_, $link_to_pid{$_}{pid})
        } keys %link_to_pid;

        for my $status ( keys %{$pattern_for{$web_name}} ) {
            my @patterns = @{$pattern_for{$web_name}{$status}};

            for my $link_text ( keys %link_to_pid ) {
                my $pid = $link_to_pid{$link_text};

                # Ensure the product is in the desired state
                $pid->{product_channel}->update($update_fields{$status})
                    if defined $update_fields{$status};

                # Update patterns for each link with correct pid/designer
                for my $pattern ( @patterns ) {
                    if ( $pattern =~ m{\Q$link_text\E} ) {
                        # Replace the product_id
                        my $product_id = $pid->{pid};
                        $pattern =~ s{\$product_id}{$product_id};

                        # Replace the designer name
                        my $designer = $pid->{product}->designer->designer;
                        $pattern =~ s{\$designer}{$designer};
                    }
                }
            }

            my $markup = XTracker::Markup->new({
                product_id => $source_pid->{pid},
                schema     => $_[0]->{schema}
            });

            my $replaced_comments = $markup->_add_product_links({
                text => $input,
            });
            like( $replaced_comments, qr{\Q$_\E}, "comment ok on $web_name for $status products" )
                for @patterns;
        }
    }
}

sub test_transfer_product_data {
    my ( $self ) = @_;
    my $channel = Test::XTracker::Data->channel_for_nap;

    # set-up a dbh ref that will be passed into the functions for the NAP Web
    # DB
    my $dbh_ref = get_transfer_sink_handle({
        environment => 'live',
        channel => $channel->business->config_section,
    });
    # pass the XT DB Handle as well
    $dbh_ref->{dbh_source}  = $self->{schema}->storage->dbh;

    lives_ok( sub {
        transfer_product_data({
            dbh_ref     => $dbh_ref,
            channel_id  => $channel->id,
            product_ids => [ 12345, 54321 ],
        });
    }, "'transfer_product_data' lives ok with valid arguments" );
    dies_ok( sub {
        transfer_product_data({
            dbh_ref     => $dbh_ref,
            channel_id  => $channel->id,
            product_ids => [ 12345, 54321 ],
            transfer_categories => [ 'test_category' ],
        } );
    }, "'transfer_product_data' dies with invalid arguments" );
    like( $@, qr/Invalid transfer_category \(test_category\)/,
        "Die message shows invalid category 'test_category'" );

    # now undef the web handle and should be fine as it should just return
    # immediately if there is no Web handle to connect to regardless of the
    # validity of the other arguments
    $dbh_ref->{dbh_sink} = undef;

    lives_ok( sub {
        transfer_product_data({
            dbh_ref     => $dbh_ref,
            channel_id  => $channel->id,
            product_ids => [ 12345, 54321 ],
            transfer_categories => [ 'test_category' ],
        });
    }, "'transfer_product_data' lives ok with disconnected Web Handle" );
    # now check with only passing 'dbh_source' in the 'dbh_ref' argument
    lives_ok( sub {
        transfer_product_data({
            dbh_ref     => { dbh_source => $dbh_ref->{dbh_source} },
            channel_id  => $channel->id,
            product_ids => [ 12345, 54321 ],
            transfer_categories => [ 'test_category' ],
        });
    }, "'transfer_product_data' lives ok with just 'dbh_source' passed" );
}

sub test_transfer_navigation_data : Tests {
    my ( $self ) = @_;
    my $channel = Test::XTracker::Data->channel_for_nap;

    # set-up a dbh ref that will be passed into the functions for the NAP Web
    # DB
    my $dbh_ref = get_transfer_sink_handle({
        environment => 'live',
        channel => $channel->business->config_section,
    });
    # pass the XT DB Handle as well
    $dbh_ref->{dbh_source}  = $self->{schema}->storage->dbh;

    lives_ok( sub {
        transfer_navigation_data({
            dbh_ref     => $dbh_ref,
            ids         => [ 12345, 54321 ],
            transfer_category => 'navigation_category',
        });
    }, "'transfer_navigation_data' lives ok with valid arguments" );
    dies_ok( sub {
        transfer_navigation_data({
            dbh_ref     => $dbh_ref,
            ids         => [ 12345, 54321 ],
            transfer_category => 'test_category',
        });
    }, "'transfer_navigation_data' dies with invalid arguments" );
    like( $@, qr/Invalid transfer_category \(test_category\)/,
        "Die message shows invalid category 'test_category'" );

    # now undef the web handle and should be fine as it should just return
    # immediately if there is no Web handle to connect to regardless of the
    # validity of the other arguments
    $dbh_ref->{dbh_sink} = undef;

    lives_ok( sub {
        transfer_navigation_data({
            dbh_ref     => $dbh_ref,
            ids         => [ 12345, 54321 ],
            transfer_category => 'test_category',
        });
    }, "'transfer_navigation_data' lives ok with disconnected Web Handle" );
    # now check with only passing 'dbh_source' in the 'dbh_ref' argument
    lives_ok( sub {
        transfer_navigation_data({
            dbh_ref     => { dbh_source => $dbh_ref->{dbh_source} },
            ids         => [ 12345, 54321 ],
            transfer_category => 'test_category',
        });
    }, "'transfer_navigation_data' lives ok with just 'dbh_source' passed" );
}

sub test_is_valid_alias : Tests {
    my $self = shift;

    my @aliases = $self
        ->{schema}
        ->resultset('Public::DistribCentre')
        ->get_column('alias')
        ->all;

    my @tests;

    push( @tests, {
        expected    => 1,
        description => 'no prefix',
        parameters  => [ $_ ]
    } ) foreach @aliases;

    push( @tests, {
        expected    => 1,
        description => 'correct prefix',
        parameters  => [ "ok_$_", 'ok_' ]
    } ) foreach @aliases;

    push( @tests, {
        expected    => 0,
        description => 'prefix not specified',
        parameters  => [ "ok_$_" ]
    } ) foreach @aliases;

    push( @tests, {
        expected    => 0,
        description => 'wrong prefix',
        parameters  => [ "ok_$_", 'fail_' ]
    } ) foreach @aliases;

    push( @tests, {
        expected    => 0,
        description => 'non existent region',
        parameters  => [ 'non_existent' ]
    } );

    push( @tests, {
        expected    => 0,
        description => 'invalid region with correct prefix',
        parameters  => [ 'ok_non_existent', 'ok_' ]
    } );

    push( @tests, {
        expected    => 0,
        description => 'invalid region with wrong prefix',
        parameters  => [ 'ok_non_existent', 'fail_' ]
    } );

    foreach my $test ( @tests ) {

        my @parameters     = @{ $test->{parameters} };
        my $paramater_text = '"' . join( '", "', @parameters ) . '"';

        my $result = XTracker::Comms::DataTransfer::is_valid_region( @parameters );

        cmp_ok( $result, '==', $test->{expected}, "is_valid_region($paramater_text) with $test->{description} returns $result as expected" );

    }

}

Test::Class->runtests;

1;
