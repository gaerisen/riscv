TARGET ?= top

RTL_SRC := pkg/rv32.sv pkg/mem_ifc.sv rtl/$(TARGET).sv

VERILATOR_ROOT ?= $(shell verilator --getenv VERILATOR_ROOT)
VINC = $(VERILATOR_ROOT)/include
VLTSTDINC = $(VERILATOR_ROOT)/include/vltstd

.PHONY: all
all: main

# Compile RTL

obj_dir/Vtop.mk: $(RTL_SRC)
	verilator --cc -Irtl \
		--top-module $(TARGET) \
		--prefix Vtop \
		--Mdir obj_dir \
		-y rtl/ \
		--trace \
		--report-unoptflat \
		--coverage \
		$(RTL_SRC)

obj_dir/Vtop__ALL.a: obj_dir/Vtop.mk
	make -C obj_dir -j$(shell nproc) -f Vtop.mk


# Compile TB

TB_SRC = sim/main.cpp \
	 sim/field.cpp \
	 sim/generator.cpp \
	 sim/device.cpp \
	 sim/$(TARGET).cpp

TB_OBJ = $(TB_SRC:.cpp=.o)

CXXFLAGS = -I$(VINC) -I$(VLTSTDINC) -Isim/include -Iobj_dir -std=c++17

$(TB_OBJ): $(TB_SRC) obj_dir/Vtop.mk

# Link

main: obj_dir/Vtop__ALL.a $(TB_OBJ)
	$(CXX) $(TB_OBJ) obj_dir/Vtop__ALL.a \
	       	$(VINC)/verilated.cpp \
		$(VINC)/verilated_threads.cpp \
		$(VINC)/verilated_vcd_c.cpp \
		$(VINC)/verilated_cov.cpp \
	       -lpthread -o $@


.PHONY: clean cleaner
clean:
	rm -rf sim/*.o
cleaner:
	rm -rf obj_dir sim/*.o main *.vcd
