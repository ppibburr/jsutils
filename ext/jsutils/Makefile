JSUTILS_LIB_DIR ?= /usr/lib/jsutils/0.1.0
all:
	valac *vala --vapidir=../../vapi/ --pkg jsutils-0.1 --library=bridge -H bridge.h -o bridge.so -X -shared -X -fPIC

install:
	cp bridge.so $(JSUTILS_LIB_DIR)/
	cp bridge.vapi $(JSUTILS_LIB_DIR)/vapi/
	cp bridge.h $(JSUTILS_LIB_DIR)/include/
	
uninstall:
	rm $(JSUTILS_LIB_DIR)/bridge.so
	rm $(JSUTILS_LIB_DIR)/vapi/bridge.vapi
	rm $(JSUTILS_LIB_DIR)/include/bridge.h
	
clean:
	rm *.so
	rm *.h
	rm *.vapi
