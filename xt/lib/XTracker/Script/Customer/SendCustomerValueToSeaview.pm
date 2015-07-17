package XTracker::Script::Customer::SendCustomerValueToSeaview;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';

with qw(
    MooseX::Getopt
    XTracker::Script::Feature::SingleInstance
    XTracker::Script::Feature::Schema
    XTracker::Script::Feature::Logger
);

use XTracker::Logfile qw(xt_logger);
use Try::Tiny;
use Moose::Util::TypeConstraints;
use List::MoreUtils qw ( uniq );

=head1 NAME

    XTracker::Script::Customer::SendCustomerValueToSeaview

=head1 SYNOPSIS

    XTracker::Script::Customer::SendCustomerValueToSeaview->invoke();

=head1 DESCRIPTION

    Pushes "Customer Value" to Seaview(BOSH) of all customer or given list of customers
    whose account urn is provided.

=cut


# Set all the attributes that we've either inherited or consumed, to not be
# exposed as an argument.
has "+$_" => ( traits => ['NoGetopt'] )
    foreach _no_get_opt_list();

subtype 'FHandle', as 'FileHandle';

coerce 'FHandle',
    from 'Str',
    via {
        IO::File->new($_, 'w')
        or die "Can't open $_: $!\n"
    };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( 'FHandle' => '=s' );

has verbose => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'v',
    documentation   => 'Provide verbose output.',
    default         => 0,
);

has dryrun => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'd',
    documentation   => 'Runs in DryRun mode.',
    default         => 0,
);

has failed_file_path => (
    is              => 'ro',
    isa             => 'FHandle',
    coerce          => 1,
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'f',
    documentation   => "File path to dump comma seperated list of failed account urn's",
);

has success_file_path => (
    is              => 'ro',
    isa             => 'FHandle',
    coerce          => 1,
    traits          => [ 'Getopt' ],
    cmd_aliases     => 's',
    documentation   => "File path to dump comma seperated list of Successful account urn's",
);

has all => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'a',
    documentation   => "Send customer Value for 'ALL' customers to Seaview",
    default         => 0,
);

has stdin => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'si',
    documentation   => "For given list of account urn's of customers provided via STDIN whose Customer Value needs to be pushed to SeaView (BOSH)  ",
    default         => 0,
);

has batch => (
    is              => 'ro',
    isa             => 'Num',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'b',
    documentation   => "Run the loop in batches of the number supplied. This option is ignored when '--all' option is used.",
    default         => 1000,
);

sub log4perl_category { return ''; }

sub invoke {
    my ($self, %args) = @_;

    $self->log_info("Starting Script");

    my @account_urn;

    # Check if account urns are keyed in at STDIN or command line.
    if ( $self->stdin ) {
        # If we've piped input
        while (my $urn = <STDIN> ) { ## no critic(ProhibitExplicitStdin)
            chomp $urn;
            push( @account_urn, split /\s+/, $urn);
        }
    } else {
        @account_urn = @{$self->extra_argv };
    }
    my $length_urn_list = scalar( @account_urn );

    if( $length_urn_list == 0 && ! $self->all ){
        $self->log_error("Please provide valid options or run the script with --help option to list usage");
        return 0;
    }

    # Delete duplicated from array if any
    @account_urn = uniq (@account_urn);

    $length_urn_list = scalar(@account_urn);
    my $customer_rs  = $self->schema->resultset('Public::Customer');
    my $success_list = {};
    my $failure_list = {};

    try {

        if( $self->all ) {
            $self->log_info("Querying Database for list of all customers who has account_urn");
            $customer_rs = $customer_rs->search ( {
                account_urn => { '!=' => undef }
            });

            $self->log_info("Pushing Customer Value to Seaview for All customers");
            my ( $success, $failure ) = $self->_push_customer_value( $customer_rs );

            # Populate success and failure list
            $success_list   = { %$success_list, %$success };
            $failure_list   = { %$failure_list, %$failure };

        } else {

            # Delete undef's, if any
            @account_urn = grep { defined $_ } @account_urn;

            $self->log_info("Query Database for given list of account urn's");


            $failure_list       =  { map { $_ => 1 } @account_urn };
            my $batch  = $self->{batch};

            while (my @urn_batch = splice(@account_urn, 0, $batch)) {

                my $rs = $customer_rs->search({
                    account_urn => { 'IN'=> \@urn_batch }
                });

                my ( $success, $failure )  = $self->_push_customer_value( $rs );

                # Populate success and failure
                $success_list = { %$success_list, %$success  };
                $failure_list = { %$failure_list, %$failure  };
            }

       }

        foreach my $key (keys(%{$success_list} ) ) {
            delete $failure_list->{$key};
        }


        # Write output to files
        if($self->failed_file_path ) {
            my $file_handle = $self->failed_file_path;
            print $file_handle join (',',  keys %{ $failure_list} )."\n";
        }

        if( $self->success_file_path ) {
            my $file_handle = $self->success_file_path;
            print $file_handle join (',',  keys %{ $success_list} )."\n";
        }

        $self->log_info( "Failed Account URN list: ".join (',', keys %{ $failure_list} ));
        $self->log_info( "Success Account URN list: ".join (',', keys %{$success_list}));

        $self->log_info(" Completed Script");

    } catch {
        $self->log_error($_);
    };

    return;
}


sub _push_customer_value {
    my $self        = shift;
    my $customer_rs = shift;

    my $success_urn = {};
    my $failed_urn = {};
    while ( my $customer = $customer_rs->next ) {
        if( $customer->account_urn ) {
            try {
                $customer->update_customer_value_in_service() unless $self->dryrun;
                $success_urn->{$customer->account_urn} = 1;
            } catch {
                my $msg = "Failed to push customer value to Seaview for account urn: ".$customer->account_urn;
                $self->log_error( $msg );
                $failed_urn->{$customer->account_urn} = 1;
            };
        } else {
            $self->log_error("Customer: ".$customer->is_customer_number. " does not have account_urn ");
        }
    } #end of while

    return ($success_urn, $failed_urn);

}

sub _no_get_opt_list {

    # Get a list of all attributes provided from MooseX::Getopt, because
    # these are the ones we want to keep.
    my %getopt_hash;
    my @getopt = MooseX::Getopt->meta->get_attribute_list;
    @getopt_hash{ @getopt } = 1;

    # Remove the MooseX::Getopt attributes from the list of attributes in the
    # current class, leaving just the ones we don't want as arguments.
    return
        grep { ! exists $getopt_hash{ $_ } }
        __PACKAGE__->meta->get_attribute_list;

}

__PACKAGE__->meta->make_immutable;

1;
