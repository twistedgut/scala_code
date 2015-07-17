package XT::DC::Controller::CustomerCare::CustomerCategory;

use NAP::policy qw(class tt);

use XTracker::Logfile   qw( xt_logger );
use XTracker::Constants::Seaview qw( :seaview_failure_messages );

BEGIN { extends 'Catalyst::Controller' };

=head1 NAME

XT::DC::Controller::CustomerCare::CustomerCategory

=head1 DESCRIPTION

Controller for /CustomerCare/CustomerCategory

=head1 METHODS

=over

=item B<root>

Uses REST and includes a GET and a POST which submits customer numbers for their customer category to be updated

=cut

# ----- common -----

sub begin : Private {
    my ($self, $c) = @_;

    $c->check_access();
}

sub bulk_category : Path('/CustomerCare/CustomerCategory') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    # Get the customer categories from the database
    my @categories = $c->model("DB::Public::CustomerCategory")->search(
        {},
        {order_by => {-asc => "category"}}
    )->all;

    my @customer_categories = map { { id => $_->id, category => $_->category } } @categories;

    # Get the channels from the database
    my @channels = $c->model("DB::Public::Channel")->channel_list->all;

    $c->stash(
        customer_categories => \@customer_categories,
        channels            => \@channels,
        template => "customercare/customercategory/bulk.tt",
        logger => xt_logger(),
    );
}

sub bulk_category_GET {
    my ($self, $c) = @_;
}

sub bulk_category_POST {
    my ($self, $c) = @_;
    my $form_ok = 1;

    my $request_params = $c->request->parameters;

    if( $request_params->{ 'failed_customer_ids'} ) {

        my $failed_ids = $request_params->{ 'failed_customer_ids' };
        $c->stash(
            customer_numbers => $failed_ids,
        );

    } else {
        $c->stash(
            css     => [ '/css/customercare/customercategory.css' ],
            js      => [ '/javascript/customercare/bulkcustomercategorysummary.js' ],
        );

        my $channel;
        my $channel_id = $request_params->{'channel'};
        # Check channel has been selected
        if ( !$channel_id ) {
            $c->feedback_warn('Please select a channel');
            $form_ok = 0;
        }
        else {
            $channel = $c->model('DB::Public::Channel')->find($channel_id);
            # Check channel can be found
            unless (  $channel ) {
                $c->feedback_warn('Please select a valid channel');
                $form_ok = 0;
            }
        }

        # Check customer category has been selected
        unless ( $c->request->param('category') ) {
            $c->feedback_warn('Please select a category');
            $form_ok = 0;
        }

        unless ( $form_ok ) {
            $c->stash(
                customer_numbers => $c->request->param( 'customers' ) // '',
            );
            return;
        }

        my $invalid_customers = [];
        my $customer_records = $c->model('DB::Public::Customer')
            ->from_text( $request_params->{ 'customers' }, $invalid_customers )
            # Order the customer numbers in ascending numerical order
            ->search_rs( {channel_id => $channel_id},
                {order_by => { -asc => 'is_customer_number' }} );

        my $customer_records_count = $customer_records->count;
        my @all_customer_records = $customer_records->all;

        # Check at least one customer id has been entered
        unless ( $customer_records_count > 0 || scalar(@$invalid_customers) > 0 ) {
            $c->feedback_warn('Please enter at least one customer ID');
            $form_ok = 0;
        }

        # Limit amount of customer numbers to 1000
        unless ( $customer_records_count < 1001 ) {
            $c->feedback_warn("You entered $customer_records_count customer numbers. Please enter 1000 or fewer customer numbers at a time");
            $form_ok = 0;
        }

        # If the form was completed correctly.
        if ( $form_ok ) {

            $c->stash(
                template    => "customercare/customercategory/summary.tt",
            );

            my @success_customers = map{ $_->is_customer_number } @all_customer_records;

            my $schema = $c->model('DB')->schema;

            my @invalid_customer_list = map{ $_->{is_customer_number} } (@$invalid_customers);
            @invalid_customer_list = sort{$a <=> $b} (@invalid_customer_list);
            $c->stash(
                successes               => \@all_customer_records,
                success_count           => scalar( @success_customers ),
                invalid_count           => scalar( @$invalid_customers ),
                invalid_customer_list   => \@invalid_customer_list,
            );

            my $payload = {
                customer_category_id => $c->request->param('category'),
                channel_id => $c->request->param('channel'),
                customer_numbers => [@success_customers],
                operator_id => $c->session->{operator_id},
            };

            my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::Customer::CustomerCategory' });
            $job_rq->set_payload( $payload );
            my $job = $job_rq->send_job();

            $c->stash(
                job_number => $job->jobid,
            );

        } else {
            $c->stash(
                customer_numbers => $c->request->param( 'customers' ) // '',
            );
        }
    }

}
1;
