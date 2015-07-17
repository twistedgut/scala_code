#!/usr/bin/env perl

use NAP::policy "tt",     'test';

#
# Test Receive::StockControl::Reservation::PreparePDF job
#

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => qw( $distribution_centre );

use XTracker::Config::Local             qw( config_var );
use XTracker::Constants                 qw( :application );
use XTracker::Database::Reservation     qw( get_upload_reservations );
use XTracker::Utilities                 qw( :string );
use XTracker::DBEncode                  qw( decode_db );
use XTracker::Constants::FromDB         qw( :branding );

use Test::MockObject;

use DateTime;
use DateTime::Duration;

use HTML::TreeBuilder::XPath;

my ($schema);
my $job_payload;

BEGIN {
    no warnings 'redefine';
    use_ok("XT::JQ::DC::Receive::StockControl::Reservation::PreparePDF");

    # re-define 'request' method in LWP::UserAgent, so that 'LWP::Simple::head' can
    # always find images and build the PDF properly. Tried to re-define 'head' but
    # this just didn't work properly and always ended up using the original instead.
    use_ok("LWP::UserAgent");
    *LWP::UserAgent::request = sub {
                            return _setup_fake_response();
                        };

    # re-define the 'set_payload' method so that we can get what payload is being sent
    use_ok("XT::JQ::DC");
    *XT::JQ::DC::set_payload    = sub {
                            my ( $self, $payload )  = @_;
                            $job_payload    = $payload;     # store it externally
                            return $self->{payload} = $payload;
                        };

    $schema = Test::XTracker::Data->get_schema;
    isa_ok( $schema, 'XTracker::Schema' );
}


#--------------- Run TESTS ---------------

_test_prepare_pdf();

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_prepare_pdf {

    my $payload;
    my @channels    = (
                        Test::XTracker::Data->channel_for_nap(),
                        Test::XTracker::Data->channel_for_out(),
                        Test::XTracker::Data->channel_for_mrp(),
                      );

    my $upload_date = DateTime->now();
    $upload_date->set( hour => 0, minute => 0, second => 0, nanosecond => 0, );

    $schema->txn_do( sub {

        foreach my $channel ( @channels ) {

            note "Testing Channel: " . $channel->name;

            my $pids        = _get_pids( $channel, $upload_date );
            my $brand_date  = $channel->business->branded_date( $upload_date );

            $payload    = {
                        channel_name    => $channel->name,
                        channel_id      => $channel->id,
                        output_filename => config_var('SystemPaths','include_dir').'/'
                                           . sprintf( 'upload_%d_%s_%d.pdf', $channel->id, $upload_date->dmy('-'), $APPLICATION_OPERATOR_ID ),
                        upload_date     => $upload_date->dmy('-'),
                        current_user    => $APPLICATION_OPERATOR_ID,
                    };
            lives_ok( sub {
                _send_job( $payload, "Receive::StockControl::Reservation::PreparePDF" );
            }, "Send Prepare PDF Request" );

            my ( $pages )   = _parse_html_content( $job_payload->{html_content} );
            my $header = $channel->branding->{$BRANDING__PLAIN_NAME};
            like( $job_payload->{html_content}, qr{[0-9]<br /><br /></span>}, "There are 2 'BR' tags after the price" );

             my $footer_txt = $channel->get_reservation_upload_pdf_footer;

            cmp_ok( scalar @{ $pages }, '==', 2, "Have 2 pages of PIDs" );
            cmp_ok( scalar @{ $pages->[0] }, '==', 9, "First page has 9 PIDs" );
            cmp_ok( scalar @{ $pages->[1] }, '==', 5, "Second page has 5 PIDs" );

            is_deeply( $job_payload->{pdf_options}, {
                                            page => { size => 'A4' },
                                            body_font => { face => 'Arial' },
                                            header => {
                                                     left => $header,
                                                     centre => $brand_date,
                                                     right  => { symbol => 'PAGE_NUMBER'},
                                                     },
                                            footer => {
                                                        centre => $footer_txt,
                                                    },
                                            }, "PDF Options in Job Payload as Expected" );

            # go through each page and check all products are correct
            note "Go through each page and check that all the Items are correct and in the expected order";
            foreach my $page_idx ( 0..$#{ $pages } ) {
                note "Page: $page_idx";
                foreach my $item_idx ( 0..$#{ $pages->[ $page_idx ] } ) {
                    my $product = $pids->[ $item_idx + ( $page_idx * 9 ) ];     # get the appropriate product
                    my $item    = $pages->[ $page_idx ][ $item_idx ];

                    my $name        = rtrim( decode_db($product->product_attribute->name) );
                    my $designer    = uc( decode_db($product->designer->designer) );
                    my $pid         = $product->id;
                    if ( $designer =~ m/^CHLO/ ) {
                        $designer   = 'CHLO';   # account for the Chloe exception that's in the code
                    }

                    like( $item->{text}, qr/^$designer.*$name +\(PID[^0-9,A-Z]$pid\)/, "Item: $item_idx, Designer, Name & PID are correct for PID: ".$product->id );
                }
            }

            note "Now use a 'filter' to exclude some of the PIDs";
            # add a filter to the above payload
            $payload->{filter}{exclude_pids}    = [ map { $_->id } @{ $pids }[0,1,2] ];

            $job_payload    = undef;
            lives_ok( sub {
                _send_job( $payload, "Receive::StockControl::Reservation::PreparePDF" );
            }, "Send Prepare PDF Request" );

            ( $pages )  = _parse_html_content( $job_payload->{html_content} );
            my @got_pids;
            foreach my $page_idx ( 0..$#{ $pages } ) {
                push @got_pids, map { $_->{pid} } @{ $pages->[ $page_idx ] };
            }
            is_deeply(
                        [ sort { $a <=> $b } @got_pids ],
                        [ sort { $a <=> $b } map { $_->id } @{ $pids }[ 3..$#{ $pids } ] ],
                        "Using a Filter Excluded the Expected PIDs"
                    );
        }

        # rollback changes
        $schema->txn_rollback();
    } );
}


#--------------------------------------------------------------

# parse the HTML content that will be converted into a PDF
sub _parse_html_content {
    my $content = shift;

    my @retval;

    # split up the pages, so that where there are page breaks
    # they are replaced with open and closing table tags which
    # create 1 Table per page.
    $content    =~ s{<!-- PAGE BREAK -->}{</table><!-- PAGE BREAK --><table>}g;
    $content    =~ s{(&pound;|\$)}{}g;               # get rid of any currency symbols

    my $tree    = HTML::TreeBuilder::XPath->new_from_content( $content );
    my @tables  = $tree->find_xpath('/html/body/table')->get_nodelist();
    foreach my $table ( @tables ) {
        my $parsed  = _parse_table( $table );
        push @retval, $parsed;
    }

    #my $title   = $tree->find_xpath('/html/head/title')
    #                   ->get_node(1)
    #                       ->as_text;

    return (\@retval );
}

# parse a table
sub _parse_table {
    my $table   = shift;

    my @retval;

    my @tds = $table->find_xpath('./tr/td')->get_nodelist();
    foreach my $td ( @tds ) {
        my $cell_text   = $td->as_text;

        my $pid;
        if ( $cell_text =~ m/.*\(PID\s(\d+)\)/ ) {
            $pid    = $1;
        }

        my $cell    = {
                pid     => $pid,
                text    => $cell_text,
                img     => $td->find_xpath('.//img')->get_node(1)->attr('src'),
            };
        push @retval, $cell;
    }

    return \@retval;
}

# get PIDs required for test
sub _get_pids {
    my ( $channel, $upload_date )   = @_;

    my $schema  = $channel->result_source->schema;

    my ( $tmp, $pids )  = Test::XTracker::Data->grab_products( {
                                                    how_many            => 14,
                                                    dont_ensure_stock   => 1,
                                                    channel             => $channel,
                                                } );
    my $product_ids = [ map { $_->{pid} } @{ $pids } ];

    # get date to move the upload date of other PIDs out out of
    # the way from the Upload Date I'm going to use in the test
    my $outoftheway_date= $upload_date - DateTime::Duration->new( days => 3 );
    my $prods_to_move   = $schema->resultset('Public::ProductChannel')->search( { channel_id => $channel->id, upload_date => $upload_date } );
    $prods_to_move->update( { upload_date => $outoftheway_date } );

    # now set the Upload Date of the PIDs that have
    # been grabbed to the date requested for the test
    $prods_to_move  = $schema->resultset('Public::ProductChannel')->search( {
                                                            channel_id => $channel->id,
                                                            product_id => { 'IN' => $product_ids },
                                                        } );
    $prods_to_move->update( { upload_date => $upload_date } );

    # now get the upload list that should be used by the JQ Worker so
    # we can have them sorted in the correct manner, then go through
    # the list and put them into an array of PIDs using the 'product'
    # record we already have for them
    my @products;
    my $list    = get_upload_reservations( $schema->storage->dbh, $channel->id, $upload_date->dmy('-') );
    foreach my $key ( sort { $a <=> $b } keys %{ $list } ) {
        my $id  = $list->{$key}{id};
        ( $tmp )    = grep { $_->{pid} == $id } @{ $pids };
        push @products, $tmp->{product};
    }

    return \@products;
}

# Creates and executes a job
sub _send_job {
    my $payload = shift;
    my $worker  = shift;

    note "Job Payload: " . p( $payload );

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [ payload => $payload, schema => $schema, dbh => $schema->storage->dbh, ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr         if $errstr;
    $job->do_the_task( $fake_job );

    return $job;
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}

# used in the re-defining of 'LWP::UserAgent::request'
sub _setup_fake_response {
    my $fake    = Test::MockObject->new();
    $fake->set_isa('HTTP::Response');
    $fake->set_always( is_success => 1 );
}
