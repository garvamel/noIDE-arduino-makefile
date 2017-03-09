# The core files and pinout variant files are in the same folder, Arduino handles them in different folders.

include Makefile.config

TARGET =firmware
CORE =arduino
BUILD =build
FLIB =firstparty_libraries
TLIB =thirdparty_libraries

CORE_PATH =./$(CORE)/
MAIN_PATH =./$(TARGET)/
BUILD_PATH =./$(BUILD)/
FLIB_PATH =./$(FLIB)/
TLIB_PATH =./$(TLIB)/

CORE_NAME =core
ARDUINO_CORE =lib$(CORE_NAME).a
SRC =$(MAIN_PATH)$(TARGET).cpp
OPT =-Os

#Flags (options) as per arduino specification, see:
#https://github.com/arduino/Arduino/wiki/Arduino-IDE-1.5-3rd-party-Hardware-specification

# For gcc
CFLAGS =-c -g $(OPT) -w -ffunction-sections -fdata-sections -MMD

#For g++
CPPFLAGS =-c -g $(OPT) -w -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -MMD

#For asm gcc
ASFLAGS =-c -g -x assembler-with-cpp

#For .elf (linker) files
ELFFLAGS =-w $(OPT) -Wl,--gc-sections

#For arduino core archive (avr-ar)
ARFLAGS =rcs

#For objcopy elf to eep conversion
#EEPFLAGS =-O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0

#For objcopy elf to hex conversion
HEXFLAGS =-O ihex -R .eeprom

# Programming support using avrdude. Settings and variables.
CPPC =avr-g++
ARCC =avr-ar
CC =avr-gcc
OBJCOPY =avr-objcopy
# OBJDUMP =avr-objdump
# SIZE =avr-size
# NM =avr-nm

# Some shortcuts
REMOVE =rm -f
RREMOVE =rm -rf
MV =mv -f

#AVRdude uploading recipe
AVRDUDE =avrdude

#stk500
AVRDUDE_PROGRAMMER =arduino
AVRDUDE_WRITE_FLASH =-U flash:w:$(BUILD_PATH)$(TARGET).hex
AVRDUDE_BASIC =-p $(MCU) -P $(PROG_PORT) -c $(AVRDUDE_PROGRAMMER) -b $(BAUD_RATE)
AVRDUDE_FLAGS =$(AVRDUDE_BASIC)

 
#First get all files from core folder
CFILES :=$(wildcard $(CORE_PATH)*.c)
CPPFILES :=$(wildcard $(CORE_PATH)*.cpp)
SFILES :=$(wildcard $(CORE_PATH)*.S)

CORE_OBJECTS =$(CFILES:.c=.o) $(CPPFILES:.cpp=.o) $(SFILES:.S=.o)

OBJ=$(SRC:.cpp=.o)

#Also find all Library folders
FLIB_DIRS =$(sort $(dir $(wildcard $(FLIB_PATH)*/)))
TLIB_DIRS =$(sort $(dir $(wildcard $(TLIB_PATH)*/)))

#Then add the -iquote prefix (this is for #include "header.h", -I is for <header.h>)
FLIB_LIST =$(foreach dir,$(FLIB_DIRS),-iquote$(dir))
TLIB_LIST =$(foreach dir,$(TLIB_DIRS),-iquote$(dir))

# Combine all necessary flags and optional flags.
# Add target processor to flags.

ALL_CFLAGS =-mmcu=$(MCU) $(FREQ) -I$(CORE_PATH) $(FLIB_LIST) $(TLIB_LIST) $(CFLAGS)
ALL_CPPFLAGS =-mmcu=$(MCU) $(FREQ) -I$(CORE_PATH) $(FLIB_LIST) $(TLIB_LIST) $(CPPFLAGS)
ALL_ASFLAGS =-mmcu=$(MCU) $(FREQ) -I$(CORE_PATH) $(FLIB_LIST) $(TLIB_LIST) -x assembler-with-cpp $(ASFLAGS)
ALL_ELFFLAGS =-mmcu=$(MCU) $(FREQ) $(ELFFLAGS)

# RULES
.PHONY:	new build clean upload build&clean clean_all drop

# Start a new project ('>>' operand with echo just in case this is run on an already created project to avoid overwriting)
new: getcore.py
	@mkdir -p $(CORE); \
	mkdir -p $(TARGET); \
	mkdir -p $(BUILD); \
	mkdir -p $(FLIB); \
	mkdir -p $(TLIB); \
	echo '#include <Arduino.h>\n\n//Libraries go from here--------\n\n//To here-----------------------\n\nvoid setup(void);\nvoid loop(void);\n\n//Prototypes go from here-------\n\n//To here-----------------------\n\nint main(void)\n{\n\tinit();\n\tsetup();\n\tfor(;;)\n\t\tloop();\n}\n\n //"Arduino" Code starts here\n\nvoid setup(void)\n{\n}\nvoid loop(void)\n{\n}\n' >> $(SRC)
	@(python getcore.py $(PIN_VARIANT) $(CORE_PATH) ; echo "\n\nCore download finished\n\n") &

build: $(CORE_PATH)$(ARDUINO_CORE) $(TARGET).elf $(TARGET).hex
#$(TARGET).eep

$(CORE_PATH)$(ARDUINO_CORE): $(CORE_OBJECTS)
	$(ARCC) $(ARFLAGS) $@ $^

%.o : %.c
	$(CC) $(ALL_CFLAGS) $< -o $@

%.o : %.cpp
	$(CPPC) $(ALL_CPPFLAGS) $< -o $@

%.o : %.S
	$(CC) $(ALL_ASFLAGS) $< -o $@

# Link: create ELF output file from object files.
$(TARGET).elf: $(OBJ)
	$(CC) $(ALL_ELFFLAGS) -o $@ $(OBJ) -L$(CORE_PATH) -l$(CORE_NAME) -lm
	$(MV) $@ $(BUILD_PATH)$@

# Create HEX file from ELF file.
$(TARGET).hex: $(BUILD_PATH)$(TARGET).elf
	$(OBJCOPY) $(HEXFLAGS) $< $@
	$(MV) $@ $(BUILD_PATH)$@

# This is needed for eeprom programming at upload only, avrdude recipe not supporting it right now
# $(TARGET).eep: $(BUILD_PATH)$(TARGET).elf
# 	$(OBJCOPY) $(EEPFLAGS) $< $@
# 	$(MV) $@ $(BUILD_PATH)$@

# Target: clean unnecesary files after build.
clean:
	@$(REMOVE) $(CORE_PATH)*.o $(CORE_PATH)*.d $(CORE_PATH)*.a \
	$(MAIN_PATH)*.o $(MAIN_PATH)*.d $(BUILD_PATH)*.elf

# Upload program to the device.  
upload: $(BUILD_PATH)$(TARGET).hex #$(BUILD_PATH)$(TARGET).eep
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FLASH)

build_clean: build clean

clean_all: clean
		@$(REMOVE) $(BUILD_PATH)*.hex #$(BUILD_PATH)*.eep


drop: 
	@read -p "Are you sure? (y/N): " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; \
	then \
	    $(RREMOVE) $(CORE_PATH) $(BUILD_PATH) $(MAIN_PATH) $(FLIB_PATH) $(TLIB_PATH); \
	fi
