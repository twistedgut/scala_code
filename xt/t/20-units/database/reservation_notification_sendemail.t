#!/usr/bin/env perl

# Look at the Sign-Off for the Reservation Customer Notification Email

use NAP::policy     'test';

use Test::XTracker::Data;
use Test::XTracker::Hacks::isaFunction;

my $original_get_and_parse_func;
BEGIN {
    no warnings 'redefine';
    use_ok( 'XTracker::Stock::Actions::SendReservationEmail' );

    # override the 'send_email' function with our own so we can test what is sent
    *XTracker::Stock::Actions::SendReservationEmail::send_customer_email = \&_send_email;

    # override the 'get_and_parse_correspondence_template' function to get the data passed to it
    $original_get_and_parse_func    = \&XTracker::Database::Reservation::get_and_parse_correspondence_template;
    *XTracker::Database::Reservation::get_and_parse_correspondence_template = \&_get_and_parse;
}

use Test::XT::Data;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :reservation_status :department );


# Global Variable to contain the content of the Email that will be sent
# and the Data used by the Template to actually build the Email
my $email_args;
my $email_data;

my $schema  = Test::XTracker::Data->get_schema;

my @channels= $schema->resultset('Public::Channel')->search->all;

# list of Department names with their how they appear in the Email Sign-Off
my %department_to_signoff_name  = (
    'Customer Care'     => 'Customer Care',
    'Fashion Advisor'   => 'Fashion Consultant',
    'Personal Shopping' => 'Personal Shopper',
);

# get the various Sing-Offs to check for each department and channel
my %tests   = (
        'NAP'   => {
            'Customer Care'     => qr{Firstname<br/>Customer Care}s,
            'Fashion Advisor'   => qr{Firstname<br/>Fashion Consultant}s,
            'Personal Shopping' => qr{Firstname<br/>Personal Shopper}s,
        },
        'OUTNET'=> {
            'Customer Care'     => qr{Firstname<br/>Customer Care}s,
            'Fashion Advisor'   => qr{Firstname<br/>Fashion Consultant}s,
            'Personal Shopping' => qr{Firstname<br/>Personal Shopper}s,
        },
        'MRP'   => {
            'Customer Care'     => qr{Firstname Lastname}s,
            'Fashion Advisor'   => qr{Firstname Lastname}s,
            'Personal Shopping' => qr{Firstname Lastname}s,
        },
    );

$schema->txn_do( sub {
    # Get Application Operator and Change Name for Tests;
    my $operator= $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );
    $operator->update( { name => 'Firstname Lastname', department_id => $DEPARTMENT__FASHION_ADVISOR } );

    foreach my $channel ( @channels ) {
        note "Sales Channel: ".$channel->name;

        my $test    = $tests{ $channel->business->config_section };

        my $data = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::ReservationSimple',
            ],
        );

        # set-up the channel & operator for the Reservation
        $data->channel( $channel );
        $data->operator( $operator );

        my $reservation = $data->reservation;
        my $product     = $data->variant->product;

        # make reservation record available for 'Customer Notification'
        $reservation->update( {
                                date_uploaded   => \'now()',
                                status_id       => $RESERVATION_STATUS__UPLOADED,
                            } );

        # build up the regex to find the product in the email text
        my $prod_regex  = $product->id . '.*' . $product->designer->designer . '.*' . $product->product_attribute->name;

        # loop through 3 departments checking the 'Sign-Off' for each
        foreach my $department ( keys %{ $test } ) {
            $email_args = {};
            $email_data = {};

            # get a Handler with the necessary data in 'param_of' populated
            my $handler = _mock_handler( $schema, $department, {
                                                        "inc-".$reservation->id => 1,
                                                        channel_id              => $channel->id,
                                                        customer_id             => $reservation->customer_id,
                                                    } );

            XTracker::Stock::Actions::SendReservationEmail::_send_notification( $handler );

            note "check the data used to Build the Email";
            is( $email_data->{sign_off_parts}{name}{full}, $operator->name,
                                    "Operator Name found in 'sign_off_parts'" );
            is( $email_data->{sign_off_parts}{role}{name}, $department_to_signoff_name{ $department },
                                    "Role Name found in 'sign_off_parts'" );
            cmp_deeply(
                $email_data->{product_items},
                {
                    $reservation->id    => superhashof( {
                        product_id  => $product->id,
                        product_name=> $product->product_attribute->name,
                        designer    => $product->designer->designer,
                    } ),
                },
                "'product_items' Hash Ref found and has enough Product Data in it"
            );
            cmp_deeply(
                $email_data->{items},
                {
                    $reservation->id    => {
                        prod_detail => re( qr{<table.*</table>} ),
                        master_sku  => $product->id,
                        product_name=> $product->product_attribute->name,
                        designer    => $product->designer->designer,
                    },
                },
                "'items' Hash Ref also found for backward compatibility"
            );

            note "check the To/From etc. used to Send the Email";
            is( $email_args->{to}, $handler->{param_of}{to_email}, "Email 'To' Address as expected" );
            is( $email_args->{from}, $handler->{param_of}{from_email}, "Email 'From' Address as expected" );
            is( $email_args->{reply_to}, $handler->{param_of}{from_email}, "Email 'Reply-To' Address as expected" );
            like( $email_args->{subject}, qr/\w+/, "Email has something in the Subject" );
            is( $email_args->{content_type}, 'html', "Email has 'html' Content Type" );

            my $email_content   = $email_args->{content};
            cmp_ok( length( $email_content ), '>', 5, "Got some Content for the Email" );
            SKIP: {
                skip "The Outnet Copy is being used for something else at the moment", 3
                                            if ( $channel->business->config_section eq 'OUTNET' );
                like( $email_content, qr{Dear Test Name,}s,
                                            "Found Addressee after Dear in Email Content" );
                like( $email_content, qr{$prod_regex}s, "Found Product Reserved in Email Content" );
                like( $email_content, $test->{ $department },
                                            "Sign-Off as expected for '$department' department: ".$test->{ $department } );
            };
        }
    }

    $schema->txn_rollback();
} );


done_testing();

#-----------------------------------------------------------------

# our own 'send_email' function that gets the email content so it can be tested against
sub _send_email {
    $email_args = $_[0];

    note "=============== IN REDEFINDED 'send_customer_email' FUNCTION ===============";

    return 1;
}

# our own 'get_and_parse' function that actually parses the email Template
sub _get_and_parse {
    $email_data = $_[2]->{data};

    note "=============== IN REDEFINDED 'get_and_parse_correspondence_template' FUNCTION ===============";

    # call the original function as well
    return $original_get_and_parse_func->( @_ );
}

# set-up a mock handler object
sub _mock_handler {
    my ( $schema, $department, $args ) = @_;

    my $dept_id = $schema->resultset('Public::Department')->find(
                            { department => $department },
                            { key => 'department' }
                        )->id;

    my $args_ref = {
            schema  => $schema,
            dbh     => $schema->storage->dbh,
            data    => {
                operator_id     => -1,          # set an invaid user to make sure 'param_of->{operator_id}' is used instead
                department_id   => $dept_id,
            },
            param_of=> {
                operator_id => $APPLICATION_OPERATOR_ID,
                from_email  => 'from.test@test.test',
                to_email    => 'to.test@test.test',
                addressee   => 'Test Name',
                %{ $args }
            },
        };

    # require this because it minimises 'UNIVERSAL::isa' warnings;
    require Test::MockObject;

    my $mock_handler    = Test::MockObject->new($args_ref);
    $mock_handler->set_isa('XTracker::Handler');
    $mock_handler->set_always( operator_id => $args_ref->{data}{operator_id} );
    $mock_handler->set_always( department_id => $args_ref->{data}{department_id} );
    $mock_handler->set_always( schema => $args_ref->{schema} );
    $mock_handler->set_always( dbh => $args_ref->{dbh} );

    return $mock_handler;
}
