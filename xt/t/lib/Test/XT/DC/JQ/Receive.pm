=head1 NAME

 Test::XT::DC::JQ::Receive - useful subroutines for testing receiving jobs

=head1 SYNOPSIS

 use Test::XT::DC::JQ::Receive qw(send_job get_channels redefine_db_connection);

 Payload has to constraint to the valid format specified by the
 receive_module itself.

 my $payload = {
        action  => '<someaction>',
        pid1    => 123,
        pid2    => 321,
        ...
 };

 send_job( $payload, 'XT::JQ::DC::Receive::<Module>' );

=head1 EXPORTED SUBROUTINES

=cut

package Test::XT::DC::JQ::Receive;

use NAP::policy "tt",'test','exporter';

use Test::MockObject;
use Test::XTracker::Data;

use XTracker::Database ();

use Sub::Exporter;
Sub::Exporter::setup_exporter({
  exports => [qw(
    send_job
    get_channels
    redefine_db_connection
  )],
});

my $schema;
BEGIN {
  $schema = Test::XTracker::Data->get_schema;
  isa_ok( $schema, 'XTracker::Schema' );
}

=head2 send_job($payload, $funcname)

 Run the 'do_the_task' on a mocked job having the provided payload ($payload)
 and being of type $funcname

=cut

sub send_job {
    my ($payload, $funcname) = @_;

    my $fake_job = _setup_fake_job();
    my $job = $funcname->new({ payload => $payload, schema => $schema });
    isa_ok($job, $funcname);

    my @errstr = $job->check_job_payload($fake_job);
    die @errstr if scalar @errstr;
    $job->do_the_task( $fake_job );
    return $fake_job;
}


=head2 send_job($payload, $funcname)

 Redefines the db connection in order to grab the mocked dbh.
 INPUT: hash containing whatever key/value DBD::Mock accepts.
 OUTPUT: the mocked dbh

=cut

sub redefine_db_connection {
    my ($mock_obj_params) = @_;

    my $original__db_connection = \&XTracker::Database::db_connection;
    my $mock_web_dbh;

    my $redefined_sub = sub {

        die 'cannot connect' if $mock_obj_params->{mock_connect_fail};

        my $dbh = $original__db_connection->( @_ );
        $mock_web_dbh = $dbh;

        foreach my $mock_param (keys %{$mock_obj_params}) {
            $mock_web_dbh->{$mock_param} = $mock_obj_params->{$mock_param};
        }

        return $dbh;
    };

    {
     no warnings 'redefine';
     *XTracker::Database::db_connection = \&$redefined_sub;
    }
    return $mock_web_dbh;
}

=head2 get_channels

 Get an array containing all the available channels' ids.

=cut

sub get_channels {
    return map { $_->id } $schema->resultset('Public::Channel')->search({},{order_by => 'id'})->all;
}

# setup a fake TheSchwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );

    # mocking the failed() method to return the failing reason
    $fake->mock( 'failed' => sub { $_[0]->{failed} = $_[1] } );

    return $fake;
}

1;
