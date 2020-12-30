ARG NGINX_VERSION="1.18.0"

FROM nginx:${NGINX_VERSION}-alpine as build

# Install packages
RUN apk add --update --no-cache \
      autoconf \
      automake \
      byacc \
      curl-dev \
      flex \
      g++ \
      gcc \
      geoip-dev \
      git \
      libc-dev \
      libmaxminddb-dev \
      libstdc++ \
      libtool \
      libxml2-dev \
      linux-headers \
      lmdb-dev \
      make \
      openssl-dev \
      pcre-dev \
      yajl-dev \
      zlib-dev

ENV NGX_DEVEL_VERSION="0.3.1" \
    NGINX_COOKIE_FLAG_VERSION="1.1.0" \
    LUA_NGINX_VERSION="0.10.19" \
    LUAJIT_MAJOR_VERSION="2.1" \
    LUAJIT_MINOR_VERSION="20201027" \
    MODSECURITY_VERSION="3.0.4" \
    MODSECURITY_NGINX_VERSION="1.0.1" \
    MODSECURITY_SSDEEP_VERSION="2.14.1"

WORKDIR /tmp
    
RUN : "---------- download NGINX ----------" \
    && curl -sfSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz \
    && mkdir /tmp/nginx && mkdir -p /var/cache/nginx/{proxy_temp,fastcgi_temp} \
    && tar -zxvf nginx.tar.gz -C /tmp/nginx --strip-components=1  \
    && : "---------- download GEOIP2 ----------" \
    && curl -sfSL https://github.com/leev/ngx_http_geoip2_module/archive/master.tar.gz -o ngx_http_geoip2_module.tar.gz \
    && tar -zxvf ngx_http_geoip2_module.tar.gz  -C /tmp/nginx \
    && : "---------- download Nginx Cookie Flag ----------" \ 
    && curl -sfSL https://github.com/AirisX/nginx_cookie_flag_module/archive/v${NGINX_COOKIE_FLAG_VERSION}.tar.gz -o nginx_cookie_flag_module.tar.gz \
    && mkdir /tmp/nginx/nginx_cookie_flag_module && tar -zxvf nginx_cookie_flag_module.tar.gz -C /tmp/nginx/nginx_cookie_flag_module --strip-components=1 \
    && : "---------- download NGINX DEVEL KIT ----------" \
    && curl -sfSL https://github.com/vision5/ngx_devel_kit/archive/v${NGX_DEVEL_VERSION}.tar.gz -o nginx_devel.tar.gz \
    && mkdir /tmp/nginx/nginx_devel && tar -zxvf nginx_devel.tar.gz -C /tmp/nginx/nginx_devel --strip-components=1 \
    && : "---------- download LUA NGINX MODULE ----------" \
    && curl -sfSL https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_VERSION}.tar.gz -o lua_nginx.tar.gz \
    && mkdir /tmp/nginx/lua_nginx && tar -zxvf lua_nginx.tar.gz -C /tmp/nginx/lua_nginx --strip-components=1 \
    && : "---------- download LUAJIT ----------" \
    && curl -sfSL https://github.com/openresty/luajit2/archive/v${LUAJIT_MAJOR_VERSION}-${LUAJIT_MINOR_VERSION}.tar.gz -o luajit.tar.gz \
    && mkdir /tmp/nginx/luajit && tar -zxvf luajit.tar.gz -C /tmp/nginx/luajit --strip-components=1 \
    && : "---------- download MODSECURITY ----------" \
    && curl -sfSL https://github.com/SpiderLabs/ModSecurity/releases/download/v${MODSECURITY_VERSION}/modsecurity-v${MODSECURITY_VERSION}.tar.gz -o modsecurity.tar.gz \
    && mkdir /tmp/nginx/modsecurity && tar -zxvf modsecurity.tar.gz -C /tmp/nginx/modsecurity --strip-components=1 \
    && : "---------- download MODSECURITY NGINX ----------" \
    && curl -sfSL https://github.com/SpiderLabs/ModSecurity-nginx/releases/download/v${MODSECURITY_NGINX_VERSION}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}.tar.gz -o modsecurity-nginx.tar.gz \
    && mkdir /tmp/nginx/modsecurity-nginx && tar -zxvf modsecurity-nginx.tar.gz -C /tmp/nginx/modsecurity-nginx --strip-components=1 \
    && : "---------- download MODSECURITY SSDEEP ----------" \
    && curl -sfSL https://github.com/ssdeep-project/ssdeep/releases/download/release-${MODSECURITY_SSDEEP_VERSION}/ssdeep-${MODSECURITY_SSDEEP_VERSION}.tar.gz -o modsecurity-ssdeep.tar.gz \
    && mkdir /tmp/nginx/modsecurity-ssdeep && tar -zxvf modsecurity-ssdeep.tar.gz -C /tmp/nginx/modsecurity-ssdeep --strip-components=1


# Build LuaJIT
WORKDIR /tmp/nginx/luajit
RUN make -j $(nproc) \
    && make -j $(nproc) install
ENV LUAJIT_LIB="/usr/local/lib" \
    LUAJIT_INC="/usr/local/include/luajit-${LUAJIT_MAJOR_VERSION}"

# Build Modsecurity
WORKDIR /tmp/nginx
RUN cd /tmp/nginx/modsecurity-ssdeep && ./configure && make -j $(nproc) install \
    && cd /tmp/nginx/modsecurity && ./build.sh \
    && ./configure --with-lmdb \
    && make -j $(nproc) \
    && make -j $(nproc) install \
    && rm -fr /usr/local/modsecurity/lib/libmodsecurity.a \
      /usr/local/modsecurity/lib/libmodsecurity.la

# Build Nginx
WORKDIR /tmp/nginx
RUN : "---------- CHANGE NGINX SERVER HEADERS ----------" \
    && sed -i 's/Server: nginx/Server: webserver/g' src/http/ngx_http_header_filter_module.c \
    && : "---------- COMPILE NGINX ----------" \
    && ./configure \
        --user=nginx \
        --group=nginx \
        --prefix=/usr/share/nginx \
        --modules-path=/etc/nginx/modules \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/run/lock/subsys/nginx \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --with-debug \
        --with-http_v2_module \
        --with-http_auth_request_module \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-pcre \
        --with-md5-asm \
        --with-pcre-jit \
        --with-sha1-asm \
        --with-http_stub_status_module \
        --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
        --without-http_autoindex_module \
        --without-http_ssi_module \
        --without-http_empty_gif_module \
        --without-http_uwsgi_module \
        --add-module=nginx_devel \
        --add-module=lua_nginx \
        --add-module=nginx_cookie_flag_module \
        --add-dynamic-module=/tmp/nginx/modsecurity-nginx \
        --add-dynamic-module=ngx_http_geoip2_module-master $(nginx -V) --with-compat \
    && make -j $(nproc) \
    && make -j $(nproc) install \
    && make -j $(nproc) modules

# Add Resty Modules
ENV LUA_INCLUDE_DIR=${LUAJIT_INC} \
    LUA_RESTY_HTTP="0.14" \
    LUA_RESTY_STRING="0.12" \
    LUA_RESTY_CORE="0.1.21" \
    LUA_RESTY_LRUCACHE="0.10" \
    LUA_CJSON="2.1.0.7" 

WORKDIR /tmp/nginx
RUN mkdir /usr/local/share/lua/5.1/resty/ \
    && curl -sSL https://github.com/ledgetech/lua-resty-http/archive/v${LUA_RESTY_HTTP}.tar.gz | tar xz \
    && curl -sSL https://github.com/openresty/lua-resty-string/archive/v${LUA_RESTY_STRING}.tar.gz | tar xz \
    && curl -sSL https://github.com/openresty/lua-resty-core/archive/v${LUA_RESTY_CORE}.tar.gz | tar xz \
    && curl -sSL https://github.com/openresty/lua-resty-lrucache/archive/v${LUA_RESTY_LRUCACHE}.tar.gz | tar xz \
    && cp -r lua-resty-*/lib/resty/* /usr/local/share/lua/5.1/resty/ \
    && curl -sSL https://github.com/openresty/lua-cjson/archive/${LUA_CJSON}.tar.gz | tar xz \
    && cd lua-cjson-${LUA_CJSON} \
    && make -j $(nproc) install 


# Add Prometheus
ENV LUA_RESTY_PROMETHEUS="0.20201218"

RUN curl -sSL https://github.com/knyar/nginx-lua-prometheus/archive/${LUA_RESTY_PROMETHEUS}.tar.gz | tar xz \
    && curl -sSL https://raw.githubusercontent.com/Kong/lua-resty-counter/master/lib/resty/counter.lua >  /usr/local/share/lua/5.1/prometheus_resty_counter.lua \
    && cp -r nginx-lua-prometheus-${LUA_RESTY_PROMETHEUS}/*.lua /usr/local/share/lua/5.1/

FROM nginx:${NGINX_VERSION}-alpine

RUN apk add --no-cache \
    tzdata \
    curl-dev \
    curl \
    libmaxminddb-dev \
    libstdc++ \
    libxml2-dev \
    lmdb-dev \
    tzdata \
    yajl && \
    chown -R nginx:nginx /usr/share/nginx

ENV LUAJIT_LIB="/usr/local/lib" \
    LUAJIT_INC="/usr/local/include/luajit-2.1" \
    GEO_DB_RELEASE="2020-12" \
    MODSECURITY_CRS_VERSION="3.2.0"

# Download GeoDB
RUN mkdir -p /etc/nginx/geoip/ \  
    && wget -O - https://download.db-ip.com/free/dbip-city-lite-${GEO_DB_RELEASE}.mmdb.gz | gzip -d > /etc/nginx/geoip/dbip-city-lite.mmdb \
    && wget -O - https://download.db-ip.com/free/dbip-country-lite-${GEO_DB_RELEASE}.mmdb.gz | gzip -d > /etc/nginx/geoip/dbip-country-lite.mmdb 
   
# Copy from Build Stage
COPY --from=build /etc/nginx/ /etc/nginx/
COPY --from=build /usr/local/modsecurity /usr/local/modsecurity
COPY --from=build /usr/lib/nginx/modules/ /usr/lib/nginx/modules/
COPY --from=build /usr/local/lib/ /usr/local/lib/
COPY --from=build /usr/local/include/ /usr/local/include/
COPY --from=build /usr/local/share/lua /usr/local/share/lua
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /usr/sbin/nginx-debug /usr/sbin/nginx-debug

# Copy from Local
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/conf.d/ /etc/nginx/conf.d/
COPY etc/nginx/modsecurity.d/ /etc/nginx/modsecurity.d/

# Add Modsecurity Unicode and Rules
RUN curl -sfSL https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping > /etc/nginx/modsecurity.d/unicode.mapping \
    && mkdir -p /tmp/owasp-modsecurity-crs \
    && curl -sSL https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${MODSECURITY_CRS_VERSION}.tar.gz | tar -zx -C /tmp/owasp-modsecurity-crs --strip-components=1 \
    && mv /tmp/owasp-modsecurity-crs/rules/ /etc/nginx/modsecurity.d/ \
    && rm -fr /tmp/owasp-modsecurity-crs

WORKDIR /etc/nginx

HEALTHCHECK --interval=5s --timeout=5s --retries=10 CMD curl --fail http://127.0.0.1/nginx_metrics || exit 1
