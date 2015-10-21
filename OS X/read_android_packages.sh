#! /usr/bin/env bash

adb shell "pm list packages -f" | tee ./android_packages.list
