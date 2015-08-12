JSUTILS_LIB_DIR ?= /usr/lib/jsutils/0.1.0
all:
	valac src/lib/*vala --pkg gee-1.0 --vapidir=./ --vapidir=./vapi/ --pkg javascriptcoregtk-3.0 --library=jsutils-0.1 -H jsutils.h -o libjsutils-0.1.so -X -shared -X -fPIC 

install:
	mkdir -p $(JSUTILS_LIB_DIR)/vapi
	mkdir -p $(JSUTILS_LIB_DIR)/include
	cp libjsutils-0.1.so /usr/lib/
	cp jsutils.h /usr/include/
	cp jsutils.h $(JSUTILS_LIB_DIR)/include/	
	mkdir -p /usr/share/vala/vapi/
	cp jsutils-0.1.vapi /usr/share/vala/vapi/
	cp jsutils-0.1.vapi $(JSUTILS_LIB_DIR)/vapi/
	cp -f jsutils-0.1.pc /usr/lib/pkgconfig/
	cp -f jsutils-0.1.deps /usr/share/vala/vapi/
	cp -f jsutils-0.1.deps $(JSUTILS_LIB_DIR)/vapi/
	cp -f vapi/* $(JSUTILS_LIB_DIR)/vapi/
		
uninstall:
	rm -rf $(JSUTILS_LIB_DIR)/
	rm /usr/lib/libjsutils-0.1.so
	rm /usr/include/jsutils.h
	rm /usr/share/vala/vapi/jsutils-0.1.vapi
	rm /usr/lib/pkgconfig/jsutils-0.1.pc
	rm /usr/share/vala/vapi/jsutils-0.1.deps

clean:
	rm *.so
	rm *.h
	rm *.vapi
