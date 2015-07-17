use NAP::policy 'test';
use Expect;

for my $test (
        {
            name    => 'Run with just location parameter',
            setup   => {
                params => '--location nh5',
                user_input => [],
            },
            result => {
                expected_outputs => [
                    qr{Setting up printers for (\w+) in location: nh5},
                    qr{Updating /etc/cups/printers.conf...done},
                    qr{Updating /etc/hosts...done}
                ],
                invalid_outputs => [

                ],
            },
        },
        {
            name    => 'Run with location and skiphosts parameters',
            setup   => {
                params => '--location nh5 --skiphosts',
                user_input => [],
            },
            result => {
                expected_outputs => [
                    qr{Setting up printers for (\w+) in location: nh5},
                    qr{Updating /etc/cups/printers.conf...done},
                ],
                invalid_outputs => [
                    qr{Updating /etc/hosts...done}
                ],
            },
        },
        {
            name    => 'Run without location (expect to be prompted)',
            setup   => {
                params => '',
                user_input => [
                    'a',
                    '',
                    '',
                    '',
                    '',
                    ''
                ]
            },
            result => {
                expected_outputs => [
                    qr{Where are the printers you are configuring?},
                    qr{IP address for small label printers},
                    qr{Setting up printers for (\w+) in location: nh5},
                    qr{Updating /etc/cups/printers.conf...done}
                ],
                invalid_outputs => [

                ],
            },
        }
    ) {

    subtest $test->{name} => sub {

        # Always do a 'dummy' run, so that we don't actually try to make permanent changes to the system,
        # and force the script to run, whatver the XT config says
        my $command = "$ENV{XTDC_BASE_DIR}/script/DAVE-QA/printer-setup.pl $test->{setup}{params} --dummyrun --force";

        note("Command: $command");

        my $expect = Expect->new();

        my @output;

        # Capture stout logging so that we can interrogate it later
        $expect->log_file(sub {
            push @output, shift;
        });
        # Don't print to actual stdout (as it just creates noise)
        $expect->log_stdout(0);

        $expect->spawn($command) or die "Can not spawn $command: $!\n";

        for my $input (@{$test->{setup}->{user_input}}) {
            $expect->send($input . "\n");
        }

        $expect->soft_close();

        for my $expected_output (@{$test->{result}->{expected_outputs}}) {
            ok((grep { $_ =~ $expected_output } @output), "Expected output '$expected_output' found.");
        }

        for my $invalid_output (@{$test->{result}->{invalid_outputs}}) {
            ok(!(grep { $_ =~ $invalid_output } @output), "Invalid output '$invalid_output' not found.");
        }
    };
}

done_testing();