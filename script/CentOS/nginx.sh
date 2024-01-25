#!/bin/bash


if [[ $EUID -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi


# Define directory
DOWNLOAD_DIRECTORY=${DOWNLOAD_DIRECTORY:-/usr/local/src}
SERVICE_DIRECTORY=${SERVICE_DIRECTORY:-/usr/lib/systemd/system}
LOGROTATE_DIRECTORY=${LOGROTATE_DIRECTORY:-/etc/logrotate.d}
NGINX_DIRECTORY=${NGINX_DIRECTORY:-/etc/nginx}
NGINX_CONF_DIRECTORY=${NGINX_CONF_DIRECTORY:-/etc/nginx/conf.d}
NGINX_CACHE_DIRECTORY=${NGINX_CACHE_DIRECTORY:-/var/cache/nginx}
# Define version
NGINX_VERSION=${NGINX_VERSION:-1.20.2}
# Define options
NGINX_OPTIONS=("--prefix=/etc/nginx"
	"--sbin-path=/usr/sbin/nginx"
	"--modules-path=/usr/lib64/nginx/modules"
	"--conf-path=/etc/nginx/nginx.conf"
	"--error-log-path=/var/log/nginx/error.log"
	"--http-log-path=/var/log/nginx/access.log"
	"--pid-path=/var/run/nginx.pid"
	"--lock-path=/var/run/nginx.lock"
  	"--http-client-body-temp-path=/var/cache/nginx/client_temp"
  	"--http-proxy-temp-path=/var/cache/nginx/proxy_temp"
  	"--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp"
  	"--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp"
  	"--http-scgi-temp-path=/var/cache/nginx/scgi_temp"
  	"--user=nginx"
  	"--group=nginx"
  	"--with-cc-opt=-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC"
  	"--with-ld-opt=-Wl,-z,relro -Wl,-z,now -pie")
# Define modules
NGINX_MODULES=("--with-compat"
	"--with-file-aio"
	"--with-threads"
	"--with-http_addition_module"
	"--with-http_auth_request_module"
	"--with-http_dav_module"
	"--with-http_flv_module"
	"--with-http_gunzip_module"
	"--with-http_gzip_static_module"
	"--with-http_mp4_module"
	"--with-http_random_index_module"
	"--with-http_realip_module"
	"--with-http_secure_link_module"
	"--with-http_slice_module"
	"--with-http_ssl_module"
	"--with-http_stub_status_module"
	"--with-http_sub_module"
	"--with-http_v2_module"
	"--with-mail"
	"--with-mail_ssl_module"
	"--with-stream"
	"--with-stream_realip_module"
	"--with-stream_ssl_module"
	"--with-stream_ssl_preread_module")

if [[ ! -d ${NGINX_DIRECTORY} ]]; then
	mkdir ${NGINX_DIRECTORY}
fi

if [[ ! -d ${NGINX_CONF_DIRECTORY} ]]; then
	mkdir ${NGINX_CONF_DIRECTORY}
fi

if [[ ! -d ${NGINX_CACHE_DIRECTORY} ]]; then
	mkdir ${NGINX_CACHE_DIRECTORY}
fi

# Check download directory
if [[ ! -d ${DOWNLOAD_DIRECTORY} ]]; then
	echo "The directory '${DOWNLOAD_DIRECTORY}' does not exists"
	exit 1
fi

# Dependencies
yum -y update > /dev/null 2>&1
yum -y install epel-release gcc gcc-c++ glibc-devel make ncurses-devel openssl-devel autoconf git wget expect tar  > /dev/null 2>&1

# Download nginx source code compressed file
wget -q https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O ${DOWNLOAD_DIRECTORY}/nginx.tar.gz
if [[ $? -ne 0 ]]; then
	echo "Download 'nginx-${NGINX_VERSION}.tar.gz' failed"
	exit 1
fi

# Decompress nginx.tar.gz
tar zxf ${DOWNLOAD_DIRECTORY}/nginx.tar.gz -C ${DOWNLOAD_DIRECTORY}

cd ${DOWNLOAD_DIRECTORY}/nginx-${NGINX_VERSION}
./configure "${NGINX_OPTIONS[@]}" ${NGINX_MODULES[@]} > /dev/null 2>&1
make -j "$(nproc)" > /dev/null 2>&1
make install > /dev/null 2>&1

# Systemd script
if [[ ! -d ${SERVICE_DIRECTORY} ]]; then
	echo "The directory '${SERVICE_DIRECTORY}' does not exists"
	exit 1
fi

if [[ ! -e ${SERVICE_DIRECTORY}/nginx.service ]]; then
	wget -q https://raw.githubusercontent.com/Jupiter0428/nginx-install/master/conf/nginx.service -O ${SERVICE_DIRECTORY}/nginx.service
else
	echo "File '${SERVICE_DIRECTORY}/nginx.service' already exists"
fi
systemctl daemon-reload
systemctl enable nginx > /dev/null 2>&1

# Logrotate conf
if [[  ! -d ${LOGROTATE_DIRECTORY} ]]; then
	echo "Directory '${LOGROTATE_DIRECTORY}' does not exists"
	exit 1
fi

if [[ ! -e ${LOGROTATE_DIRECTORY}/nginx ]]; then
	wget -q https://raw.githubusercontent.com/Jupiter0428/nginx-install/master/conf/nginx -O ${LOGROTATE_DIRECTORY}/nginx

else 
	echo "File '/etc/logrotate.d/nginx' already exists"
fi

# User nginx
if ! $(id -u nginx >/dev/null 2>&1); then
	useradd -s /sbin/nologin nginx
fi

# nginx.conf
if [[ ! -e ${NGINX_DIRECTORY}/nginx.conf ]]; then
	wget -q https://raw.githubusercontent.com/Jupiter0428/nginx-install/master/conf/nginx.conf -O ${NGINX_DIRECTORY}/nginx.conf
fi

# Start nginx
systemctl start nginx
if [[ $? -ne 0 ]]; then
	echo -e "Nginx start failed"
	exit 1
fi