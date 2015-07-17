#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt",     'test';

use Test::XTracker::LoadTestConfig;

use XTracker::Config::Local qw( config_var );

# sick of bail-outs halfway through the tests I decided to add "required write
# permission" as a test that's run early in the process - CCW

# from t/dc2ca/ca_state_switch.t
#   Hard coded dirs in XT that we need to write to. Just check them for now.
my $tt_cache=config_var('SystemPaths','tt_compile_dir');
for ($tt_cache, "$tt_cache/opt") {
    if (-d $_) {
        BAIL_OUT("cant write to $_: $!") if -d $_ && ! -w $_ || !(-d $_);
    }
    else {
        mkdir $_
            || BAIL_OUT("can't create $_: $!");
    }
}


# directories that have BAIL_OUT in the test-suite somewhere

# check there is a config value for a list of directories, these
# directories will then be tested that they can be written to
my @paths_to_find = qw(
    tt_compile_dir
    xmlproblem_dir
    xmlproc_dir
    xmlwaiting_dir
    barcode_dir
    manifest_pdf_dir
    manifest_txt_dir
    document_dir
    document_temp_dir
    document_label_dir
    document_rtv_dir
    routing_dir
    routing_schedule_incoming_dir
    routing_schedule_ready_dir
    routing_schedule_processed_dir
    routing_schedule_failed_dir
    esp_base_dir
    esp_incoming_dir
    esp_responsys_dir
    search_base_dir
    search_order_by_designer_results_dir
);
foreach my $dir ( @paths_to_find ) {
    BAIL_OUT("can't find a value for directory in config: '${dir}'")
                    if ( !config_var( 'SystemPaths', $dir ) );
}

my $xtdc_base_dir = config_var('SystemPaths','xtdc_base_dir');

foreach my $dir (
    "$xtdc_base_dir/root/static/print_docs",
    "$xtdc_base_dir/root/static/print_docs_tmp",

    map { config_var('SystemPaths',$_) } @paths_to_find,
) {
    BAIL_OUT("cant write to $dir : $!") if -d $dir && ! -w $dir || !(-d $dir);
    ok(-w $dir, $dir);
}

done_testing;
