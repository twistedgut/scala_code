package Test::XT::DC::Messaging::Producer::PRL::PrepareStockFile;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
# Add a RunCondition if you add PRL specific tests (which seems
# unlikely to be needed)

use XT::DC::Messaging::Producer::PRL::PrepareStockFile;

sub clean_id : Tests {
    my ($self) = @_;

    my $class = "XT::DC::Messaging::Producer::PRL::PrepareStockFile";

    is(
        $class->clean_id( q{abc123} ),
        "abc123",
        "Simple value unchanged",
    );

    note "Invalid chars given to use by Dematic (see DCA-2519), plus single quote";
    is(
        $class->clean_id( q{abc\\/:*?"<>| "123':} ),
        "abc123",
        "All invalid chars stripped out",
    );
}

