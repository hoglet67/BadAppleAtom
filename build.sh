#!/bin/bash

SRC=dlair


for mode in 0 2 4 6
do
    PROG=PLAYER${mode}

    echo Assembling $PROG
    ca65 -l ${PROG}.lst -DMODE=${mode} -o ${SRC}.o ${SRC}.asm
    echo Linking ${PROG}
    ld65 ${SRC}.o -C atom.cfg -o "${PROG}"
    echo Finished, created ${PROG}
    md5sum ${PROG}

done

rm -f ${SRC}.o
