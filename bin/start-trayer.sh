#!/bin/sh

killall trayer

exec trayer --edge top --align right --SetDockType true --expand true --width 10 --alpha 0 --tint 0x000000 --height 20 --transparent true
