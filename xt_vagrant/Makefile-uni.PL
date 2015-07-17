# vim: noexpandtab shiftwidth=8
use inc::Module::Install;
use lib 'lib';

=head1 NAME

Makefile.PL

=head1 CHANGES

Lee added:

=over 4

=item APACHE_TEST_PORT

If set, will change the names of the databases used by
XTDC, for testing on Hudson. Names will be the same as
the value of C<APACHE_TEST_PORT>, prefixed with C<dc_>
and C<jq_> for XTDC and JobQueue, respectively.

=item XTDC_CREATE_DBS

Will (eventually) cause a minimal test DB to be built.

Currently just prevents the DB being patched.

=back

=cut

# write the VERSION file from the latest in evil creations
BEGIN {
    `script/deploy/get_unicorn_version.sh`;
}

use XTracker::Version;
use warnings;
use version;

my $distname = 'xt-uni';
my $version = $XTracker::Version::VERSION;

name $distname;

license "Private, restricted commercial. Copyright reserved.";

tests_recursive;


sub MY::postamble {
    my $postamble = <<'__MAKE_FRAG__';
.PHONY: tags

tags:
	ctags -f tags --recurse --totals \
		--exclude=blib \
		--exclude=.svn \
		--exclude='*~' \
		--exclude='root/static/images' \
		--languages=Perl --langmap=Perl:+.t \

# Create the dir structure that will hold the RPM build
CWD = $(shell pwd)
rpmdir:
	rm -rf .rpmbuild || true
	mkdir -p \
		.rpmbuild/SOURCES \
		.rpmbuild/RPMS \
		.rpmbuild/RPMS/`uname -i` \
		.rpmbuild/SRPMS \
		.rpmbuild/BUILD \
		.rpmbuild/tmp \
		.rpmbuild/scratch

# Create and populate the RPM spec file with some defaults
$(DISTNAME).spec: $(DISTNAME).spec.in Makefile
	( echo "Version: $(VERSION)";\
	echo "Source: $(DISTNAME)-$(VERSION).tar";\
	echo "BuildRoot: $(CWD)/.rpmbuild/tmp/%{name}-%{version}-%{release}-build";\
	echo "Name: $(DISTNAME)";\
	) > $@
ifdef	FASTER_WRONGER_RPMS
	echo "AutoReqProv: no" >> $@
endif
	cat $< >> $@

install_rpm_deps : $(DISTNAME).spec.in Makefile
	$(PERL) -ane '/Requires:/ and print $$F[1] . ( $$F[2] eq "=" ? "-$$F[3]" : "" ) . "\n"' *.spec.in \
		| xargs sudo yum install -y

rpm : rpmdir $(DISTNAME).spec Makefile
	git archive --output=.rpmbuild/SOURCES/$(DISTVNAME).tar --prefix=$(DISTVNAME)/ HEAD

	rpmbuild -bb --clean \
	        --define "VERSION $(VERSION)" \
		--define "_topdir $(CWD)/.rpmbuild" \
		--define "_packager `perl -le 'print +(getpwuid($$>))[0]'`" \
		--define "_tmppath $(CWD)/.rpmbuild/tmp" \
                --define "_githash $(GIT_HASH)" \
		$(DISTNAME).spec
	@echo
	@echo rpm file created.
	@echo Contents can be checked by invoking
	@echo rpm -qlip /path/to/rpmfile.rpm \| less

#
# Part of the configuration section
#

# Dynamic app properties
# These can be overridden at make time


JQ_DB = job_queue
ifdef XTDC_JQ_TEST_DBNAME
  JQ_DB = $(XTDC_JQ_TEST_DBNAME)
endif
# This block makes redundent the other Hudson-specific blocks introduced 2010/06/30
ifdef APACHE_TEST_PORT
    DC_DB = dc_$(APACHE_TEST_PORT)
    JQ_DB = jq_$(APACHE_TEST_PORT)
    override XTDC_XTRACKER_TEST_DBNAME=$(DC_DB)
    override XTDC_JQ_TEST_DBNAME=$(JQ_DB)
    override XTDC_JQ_TEST_DSN=dbi:Pg:dbname=$(JQ_DB);host=localhost

    export XTDC_XTRACKER_TEST_DBNAME:=	$(DC_DB)
    export XTDC_JQ_TEST_DBNAME:=		$(JQ_DB)
    export XTDC_JQ_TEST_DSN:=			dbi:Pg:dbname=$(JQ_DB);host=localhost

    $(info Have set database names based on APACHE_TEST_PORT $(APACHE_TEST_PORT) :)
    $(info  * XTDC_XTRACKER_TEST_DBNAME = $(XTDC_XTRACKER_TEST_DBNAME))
    $(info  * XTDC_JQ_TEST_DBNAME       = $(XTDC_JQ_TEST_DBNAME))
    $(info  * XTDC_JQ_TEST_DSN          = $(XTDC_JQ_TEST_DSN))
endif



# We expect the following to be overrided when running as part of the RPM install process
NAP_PROPERTIES_FILE = $(TEMPLATE_SOURCE_DIR)/nap_dev.properties
LOCAL_PROPERTIES_FILE =
XTDC_BASE_DIR = $(CWD)
XTDC_CONF_DIR = $(CWD)/xtdc
XTDC_LOGS_DIR = $(CWD)/logs
XTDC_USER = $(USER)
XTDC_USER_JQ = $(USER)
XT_DC_MESSAGING_CONFIG = $(XTDC_CONF_DIR)/xt_dc_messaging.conf
XTDC_PROPERTIES_FILE = $(XTDC_CONF_DIR)/xtracker.properties
XTDC_PATH_PROPERTIES_FILE = $(XTDC_CONF_DIR)/xtracker_path.properties
APP_VERSION = master
RPM=0

# This one lives in limbo
JAVASCRIPT_BASE_DIR =/opt/xt/javascript

# Directories for testing artifacts
TEST_ARTIFACTS_DIR = $(CWD)/t/tmp/amq_dump_dir $(CWD)/t/tmp/xtwms_receipts $(CWD)/t/tmp/ravniwms_receipts $(CWD)/t/tmp/prl_receipts $(CWD)/t/tmp/custcred

# Where to find the template config files
TEMPLATE_SOURCE_DIR := $(CWD)/conf

# Hardcoded list of templated config files less the virtual host
XTDC_CONF_TEMPLATES = \
wms_activemq_XTDC1.conf.tt \
wms_activemq_XTDC2.conf.tt \
wms_activemq_XTDC3.conf.tt \
xt_dc_messaging.conf.tt \
xt_dc_messaging_XTDC1.conf.tt \
xt_dc_messaging_XTDC2.conf.tt \
xt_dc_messaging_XTDC3.conf.tt \
xt_dc_psp_messaging.conf.tt \
xt_dc_psp_messaging_XTDC1.conf.tt \
xt_dc_psp_messaging_XTDC2.conf.tt \
xt_dc_psp_messaging_XTDC3.conf.tt \
xtdc.env.tt \
xtracker.conf.tt \
xtracker_acl_interim.conf.tt \
xtracker_DB_XTDC1.conf.tt \
xtracker_DB_XTDC2.conf.tt \
xtracker_DB_XTDC3.conf.tt \
xtracker_extras_XTDC1.conf.tt \
xtracker_extras_XTDC2.conf.tt \
xtracker_extras_XTDC3.conf.tt \
log4perl/default.conf.tt \
log4perl/xtracker.conf.tt \
log4perl/jobqueue.conf.tt \
log4perl/amq_consumer.conf.tt \
log4perl/amq_psp_consumer.conf.tt \
log4perl/order_importer.conf.tt \
log4perl/process_routing.conf.tt \
log4perl/pick_scheduling.conf.tt \
log4perl/test.conf.tt \
log4perl/test_debug.conf.tt


# Check if we're comming from a RPM installation
ifeq ($(RPM),0)
# We want a local dev env
LOCAL_DEVEL = 1
else
LOCAL_DEVEL = 0
endif


# Everything else is or should be internal
XTDC_ENV_FILE = $(XTDC_CONF_DIR)/xtdc.env
XTDC_CONFIG_FILE = $(XTDC_CONF_DIR)/xtracker.conf

# Temp file, created for test dbs, later incorporated into xtdc.env
DB_ENV_PATH = $(XTDC_BASE_DIR)/db.env

PROPERTIES_FILES := $(NAP_PROPERTIES_FILE) $(XTDC_PROPERTIES_FILE) $(XTDC_PATH_PROPERTIES_FILE) $(LOCAL_PROPERTIES_FILE)

DIRS_TO_CREATE = $(XTDC_CONF_DIR) $(XTDC_LOGS_DIR) $(TEST_ARTIFACTS_DIR)

setup_dirs:
	$(NOECHO) mkdir -p $(DIRS_TO_CREATE) || true
        ifeq ($(RPM),0)
    # if I'm giving something my password for sudo I want to know *what* - CCW
	sudo chown -R $(XTDC_USER): $(DIRS_TO_CREATE)
	sudo chmod -R ug+rw $(DIRS_TO_CREATE)
        else
	$(NOECHO) chown -R $(XTDC_USER): $(DIRS_TO_CREATE)
	$(NOECHO) chmod -R ug+rw $(DIRS_TO_CREATE)
        endif

create_app_properties_file: setup_dirs
	@echo "Creating the app properties file..."
	$(NOECHO) (echo "# Generated properties file";\
	echo "XTDC_BASE_DIR		$(XTDC_BASE_DIR)";\
	echo "XTDC_CONF_DIR		$(XTDC_CONF_DIR)";\
	echo "XTDC_LOGS_DIR		$(XTDC_LOGS_DIR)";\
	echo "XTDC_USER			$(XTDC_USER)";\
	echo "XTDC_USER_JQ			$(XTDC_USER_JQ)";\
	echo "XTDC_USER_AMQ			$(XTDC_USER_AMQ)";\
	echo "XTDC_CONFIG_DATE	"`date +'%Y-%m-%d %H:%M:%S'`;\
	echo "JAVASCRIPT_BASE_DIR	$(JAVASCRIPT_BASE_DIR)";\
	echo "LOCAL_DEVEL		$(LOCAL_DEVEL)";\
	echo "NAP_PERL5LIB		$(XTDC_BASE_DIR)/lib:$(XTDC_BASE_DIR)/lib_dynamic";\
	) | sudo -u $(XTDC_USER) tee $(XTDC_PROPERTIES_FILE)
	@echo "Wrote $(XTDC_PROPERTIES_FILE)"

copy_path_properties:
	$(NOECHO) sudo -u $(XTDC_USER) \
        cp $(TEMPLATE_SOURCE_DIR)/xtracker_path.properties \
	   $(XTDC_CONF_DIR)/xtracker_path.properties

generate_configs: setup_dirs copy_path_properties
	@echo "Generating the app's configs..."
	$(NOECHO) sudo -E -u $(XTDC_USER) /opt/xt/xt-perl/bin/mx-run \
        NAP::Config::Frontend \
	--target-dir $(XTDC_CONF_DIR) \
	$(foreach file,$(PROPERTIES_FILES),--properties-files $(file)) \
	--base-path $(TEMPLATE_SOURCE_DIR) \
	$(foreach file,$(XTDC_CONF_TEMPLATES),--templates $(TEMPLATE_SOURCE_DIR)/$(file))


setup_test_dbs: add_hudson_env #| creates_test_dbs

for_hudson: setup | add_hudson_env

creates_test_dbs:
	        $(info Creating JQ DB, $(JQ_DB))
	        $(shell createdb -U postgres --owner=www $(JQ_DB) -E utf8)
	        $(info Populating JQ DB)
	        $(shell psql -d $(JQ_DB) -U postgres -f db_schema/current_jq/00_base_schema.sql)
	        # Cf http://confluence.net-a-porter.com/display/DEV/Fulcrum%2C+XTCD%2C+NAP+and+Outnet+Databases
	        $(info Creating DC DB, $(DC_DB))
	        $(shell createdb -U postgres --owner=www $(DC_DB) -E utf8)
	        $(info Getting DC dump file)
	        $(shell cp /net/kingpin/xen/postgres/xtracker-intl_scrubbed.sql.gz .)
	        $(info Loading SQL)
	        $(shell zcat xtracker-intl_scrubbed.sql.gz | psql -U postgres -d $(DC_DB))
	        $(shell rm xtracker-intl_scrubbed.sql.gz)

# The few settings required to run concurrent tests on Hudson
add_hudson_env:
			# Create temp file
	        echo "^^# Added by make add_hudson_env ^\
	export TAP_FORMATTER_HTML_OUTFILE=${WORKSPACE}/tap.html ^\
	export XTDC_XTRACKER_TEST_DBNAME=$(DC_DB) ^\
	export XTDC_JQ_TEST_DBNAME=$(JQ_DB) ^\
	export XTDC_JQ_TEST_DSN=dbi:Pg:dbname=$(JQ_DB);host=localhost ^" \
	   	             > $(DB_ENV_PATH)
	        # Join configs
	        cat $(XTDC_ENV_FILE) $(DB_ENV_PATH) > maker.tmp
	        # Backup xtdc configuration
	        mv  $(XTDC_ENV_FILE) $(XTDC_ENV_FILE).bak
	        # Joined configs become xtdc.env
	        mv  maker.tmp $(XTDC_ENV_FILE)
	        $(info Merged DB env file with XTDC env file)
	        # Remvoe backup
	        rm  $(XTDC_ENV_FILE).bak
			$(info Removed backup)


apply_db_patches: bootstrap_constants
    ifndef XTDC_CREATE_DBS
	@echo "Applying DB patches..."
	$(NOECHO) source $(XTDC_ENV_FILE); bash script/deploy/apply_db_patches.sh $(APP_VERSION)
    else
	$(info Not applying DB patches, as XTDC_CREATE_DBS is set)
    endif


bootstrap_constants:
	@echo "Bootstrapping constants..."
	$(NOECHO) mkdir -p lib_dynamic/XTracker/Constants
	$(NOECHO) echo 'package XTracker::Constants::FromDB; sub import {}; 1' > lib_dynamic/XTracker/Constants/FromDB.pm
	$(NOECHO) source $(XTDC_ENV_FILE); chown $(XTDC_USER): lib_dynamic/XTracker/Constants/FromDB.pm

build_constants: bootstrap_constants
	$(info Building constants)
	$(NOECHO) source $(XTDC_ENV_FILE); sudo -E -u $(XTDC_USER) $(PERL) -Ilib script/build_constants > lib_dynamic/XTracker/Constants/FromDB.pm

create_job_queue:
    ifeq ($(RPM),0)
      ifdef XTDC_CREATE_DBS
# Need to add psql to the path for this
		$(info Create $(JQ_DB))
		$(shell psql -U postgres -c "CREATE DATABASE $(JQ_DB)")
		$(info Restoring JQ schema to $(JQ_DB) ...)
		psql -U postgres -d $(JQ_DB) -f db_schema/current_jq/00_base_schema.sql
		# $(NOECHO) psql -d $(JQ_DB) -U postgres -f db_schema/current_jq/00_base_schema.sql >/dev/null 2>&1 || true
		# psql -U postgres -d ${XTDC_XTRACKER_TEST_DBNAME} -f ${WORKSPACE}/db_schema/empty/xtdc_empty.sql >/dev/null 2>&1
      else
		$(NOECHO) psql -d $(JQ_DB) -U postgres -f db_schema/current_jq/00_base_schema.sql >/dev/null 2>&1 || true
      endif
    endif

create_system_paths:
	@echo "Creating required system paths..."
        ifeq ($(RPM),1)
	$(NOECHO) source $(XTDC_ENV_FILE); script/deploy/assert_system_paths.pl $(XTDC_USER)
        else
	$(NOECHO) source $(XTDC_ENV_FILE); sudo -E $(PERL) script/deploy/assert_system_paths.pl $(XTDC_USER)
        endif

devclean:
	@echo "Cleaning development artifacts..."
	rm -rf $(DIRS_TO_CREATE) ./tmp ./inc ./xtdc ./.rpmbuild ./lib_dynamic

finish:
        ifeq ($(RPM),0)
	@echo
	@echo
	@echo "Wrote $(XTDC_ENV_FILE)"
	@echo "Don't forget to 'source $(XTDC_ENV_FILE)' or '. $(XTDC_ENV_FILE)' in your shell."
	@echo "Otherwise things won't work !!!"
	@echo -e "\nmake helpme - For more help"
        endif

configs: create_app_properties_file \
generate_configs

rebuild_manifest:
	rm -rf MANIFEST
	tar cf symlinks.tar `find ./root/static/ -type l`
	find ./root/static/ -type l -exec rm '{}' '+'
	$(PERLRUN) "-MExtUtils::Manifest=mkmanifest" -e mkmanifest 2>/dev/null
	tar xf symlinks.tar && rm symlinks.tar

setup: rebuild_manifest \
configs \
bootstrap_constants \
apply_db_patches \
create_job_queue \
build_constants \
create_system_paths \
finish

debug: Makefile
	@echo -e "\nDEBUG Variables:"
	@echo "TEMPLATES               $(XTDC_CONF_TEMPLATES)"
	@echo "NO_DB_PATCH             $(NO_DB_PATCH)"
	@echo "PROPERTIES_FILES        $(PROPERTIES_FILES)"
	@echo "TEMPLATE_SOURCE_DIR     $(TEMPLATE_SOURCE_DIR)"
	@echo "LOCAL_DEVEL             $(LOCAL_DEVEL)"
	@echo
	@echo -e "The following are variables you can tweak like, make setup XTDC_LOGS_DIR=/bla"
	@echo "NAP_PROPERTIES_FILE     $(NAP_PROPERTIES_FILE)"
	@echo "XTDC_PROPERTIES_FILE    $(XTDC_PROPERTIES_FILE)"
	@echo "XTDC_BASE_DIR           $(XTDC_BASE_DIR)"
	@echo "XTDC_CONF_DIR           $(XTDC_CONF_DIR)"
	@echo "XTDC_LOGS_DIR           $(XTDC_LOGS_DIR)"
	@echo "XTDC_USER               $(XTDC_USER)"
	@echo "XT_DC_MESSAGING_CONFIG  $(XT_DC_MESSAGING_CONFIG)"
	@echo "JAVASCRIPT_BASE_DIR     $(JAVASCRIPT_BASE_DIR)"
	@echo "AP_VERSION              $(APP_VERSION)"
	@echo "RPM                     $(RPM)"

runtests: Makefile
	./t/TEST -start
	( time prove -lvr --timer t ) 2>&1 |tee test_run_`date +%Y%m%d%H%M.log`; exit $$PIPESTATUS
	./t/TEST -stop

helpme:
	@echo -e "\n### XTDC Makefile Help: ###\n"
	@echo "make helpme     - this screen"
	@echo "make setup      - sets up your environment"
	@echo "make configs    - regenerates configs"
	@echo "make runtests   - runs the app's test suite"
	@echo "make apply_db_patches - applies DB patches"
	@echo
	@echo -e "Usefull overrides:"
	@echo
	@echo "Append these to any target"
	@echo "NOECHO=\"\"   for extra debug "
	@echo "NAP_PROPERTIES_FILE=~/nap_dev.properties"
	@echo "e.g. make setup NAP_PROPERTIES_FILE=~/nap_dev.properties"
	@echo -e "\n"

__MAKE_FRAG__

}

install_share 'DEPLOYMENT_INSTRUCTIONS';
#install_as_vendor;

install_script glob('script/*.pl');
auto_install;

WriteMakefile(
              DISTNAME => $distname,
              VERSION  => $version,
);

