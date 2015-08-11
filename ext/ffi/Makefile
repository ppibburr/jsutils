JSUTILS_LIB_DIR ?= /usr/lib/jsutils/0.1.0

all:
	valac ffi.vala --pkg jsutils-0.1 --vapidir=../../vapi/ -H FFI.h --library=FFI -X -shared -X -fPIC -o ffi.so --pkg ffi --pkg gee-1.0
					

clean:
	rm ./ffi.so
	rm ./FFI.vapi
	rm ./FFI.h


install:
	cp ./ffi.so $(JSUTILS_LIB_DIR)/	
	cp ../../vapi/ffi.vapi $(JSUTILS_LIB_DIR)/vapi/	
	cp FFI.vapi $(JSUTILS_LIB_DIR)/vapi/
	cp FFI.h $(JSUTILS_LIB_DIR)/include/

uninstall:
	rm $(JSUTILS_LIB_DIR)/ffi.so
	rm $(JSUTILS_LIB_DIR)/vapi/ffi.vapi
	rm $(JSUTILS_LIB_DIR)/vapi/FFI.vapi
	rm $(JSUTILS_LIB_DIR)/include/FFI.h
