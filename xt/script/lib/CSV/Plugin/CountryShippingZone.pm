package CSV::Plugin::CountryShippingZone;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose;


with 'CSV::Base';

sub parse_line {
    my($self,$arr) = @_;
    my $result = $self->result;
    my $code = $arr->[0];
    my $rec = {
        code => $arr->[0],
        name => $arr->[1],
        zone => $arr->[2],
    };


    if (!defined $self->result) {
        $result = { $code => [ $rec ] };
        $self->result( $result );
    } else {
        my $dat = $result->{$code};

        if (defined $dat && ref($dat) ne 'ARRAY') {
            $dat = [ $dat ];
        }
        
        push @{$dat}, $rec;
        $rec = $dat;

        $result->{$code} = $rec;
    }


}

1;
