#!/usr/bin/env bash
sudo make uninstall
make clean

cd ext/jsutils
make clean
sudo make uninstall

cd ../ffi
sudo make uninstall
make clean

cd ../../test
make clean

cd ../

make && sudo make install && make clean && cd ext/jsutils && make && sudo make install && make clean && cd ../ffi && make && sudo make install && make clean

