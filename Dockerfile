FROM buildpack-deps:jessie

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

ENV LANG C.UTF-8 
ENV TZ Asia/Shanghai
ENV BROWSER firefox-esr
ENV DISPLAY :99
ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.5.5
ARG GECKODRIVER_VERSION=0.22.0
ARG GECKODRIVER_FILE=v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz

#================================================
# Installations
#================================================

# extra dependencies (over what buildpack-deps already includes)
RUN apt-get update && apt-get install -y --no-install-recommends \
		tk-dev build-essential libssl-dev python-setuptools xauth \
		$BROWSER vim xvfb xserver-xephyr vnc4server xz-utils zlib1g-dev \
	      && rm -rf /var/lib/apt/lists/*

RUN set -ex \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	#&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	#&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	#&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	#&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--without-ensurepip \
	&& make -j "$(nproc)" \
	&& make install \
	&& ldconfig \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python \
	\
	&& python3 --version

RUN  wget -O /tmp/geckodriver.tar.gz https://github.com/mozilla/geckodriver/releases/download/$GECKODRIVER_FILE \
  && rm -rf /usr/bin/geckodriver \
  && tar -C /usr/bin -zxf /tmp/geckodriver.tar.gz \
  && rm /tmp/geckodriver.tar.gz \
  && mv /usr/bin/geckodriver /usr/bin/geckodriver-$GECKODRIVER_VERSION \
  && chmod 755 /usr/bin/geckodriver-$GECKODRIVER_VERSION \
  && ln -fs /usr/bin/geckodriver-$GECKODRIVER_VERSION /usr/bin/geckodriver


# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 18.1

RUN set -ex; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

RUN pip3 install selenium pyvirtualdisplay requests unittest-xml-reporting pymongo lxml requests


#==================
# Vim highlight
#==================

RUN echo "syntax on" >> /etc/vim/vimrc

#==================
# Xvfb + init scripts
#==================
ADD libs/xvfb_init /etc/init.d/xvfb
RUN chmod a+x /etc/init.d/xvfb

ADD libs/xvfb-daemon-run /usr/bin/xvfb-daemon-run
RUN chmod a+x /usr/bin/xvfb-daemon-run

#============================
# Clean up
#============================
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
