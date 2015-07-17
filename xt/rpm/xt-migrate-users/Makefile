# Makefile for the xt-migrate-users transitional package

NAME = xt-migrate-users
VERSION = 1
RELEASE = 4

all: xt-migrate-users.spec rpmdir rpm cp_rpm clean

rpmdir:
	rm -rf .rpmbuild || true
	mkdir -p \
		.rpmbuild/SOURCES \
		.rpmbuild/RPMS \
		.rpmbuild/BUILD \
		.rpmbuild/tmp \

xt-migrate-users.spec: xt-migrate-users.spec.in
	( echo "Version: $(VERSION)";\
	echo "Release: $(RELEASE)";\
	echo "Name: $(NAME)";\
	) > $@
	cat $< >> $@

rpm: xt-migrate-users.spec rpmdir
	rpmbuild -bb --clean \
          --define "_topdir .rpmbuild" \
          --define "_tmppath .rpmbuild/tmp" xt-migrate-users.spec

cp_rpm: xt-migrate-users.spec rpmdir rpm
	cp .rpmbuild/RPMS/noarch/*.rpm .

clean:
	rm -rf .rpmbuild xt-migrate-users.spec

clean-all: clean
	rm -rf xt-migrate-users-*.rpm
