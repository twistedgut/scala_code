package Test::XT::Feature::Recodes;

use Moose::Role;
use MooseX::Params::Validate;

use Test::More;

#
# Recode tests
#
use XTracker::Config::Local;
use XTracker::PrintFunctions; # for get_printer_by_name
use XTracker::PrinterMatrix;

use List::MoreUtils 'any';

sub test_printing__recode_doc {
    my ($self, %args) = validated_hash( \@_,
        print_directory => { isa => 'Test::XTracker::PrintDocs' },
        variants => { isa => 'HashRef' },
    );

    $self->announce_method;

    # We should have one recode putaway sheet for each new variant
    my @print_docs = $args{print_directory}->wait_for_new_files(
        files => scalar keys %{$args{variants}},
    );

    foreach my $doc (@print_docs) {
        like ($doc->{filename}, qr/^recode\-\d+/, "Recode doc created");
    }

}

1;
