package Test::MockObject::Builder;
use strict;
use warnings;

our $VERSION = '1.00';

use Test::MockObject;

my @VALID_METHODS = qw/mock set_isa set_list/;

=head1 NAME

Test::MockObject::Builder

=head1 DESCRIPTION

This is a helper class to create structures of Test::MockObjects

=head1 PUBLIC METHODS

=head2 build

Build a Test::MockObject based on a definition hash. The hash can contain the following
 possible keys:

=head3 build keys

=head4 mock

The value should be a hashref where the keys are a list of methods to be mocked in the
mock-object, and the values returned by each. If the value of a mocked method is a
hashref, it will be interpreted as another Test::MockObject definition, which will be
built and returned

If you require an actual hashref to be a return value, wrap it in a code ref

e.g.

get_useful_hash_data => sub { return { foo => 'bar' } },

=head4 set_isa

Will call 'set_isa' on the mock-object using the value (classname) provided

=head4 set_list

Accepts a hashref of method names that should return a list. Where:
 key - name of mocked method
 value - Arrayref of values that should be returned as a list

=head4 validation_class

If a class-name is supplied, all method names created for this mock object will be
 validated against the class supplied to ensure they exist. If an attempt is made to mock
 a method that does not exist in the validation class, an exception will be thrown.

=cut

sub build {
    my ($class, $mock_object_definition) = @_;
    return $class->_build_mock_object($mock_object_definition);
}

=head4 extend

This will extend an object passed to it using Test::MockObject::Extends. The first
varaible passed should be the object to extend, the second is a mock definition hash with
the same structrue as that passed to 'build()'

=cut
sub extend {
    my ($class, $object_to_extend, $mock_object_definition) = @_;

    eval { require Test::MockObject::Extends };
        die 'Test::MockObject::Extends is required to extend objects, but does not appear to be installed' if $@;

    return $class->_build_mock_object(
        $mock_object_definition,
        Test::MockObject::Extends->new($object_to_extend)
    );
}

sub _build_mock_object {
    my ($class, $mock_object_definition, $mock_object) = @_;

    $mock_object //= Test::MockObject->new();

    # Explicitly check for a validation_class. As we need to know about that from the
    # beginning
    my $validation_class_mop;
    if(my $validation_class = delete $mock_object_definition->{validation_class}) {
        eval { require Class::MOP };
        die 'Class::MOP is required to use a validation_class, but does not appear to be installed' if $@;

        $validation_class_mop = Class::MOP::Class->initialize($validation_class);
    }

    for my $mock_method (keys %$mock_object_definition) {
        my $value = $mock_object_definition->{$mock_method};

        die sprintf('Unknown or unsupported key: "%s" in mock-object definition',
            $mock_method) unless (grep { $_ eq $mock_method } @VALID_METHODS);

        $mock_method = "_$mock_method";
        $class->$mock_method($mock_object, $value, $validation_class_mop);
    }

    return $mock_object;
}

sub _validate_mocked_method {
    my ($class, $mocked_method, $validation_class_mop) = @_;
    return unless $validation_class_mop;

    die sprintf('Method %s does not exist in validation class', $mocked_method)
        unless $validation_class_mop->find_method_by_name($mocked_method);
}

sub _mock {
    my ($class, $mock_object, $mock_defs, $validation_class_mop) = @_;

    for my $mocked_method (keys %$mock_defs) {
        $class->_validate_mocked_method($mocked_method, $validation_class_mop);

        my $mocked_value = $mock_defs->{$mocked_method};

        # If 'value' is another mock object definition (which is what we interpret a
        # hashref to be), build the mock object
        if(ref($mocked_value) eq 'HASH') {
            $mocked_value = $class->_build_mock_object($mocked_value);
        }

        # If we have not been passed a code ref, wrap the value in one
        if (ref($mocked_value) eq 'CODE') {
            $mock_object->mock($mocked_method, $mocked_value);
        } else {
            $mock_object->mock($mocked_method, sub { $mocked_value });
        }
    }
}

sub _set_isa {
    my ($class, $mock_object, $mock_class_name, $validation_class_mop) = @_;
    $mock_object->set_isa($mock_class_name);
}

sub _set_list {
    my ($class, $mock_object, $list_defs, $validation_class_mop) = @_;

    for my $mocked_method (keys %$list_defs) {
        $class->_validate_mocked_method($mocked_method, $validation_class_mop);

        $mock_object->set_list($mocked_method, @{$list_defs->{$mocked_method}});
    }
}

1;
