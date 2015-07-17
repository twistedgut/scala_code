package Test::XT::Domain::Returns;
use NAP::policy qw/class test/;
BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::DBSamples';
};

use Test::MockObject::Builder;

use Test::Exception;
use Test::XTracker::Data;

use XT::Domain::Returns;

use XTracker::Constants::FromDB qw( :return_status );

sub test___create_return_prevent_duplicate_sample :Tests {
    my ($self) = @_;

    my $sample_shipment = $self->db__samples__create_shipment();

    my $returns_logic = Test::MockObject::Builder->extend(XT::Domain::Returns->new( schema => $self->schema ), {
        mock => { _add_return_items => 1 } # Mock this one out as it is irrelevant
    });

    my $return;
    lives_ok {
        $return = $returns_logic->_create_return({
            shipment_id             => $sample_shipment->id,
            this_is_a_sample_return => 1,
            operator_id             => Test::XTracker::Data->get_application_operator_id,
            pickup                  => 1
        }
    ) } 'Creation of sample shipment return succeeds';

    throws_ok {
        $returns_logic->_create_return({
            shipment_id             => $sample_shipment->id,
            this_is_a_sample_return => 1,
            operator_id             => Test::XTracker::Data->get_application_operator_id,
            pickup                  => 1
        })
    } qr/A return already exists for sample shipment/, 'Creation of duplicate sample shipment return fails';

    $return->update( {return_status_id => $RETURN_STATUS__CANCELLED });

    lives_ok {
        $return = $returns_logic->_create_return({
            shipment_id             => $sample_shipment->id,
            this_is_a_sample_return => 1,
            operator_id             => Test::XTracker::Data->get_application_operator_id,
            pickup                  => 1
        }
    ) } 'Creation of sample shipment return succeeds';
}
