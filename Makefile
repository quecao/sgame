CC := gcc
PLAT := linux
SKYNET_PAHT ?= vendor/skynet

SKYNET_LIBS := -lpthread -lm -ldl -lrt
SHARED := -fPIC --shared
EXPORT := -Wl,-E

LUA_CLIB_PATH ?= build/luaclib
CSERVICE_PATH ?= build/cservice

SKYNET_BUILD_PATH ?= . 

# lua
LUA_STATICLIB := $(SKYNET_PAHT)/3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= $(SKYNET_PAHT)/3rd/lua

# jemaloc
JEMALLOC_STATICLIB := $(SKYNET_PAHT)/3rd/jemalloc/lib/libjemalloc_pic.a
MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)
JEMALLOC_INC := $(SKYNET_PAHT)/3rd/jemalloc/include/jemalloc

# gcc make skynet
CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)

all :copy_file jemalloc skynet

copy_file:
	mkdir -p build
	cp -r $(SKYNET_PAHT)/lualib build
	cp -r $(SKYNET_PAHT)/service build

jemalloc : $(MALLOC_STATICLIB)

$(JEMALLOC_STATICLIB) : 
	git submodule update --init --recursive
	cd $(SKYNET_PAHT)/3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-prof
	cd $(SKYNET_PAHT)/3rd/jemalloc && $(MAKE) CC=$(CC)

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet \
  client \
  bson md5 sproto lpeg $(TLS_MODULE)

LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-debugchannel.c \
  lua-datasheet.c \
  lua-sharetable.c \
  \

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

skynet : \
  $(SKYNET_BUILD_PATH)/skynet \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/skynet : $(foreach v, $(SKYNET_SRC), $(SKYNET_PAHT)/skynet-src/$(v)) $(LUA_LIB) $(MALLOC_STATICLIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src -I$(JEMALLOC_INC) $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : $(SKYNET_PAHT)/service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -I$(SKYNET_PAHT)/skynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix $(SKYNET_PAHT)/lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(SKYNET_PAHT)/skynet-src -I$(SKYNET_PAHT)/service-src -I$(SKYNET_PAHT)/lualib-src

$(LUA_CLIB_PATH)/bson.so : $(SKYNET_PAHT)/lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_PAHT)/skynet-src $^ -o $@

$(LUA_CLIB_PATH)/md5.so : $(SKYNET_PAHT)/3rd/lua-md5/md5.c $(SKYNET_PAHT)/3rd/lua-md5/md5lib.c $(SKYNET_PAHT)/3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_PAHT)/3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/client.so : $(SKYNET_PAHT)/lualib-src/lua-clientsocket.c $(SKYNET_PAHT)/lualib-src/lua-crypt.c $(SKYNET_PAHT)/lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/sproto.so : $(SKYNET_PAHT)/lualib-src/sproto/sproto.c $(SKYNET_PAHT)/lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_PAHT)/lualib-src/sproto $^ -o $@ 

$(LUA_CLIB_PATH)/ltls.so : $(SKYNET_PAHT)/lualib-src/ltls.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_PAHT)/skynet-src -L$(TLS_LIB) -I$(TLS_INC) $^ -o $@ -lssl

$(LUA_CLIB_PATH)/lpeg.so : $(SKYNET_PAHT)/3rd/lpeg/lpcap.c $(SKYNET_PAHT)/3rd/lpeg/lpcode.c $(SKYNET_PAHT)/3rd/lpeg/lpprint.c $(SKYNET_PAHT)/3rd/lpeg/lptree.c $(SKYNET_PAHT)/3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_PAHT)/3rd/lpeg $^ -o $@