VERILATOR:=verilator
VERILATORFLAGS:=--exe main.cpp \
		--trace \
		--report-unoptflat \
		--timing \
		--cc rtl/core/rv32.sv

TGT ?= top
TGT_PATH = $(shell find -name $(TGT).sv)

.PHONY: all
all: sim

.PHONY: sim
sim: obj
	$(MAKE) -C obj_dir -f V$(TGT).mk -j$(shell nproc)
	./Vtop

.PHONY: obj
obj: $(TGT_PATH)
	$(VERILATOR) $(VERILATORFLAGS) --cc $(TGT_PATH) --top-module $(TGT)
