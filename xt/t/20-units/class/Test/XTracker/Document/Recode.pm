package Test::XTracker::Document::Recode;

use NAP::policy qw/ class test /;

use Test::File;
use Test::Fatal;
use File::Basename;

use Test::XT::Data::Recode;
use XTracker::Document::Recode;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

sub startup : Tests(startup) {
    my $self = shift;

    use XTracker::Printers::Populator;
    XTracker::Printers::Populator->new->populate_if_updated;
}

sub test__document_types :Tests {
    my ($self) = @_;

    my $expected_type = 'document';

    my $recode = Test::XT::Data::Recode->create_recode();

    my $recode_sheet = XTracker::Document::Recode->new(
        recode => $recode->id
    );

    is($recode_sheet->printer_type, $expected_type, "Document uses the correct printer type");

    lives_ok( sub{
        $recode_sheet->print_at_location($self->location_with_type($expected_type)->name);
    }, "Print document works ok");

    my ($basename, $dirs) = fileparse($recode_sheet->filename, qr{\.[^.]*});

    my @expected_files = map { "${basename}.${_}" } qw/html pdf ps/;

    for my $file (map { $dirs . $_ } @expected_files) {
        file_exists_ok($file);
        file_not_empty_ok($file);
    }
}

sub test__exceptions :Tests {
    my ($self) = @_;

    my $recode = Test::XT::Data::Recode->create_recode();

    # Test invalid recodeID
    like(
        exception { XTracker::Document::Recode->new(
            recode        => $recode->id + 1
        )},
        qr|^Attribute \(recode\) does not pass the type constraint|,
        "Can't instantiate with a nonexistent recode ID"
    );
}
