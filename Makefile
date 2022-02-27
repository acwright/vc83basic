TARGETS = sim6502 apple2

COMMON_SOURCES = $(wildcard *.s)
COMMON_OBJECTS = $(COMMON_SOURCES:.s=.o)

ASMFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

define create-target

TARGET_$1_SOURCES = $$(wildcard $1/*.s)
TARGET_$1_OBJECTS = $$(TARGET_$1_SOURCES:.s=.o)

TARGET_$1_COMMON_OBJECTS = $(COMMON_SOURCES:%.s=$1/%.o)

$1/basic: $$(TARGET_$1_OBJECTS) $$(TARGET_$1_COMMON_OBJECTS)
	cl65 -t $1 $$(LDFLAGS) -o $$@ $$^

$1/%.o: %.s
	cl65 -t $1 -c $$(ASMFLAGS) -o $$@ $$<

$1/%.o: $1/%.s
	cl65 -t $1 -c $$(ASMFLAGS) -o $$@ $$<

clean::
	rm -f $1/basic $1/*.o $1/*.d $1/*.map

endef

all: $(TARGETS:%=%/basic)

$(eval $(call create-target,sim6502))
$(eval $(call create-target,apple2))

#$(eval $(foreach TARGET, $(TARGETS), $(create-target $(TARGET))))

clean::
	rm -f *.o *.d *.map
