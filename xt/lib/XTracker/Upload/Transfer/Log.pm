package XTracker::Upload::Transfer::Log;

use strict;
use warnings;
use vars qw($VERSION);
$VERSION = 0.01;

use Log::Dispatch 2.00;
use base qw(Log::Dispatch::Output);

use DBI;


sub new {

    my($proto, %params) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;
    $self->_basic_init(%params);
    $self->_init(%params);

    return $self;
}


sub _init {
    my ($self, %params) = @_;

    if ($params{dbh}) {
        $self->{dbh} = $params{dbh};
    }
    else {
        $self->{dbh} = DBI->connect(@params{qw(datasource username password)})
            or die $DBI::errstr;
        $self->{_mine} = 1;
    }

    $self->{table} = $params{table} || 'upload.transfer_log';
    $self->{sth} = $self->create_log_statement;
}


sub create_log_statement {

    my $self    = shift;
    my $table   = $self->{table};

    my $sql
        = qq{INSERT INTO $table (transfer_id, operator_id, product_id, transfer_log_action_id, level, message)
                VALUES (?, ?, ?, ?, ?, ?)
        };

    return $self->{dbh}->prepare($sql);
}


sub log_message {

    my $self            = shift;
    my $db_log_ref      = shift;
    my $log_data_ref    = shift;

    my $operator_id = defined $db_log_ref->{operator_id} ? $db_log_ref->{operator_id} : 1;
    my $transfer_id = $db_log_ref->{transfer_id};
    my $product_id  = $log_data_ref->{product_id};
    my $action_id   = $log_data_ref->{action_id};
    my $level       = defined $log_data_ref->{level} ? $log_data_ref->{level} : 'info';
    my $message     = defined $log_data_ref->{message} ? $log_data_ref->{message} : '';

    $self->{sth}->execute($transfer_id, $operator_id, $product_id, $action_id, $level, $message);

}


sub DESTROY {
    my $self = shift;
    if ($self->{_mine} && $self->{dbh}) {
        $self->{dbh}->disconnect;
    }
}


1;

__END__

