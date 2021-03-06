
DEB_HOST_ARCH ?= $(shell dpkg-architecture -qDEB_HOST_ARCH)

gn_args=is_clang=false \
        clang_use_chrome_plugins=false \
        is_debug=false \
        use_sysroot=false \
        enable_nacl=false

# disabled features
ninja_args=is_debug=false \
           is_clang=false \
           clang_use_chrome_plugins=false \
           use_gtk3=false \
           use_ozone=false \
           use_gconf=false \
           use_sysroot=false \
           use_vulcanize=false \
           use_gnome_keyring=false \
           rtc_libvpx_build_vp9=false \
           treat_warnings_as_errors=false \
           enable_nacl=false \
           enable_nacl_nonsfi=false \
           enable_google_now=false \
           enable_widevine=false \
           enable_hangout_services_extension=false \
           enable_iterator_debugging=false \
           gold_path=\"\" \
           linux_use_bundled_binutils=false \

# enabled features
ninja_args+=use_gio=true \
            use_pulseaudio=true \
            link_pulseaudio=true \
            proprietary_codecs=true \
            ffmpeg_branding=\"Chrome\" \
            fieldtrial_testing_like_official_build=true \


# set the appropriate cpu architecture
ifeq (i386,$(DEB_HOST_ARCH))
ninja_args+=host_cpu=\"x86\" \
            use_gold=true
TARGET_CPU = "x86"
endif
ifeq (amd64,$(DEB_HOST_ARCH))
ninja_args+=host_cpu=\"x64\" \
            use_gold=true
TARGET_CPU = "x64"
endif
ifeq (arm64,$(DEB_HOST_ARCH))
ninja_args+=host_cpu=\"arm64\" \
            use_gold=true
TARGET_CPU = "arm64"
endif
ifeq (armhf,$(DEB_HOST_ARCH))
ninja_args+=host_cpu=\"arm\" \
            use_gold=true \
            arm_use_neon=false
TARGET_CPU = "arm"
endif
ifeq (mips64el,$(DEB_HOST_ARCH))
ninja_args+=host_cpu=\"mips64el\" \
            use_gold=false
TARGET_CPU = "mips64el"
endif

all: build-gn generate-cef-args build-cef

install-deps:
	sudo apt-get install libcups2-dev libgtk2.0-dev libnss3-dev \
		libgtkglext1-dev libgconf2-dev libffi-dev libasound2-dev gperf \
		bison libpci-dev libxss-dev

build-gn:
	cd src && \
		tools/gn/bootstrap/bootstrap.py -s --no-clean --no-rebuild --gn-gen-args="$(defines)"

generate-chrome-args:
	cd src && \
		out/Release/gn gen out/Release --args="$(ninja_args)"

build-chrome:
	cd src && \
		ninja -C out/Release chrome chrome_sandbox

# Create git repo in src or else git-patch command will not work
generate-cef-args: create-temp-git-repos do-generate-cef-args clean-temp-git-repos

create-temp-git-repos:
	cd src && git init
	cd src/third_party/pdfium && git init
	cd src/third_party/swiftshader && git init

do-generate-cef-args:
	cd src/cef && \
	PATH=$(PWD)/src/out/Release:$(PWD)/depot_tools:$$PATH \
		 ./cef_create_projects.sh

clean-temp-git-repos:
	rm -rvf src/.git src/third_party/pdfium/.git src/third_party/swiftshader/.git

build-cef:
	cd src && \
		ninja -C out/Release_GN_$(TARGET_CPU) cef chrome_sandbox

clean-cef:
	cd src && git checkout .
	cd src && rm -rf ui/base/clipboard/clipboard_qt_mapper.cc \
		ui/base/clipboard/clipboard_qt_mapper.h

build-cef-tarball:
	cd src/cef/tools && \
		./make_distrib.sh  --no-symbols --no-docs --no-archive --ninja-build --minimal \
		--distrib-subdir=cef_$(TARGET_CPU) \
		--output-dir=../../../out
	cd out/cef_$(TARGET_CPU)_minimal && \
		tar -cf cef.$(TARGET_CPU).tar Release/ Resources/ && \
		gzip --best cef.$(TARGET_CPU).tar

update-submodules:
	git submodule update --init --recursive
	git submodule update --remote
