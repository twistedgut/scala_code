package XT::JQ::DC::Receive::Customer::CustomerCategory;

use Moose;

use MooseX::Types::Moose        qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured    qw( Dict Optional );

use XTracker::Logfile           qw( xt_logger );


use Try::Tiny;
use Readonly;
use XTracker::Constants::Seaview    qw( :seaview_failure_messages );
use DateTime;
use XTracker::Database::Operator    qw( get_operator_by_id );
use XTracker::EmailFunctions qw( send_internal_email );
use DateTime;

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        customer_category_id    => Int,
        channel_id              => Int,
        customer_numbers        => ArrayRef[Int],  # Array of public facing customer numbers
        operator_id             => Int,
    ],
    required => 1,
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);

has operator => (
    is => 'rw',
);

has channel => (
    is => 'rw',
);

has customer_category => (
    is => 'rw',
);

has now => (
    is => 'rw',
    lazy_build => 1,
);

has now_string => (
    is => 'rw',
    lazy_build => 1,
);

sub _build_now {
    my $self = shift;

    return $self->schema->db_now();
}

sub _build_now_string {
    my $self = shift;

    return $self->now->ymd('-').' '.$self->now->hms(':');
}

Readonly my $CUSTOMER_CATEGORY_UPDATE_TEMPLATE => 'email/internal/customer_category_update.tt';

sub do_the_task {
    my ($self, $job) = @_;

    my $schema = $self->schema;
    my $channel_id  = $self->payload->{channel_id};

    # get all customer numbers from controller
    my @all_customer_numbers = @{$self->payload->{customer_numbers}};
    my @success_customers;
    my @fail_customers;

    # Bulk update function
    foreach my $customer_nr (@all_customer_numbers) {
        try {
            my $customer = $schema->resultset('Public::Customer')->find({
                is_customer_number => $customer_nr,
                channel_id => $channel_id,
            });
            my $update_xt = 1;
            try {
                $customer->update_seaview_account( $self->payload->{customer_category_id} );
            } catch {
                $update_xt = 0 unless /${SEAVIEW_FAILURE_MESSAGE__ACCOUNT_NOT_FOUND_FOR_URN}/i;
                $self->logger->warn( "Customer category Seaview update for customer ".$customer_nr.", failed: ".$_."\nUpdate XT value is ".$update_xt );
                push @fail_customers, {is_customer_number => $customer_nr, error => $_}         if ($update_xt == 0);
            };
            if($update_xt) {
                $customer->update({category_id => $self->payload->{customer_category_id}});

                push @success_customers, {
                    is_customer_number  => $customer->is_customer_number,
                    display_name        => $customer->display_name,
                    email               => $customer->email,
                }
            };

        } catch {
            my $error_message = "Customer category update for customer ".$customer_nr." failed: ".$_;
            push @fail_customers, {is_customer_number => $customer_nr, error => $error_message};
            $self->logger->error( $error_message );
        };
    }

    $self->_send_update_email({
            success_count           => scalar(@success_customers),
            successes               => \@success_customers,
            failed_customer_list    => \@fail_customers,
    });

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    my $schema = $self->schema;

    # check operator, channel and customer category ids are valid

    my $operator = $schema->resultset('Public::Operator')->find($self->payload->{operator_id});
    my $channel = $schema->resultset('Public::Channel')->find($self->payload->{channel_id});
    my $customer_category = $schema->resultset('Public::CustomerCategory')->find($self->payload->{customer_category_id});

    unless ( $operator ) {
        return ('Operator ID '.$self->payload->{operator_id}.' does not exist');
    }

    $self->operator( $operator );

    # channel
    unless ( $channel ) {
        return ('Channel ID '.$self->payload->{channel_id}.' does not exist');
    }

    $self->channel( $channel );

    # customer category
    unless ( $customer_category ) {
        return ('Customer Category ID '.$self->payload->{customer_category_id}.' does not exist');
    }
    $self->customer_category( $customer_category );
    return ();
}

sub _send_update_email {
    my ($self,$args) = @_;

    my $dt = $self->now;

    return send_internal_email(
        to => $self->operator->email_address,
        subject => "Customer Category Updates for ".$self->channel->name." at ".$self->now_string,
        from_file => {
            path => $CUSTOMER_CATEGORY_UPDATE_TEMPLATE,
        },
        stash => {
            template_type           => 'email',
            operator                => $self->operator->name,
            customer_category       => $self->customer_category->category,
            channel                 => $self->channel->name,
            date                    => $dt->ymd('-'),
            time                    => $dt->hms(':'),
            success_count           => $args->{success_count},
            successes               => $args->{successes},
            failed_customer_list    => $args->{failed_customer_list},
        },
    );
}

1;

__END__

=head1 NAME

XT::JQ::DC::Receive::Customer::CustomerCategory

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload    = {
        customer_category_id    => $customer_category_id,   # Target customer category
        channel_id              => $channel_id,             # Channel ID
        customer_numbers        => $customer_numbers,       # Customer numbers to be updated
        operator_id             => $operator_id,            # Id of user that requested the customer category update
    };

=cut

