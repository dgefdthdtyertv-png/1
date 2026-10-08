ARCHS = arm64
TARGET = iphone:clang:14.0:14.0
INSTALL_PROGRAM = NO
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = AutoTapInject
AutoTapInject_FILES = Inject.m
AutoTapInject_CFLAGS = -fobjc-arc
AutoTapInject_FRAMEWORKS = UIKit Foundation
AutoTapInject_LDFLAGS = -dynamiclib

include $(THEOS)/makefiles/library.mk
