TARGET ?= top
TARGET_PATH = $(shell find -name $(TARGET).sv)

VERILATOR:=verilator
VERILATORFLAGS:=--exe sim/$(TARGET).cpp \
		--trace \
		--report-unoptflat \
		--timing \
		--cc rtl/core/rv32.sv $(TARGET_PATH) \
		--top-module $(TARGET)

.PHONY: all
all: sim

.PHONY: sim
sim: obj
	$(MAKE) -C obj_dir -f V$(TARGET).mk -j$(shell nproc)
	./obj_dir/V$(TARGET)

.PHONY: obj
obj: $(TGT_PATH)
	$(VERILATOR) $(VERILATORFLAGS)
