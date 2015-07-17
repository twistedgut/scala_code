package XTracker::Database::Row;
use NAP::policy "tt";

use DateTime::Format::Pg;
use Carp;

use XT::Data::DateStamp;

sub query_sql { croak("Abstract: query_sql") }

sub new {
    my ($class, $args) = @_;
    return bless { %$args }, $class;
}

sub each_row {
    my ($class, $args) = @_;

    my $dbh = $args->{schema}->storage->dbh;
    my $sth = $dbh->prepare($class->query_sql);

    $sth->execute( @{$args->{query_params}} );
    while ( my $db_row = $sth->fetchrow_hashref() ) {
        my $row = $class->new($db_row);

        # TODO: eval cage
        $row->inflate( $row->inflated_columns() );
        $args->{each_sub}->( $row, { dbh => $dbh, schema => $args->{schema} } );
    }

    return 1;
}

sub inflate {
    my ($self, $key_inflate_method) = @_;
    my $class = ref($self);

    for my $key (keys %$key_inflate_method) {
        my $method = $key_inflate_method->{$key};
        $self->{$key} = $class->transform($self->{$key}, $method);
    }
}

sub transform {
    my ($class, $value, $method) = @_;

    my $method_sub = {
        DateTime => sub {
            my $datetime_string = shift or return undef;
            DateTime::Format::Pg->parse_datetime( $datetime_string );
        },
        DateStamp => sub {
            my $datetime_string = shift or return undef;
            XT::Data::DateStamp->from_datetime(
                DateTime::Format::Pg->parse_datetime( $datetime_string ),
            );
        },
    };
    my $sub = $method_sub->{$method} or croak("Unknown transformation ($method)\n");

    return $sub->($value);
}
