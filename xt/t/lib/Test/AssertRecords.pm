package Test::AssertRecords;
use strict;
use warnings;

use Module::Pluggable::Singleton;
use Carp qw/croak/;
use Test::More 0.98;
use Data::Dump qw/pp/;

# FIXME: remove dependancy
use Test::XTracker::Utils;


sub run {
    my($self,$dir,$schema,$class) = @_;
    my $plugin = $self->find($class);
    my $file = $self->_class_to_file($dir,$class);

    croak "Cannot find module for $class" if (!defined $plugin);

    # FIXME: test schema namespace $SCHEMA_NAMESPACE
    my $rs = $self->_test_schema($schema,$class);

    if ($ENV{WRITE_DATA}) {
        note "write file: ". $file;
        $plugin->write_file($rs,$file,$self->_class_simplified($class));
    } else {
        $self->_test_file( $schema,$plugin,$class,$file );

    }
}

sub _test_schema {
    my($self,$schema,$class) = @_;
    my $namespace = $self->schema_namespace;
    isa_ok($schema, $namespace, 'got schema');

    my $rs = $schema->resultset($class);
    isa_ok($rs, "${namespace}::ResultSet::${class}",
        'got resultset');

    return $rs;
}

sub _class_to_file {
    my($self,$dir,$class) = @_;
    my $filename = $self->_class_simplified($class);

    $filename = "${dir}/${filename}.json";
    note "test data file: $filename";

    my $file = Path::Class::File->new( $filename );
    isa_ok($file, 'Path::Class::File', 'file exists');

    return $file;
}

sub _class_simplified {
    my($self,$class) = @_;

    my $filename = lc($class);
    $filename =~ s/::/_/g;

    return $filename;
}

sub _test_file {
    my($self,$schema,$plugin,$class,$file) = @_;

    my $data = Test::XTracker::Utils->slurp_json_file( $file );

    isa_ok($data, 'HASH',
        'data file is hashref');

    my $key = $self->_class_simplified($class);
    isa_ok($data->{$key}, 'ARRAY',
        "has $key field with elements")
        || note ref($data);


    $plugin->test_assert_mapping($class,$schema,$data->{$key});
    if ($plugin->can('test_assert')) {
        $plugin->test_assert($schema,$data->{$key});
    }
}

1;
