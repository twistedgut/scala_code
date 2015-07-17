package XT::JQ::DC::Receive::NAPEvents::CustomerSegment;

use Moose;
use Readonly;

use Data::Dump qw/pp/;
use XTracker::Logfile qw( xt_logger );

use MooseX::Types::Moose qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured qw( Dict Optional );

use XTracker::EmailFunctions qw/send_internal_email/;
use Try::Tiny;

use namespace::clean -except => 'meta';


extends 'XT::JQ::Worker';

Readonly my $IGNORED_LIST_EMAIL_TEMPLATE  => "email/internal/intheboxpromotion.tt";


has payload => (
    is => 'ro',
    isa => Dict[
        customer_segment_id     => Int,
        current_user            => Int,
        customer_list           => ArrayRef[Int],
        action_name             => Optional[Str],
    ],
    required => 1,
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;

    my $schema = $self->schema;

    return try {

        $schema->txn_do( sub {
            my $segment = $schema->resultset('Public::MarketingCustomerSegment')->find(
                $self->payload->{customer_segment_id}
            );

            my $action = 'add';
            if( $self->payload->{action_name} ) {
                $action =  lc( $self->payload->{action_name} );
            }

            if( $action eq 'add' || $action eq 'delete') {

                my $channel_id = $segment->channel_id;
                my @action_list = ();
                my @ignored_list = ();

                # do in batches
                my $total_in_batch = 10000;
                my $counter = 0;
                my $max = $counter + ( $total_in_batch - 1);

                $max = $#{$self->payload->{customer_list}} if $total_in_batch > $#{$self->payload->{customer_list}};
                while ( my @customer_batch = @{$self->payload->{customer_list}} [ $counter..$max ] ) {
                    my $customer_rs = $schema->resultset('Public::Customer')->search( {
                        is_customer_number =>  { 'IN' => \@customer_batch },
                        channel_id         => $channel_id,
                    });
                    while ( my $customer = $customer_rs->next ) {

                        if ( $action eq 'add' ) {
                            $segment->find_or_create_related('link_marketing_customer_segment__customers',{
                               customer_id => $customer->id
                            });
                        }  else {
                            $customer->link_marketing_customer_segment__customers->delete;
                        }
                        push(@action_list, $customer->is_customer_number);
                    }

                    $counter +=$total_in_batch;
                    $max = $counter + ( $total_in_batch - 1);
                    $max = $#{$self->payload->{customer_list}} if ( $max > $#{$self->payload->{customer_list}});

                    # Commit in batches of 10,000 ($total_in_batch)
                    # else too long transactions kills the job queue deamon,
                    $schema->txn_commit;
                    $schema->txn_begin;

                }

                # get the difference between 2 arrays
                my %hash_customer = map {$_, 1} @action_list;
                @ignored_list = grep {!$hash_customer{$_}} @{$self->payload->{customer_list}};

                if ( scalar(@action_list) > 0 ) {
                    $segment->create_related( 'marketing_customer_segment_logs', {
                        operator_id     => $self->payload->{current_user},
                    } );
                };

                if( scalar(@ignored_list) > 0 ) {
                    $self->logger->info( "Ignored Customer List: ".join (',',@ignored_list). " customers as invalid ids");
                }
                #send an email to operator for ignored list
                my @new_list = ($#ignored_list < 1000 )? @ignored_list : @ignored_list[0..999];
                #send email
                if( scalar @new_list > 0 ) {
                    # operator email
                    my $operator = $schema->resultset('Public::Operator')->find($self->payload->{current_user});

                    send_internal_email(
                        to => $operator->email_address,
                        subject => "Ignored Customer Numbers for Segment  - ". $segment->name,
                        from_file => {
                            path => $IGNORED_LIST_EMAIL_TEMPLATE,
                        },
                        stash => {
                            ignored_list => \@new_list,
                            template_type => 'email',
                            total_invalid  => scalar(@ignored_list),
                            operator       => $operator,
                        },
                    ) if $operator;
                }
            } else {
                $segment->link_marketing_customer_segment__customers->delete;
                $self->logger->info( "Deleted All customers from Customer Segment ". $segment->name );
            }

            # Reset Joq queue flag
            $segment->update({ job_queue_flag => 'false' });
            $self->logger->info("Job Completed");

        });
        # this was the behaviour before replacing TryCatch with
        # Try::Tiny, I don't want to change it, although it looks not
        # very sensible
        return "";
    }
    catch {
        my $error = $_;
        $self->logger->error(qq{Failed job with error: $error});
        $job->failed( $error );
        return;
    };
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}


1;

__END__

=head1 NAME

XT::JQ::DC::Receive::NAPEvents::CustomerSegment

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload = {
       customer_segment_id  => $segment_id,
       current_user         => $operator->id,
       customer_ids         => 'Array ref of customer numbers',
       action_name          => 'add/delete/delete_all',
    };


From the given Array of customer_numbers it checks if the customer channel is same as marketing_customer_segment channel. If
yes then it links/deletes customer to/from segment else it ignores the customer.

=cut
