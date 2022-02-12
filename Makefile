SOURCES = startup.s arch_sim6502.s
OBJECTS = $(SOURCES:.s=.o)

CC = cl65
ARCH = -t sim6502
ASMFLAGS = $(ARCH) --create-dep $(<:.s=.d)
LDFLAGS = $(ARCH) -m $@.map

TARGET = basic

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.s
	$(CC) -c $(ASMFLAGS) -o $@ $<

clean:
	rm -f $(TARGET) *.o *.d *.map
