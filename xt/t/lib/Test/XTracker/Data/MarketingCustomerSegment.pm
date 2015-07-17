package Test::XTracker::Data::MarketingCustomerSegment;

use NAP::policy "tt", 'class';

use Test::XTracker::Data;
use XTracker::Constants     qw( :application );


sub create_customer_segment {
    my ( $self, $args ) = @_;

    my $schema = Test::XTracker::Data->get_schema;
    my $count  = $args->{how_many} || 1;
    my @rows;

    for my $i( 1 .. $count) {
        my $record = $schema->resultset('Public::MarketingCustomerSegment')->create({
                   name                 => $args->{name} // 'Test Segment - '.rand,
                   channel_id           => $args->{channel_id},
                   enabled              => $args->{enabled} // '1',
                   created_date         => $args->{created_date} || \'now()',
                   job_queue_flag       => $args->{job_queue_flag} || '0',
                   date_of_last_jq      => $args->{date_of_last_jq} || \'now()',
                    operator_id         => $APPLICATION_OPERATOR_ID,
                });
        print "Customer Segment Created Id/Name/Channel: ". $record->id ."/". $record->name ."/". $record->channel_id."\n";
        push (@rows, $record);
    }

    return ( wantarray ? @rows : \@rows );
}


sub link_to_customer {
    my ( $self, $segment, $customer ) = @_;


    $segment->create_related('link_marketing_customer_segment__customers',{
        customer_id => $customer->id,
    });


    return;
}

sub grab_customers {
    my ($self, $args ) = @_;

    my $limit = $args->{how_many} // 1;
    my @customers;

    for my $i (1..$limit) {
        my $customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $args->{channel_id} } );
        push @customers, {
            customer_id => $customer->id,
            customer    => $customer,
        };
    }
    return \@customers;

}

1;

