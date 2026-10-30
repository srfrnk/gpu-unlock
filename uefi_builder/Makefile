CC = clang
LD = lld-link
CFLAGS = -target x86_64-unknown-windows -nostdlib -ffreestanding -fno-builtin -fno-stack-protector -mno-red-zone -fshort-wchar -Os -Wall -Wextra -Wno-unused-parameter
LDFLAGS = -Wl,-subsystem:efi_application -Wl,-entry:efi_main

TARGET = BOOTX64.EFI
SRCS = main.c
OBJS = $(SRCS:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -target x86_64-unknown-windows -nostdlib -fuse-ld=$(LD) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
