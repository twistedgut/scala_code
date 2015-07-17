package XT::JQ::Worker;

use Moose;
use Carp;

#use namespace::clean -except => 'meta';

# Hide the Moose/Class::MOP things from the attr/role validation callstacks
$Carp::Internal{'Moose::Meta::Class'} = 1;
$Carp::Internal{'Moose::Meta::Attribute'} = 1;
$Carp::Internal{'Moose::Meta::Role'} = 1;
$Carp::Internal{'Moose::Meta::Role::Application'} = 1;
$Carp::Internal{'Moose::Meta::Role::Application::ToClass'} = 1;
$Carp::Internal{'Class::MOP::Class'} = 1;
$Carp::Internal{'Class::MOP'} = 1;
$Carp::Internal{'Moose::Object'} = 1;
$Carp::Internal{'Moose::Util'} = 1;
$Carp::Internal{'Moose'} = 1;

extends 'Moose::Object', 'XT::Common::JQ::Worker';

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str HashRef Bool );
use MooseX::Types::Structured           qw( Dict );

use XTracker::Config::Local             qw( config_var );
use XTracker::Database qw( get_schema_using_dbh xtracker_schema );
use XTracker::Logfile               qw( xt_logger );

my $logger  = xt_logger();

# override Failed Job function name with one for DC
has '+failedjob_function'   => (
    default => 'XT::JQ::DC::FailedJob'
);

# general hash reference to pass data around functions
# particulary between 'check_payload' & 'do_the_task'
has data => (
    is          => 'rw',
    isa         => 'HashRef',
    default     => sub { {} }
);

has dbh => (
    is => 'ro',
    isa => 'DBI::db',
    lazy_build => 1
);

has schema => (
    is => 'ro',
    isa => 'DBIx::Class::Schema',
    lazy_build => 1
);

sub _build_dbh {
    my $self = shift;
    return $self->schema->storage->dbh;
}

sub _build_schema {
    my $self = shift;
    # If you pass in a dbh to the constructor, we use it as it is, and we wrap
    # a schema around it. If you do not pass it in, when we call ->dbh, its
    # builder calls ->schema, so this builder gets called, ->has_dbh returns
    # false, so we get a schema, and _build_dbh gets the dbh from inside it.
    return get_schema_using_dbh($self->dbh, 'xtracker_schema') if $self->has_dbh;
    return xtracker_schema;
}

before 'work' => sub {
    my $class = shift;
    my $job = shift;
    $logger->info('Starting job: '.$job->jobid.': '.$class);
};

after 'work' => sub {
    my $class = shift;
    my $job = shift;
    $logger->info('Finished job: '.$job->jobid.': '.$class);
};

no Moose;

1;

__END__

=head1 NAME

XT::JQ::Worker - A moosified baseclass for Job workers

=head1 DESCRIPTION

Since L<XT::Common::JQ::Worker> is used by Fulcrum and DC, it seemed like too
much hassle to force Moose on another code base, so this class is here to do
it only for the the Fulcrum code base.

=head1 SYNOPSIS

 package XT::JQ::Central::Foo;

 use Moose;
 use MooseX::Types::Moose qw(Str Int Num);
 use MooseX::Types::Structured qw(Dict Tuple);

 use namespace::clean -except => 'meta';

 with 'XT::JQ::Worker';

 has remote_targets => ( isa => Tuple[Str], required => 1);

 no Moose;

 sub do_the_task { ... }

 sub check_job_args {
     my ($class, $job) = @_;
     $class->new($job->arg);

     # Will die if the attrs aren't there:
     #   Attribute (dest_channel) does not pass the type constraint because: Validation \
     #   failed for 'Int' failed with value a
 }


