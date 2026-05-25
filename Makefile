TARGET ?= top

SOURCES := pkg/rv32.sv rtl/$(TARGET).sv

VERILATOR_ROOT ?= $(shell verilator --getenv VERILATOR_ROOT)
VINC = $(VERILATOR_ROOT)/include

.PHONY: all
all: run

# Compile RTL

obj_dir/Vtop.mk:
	verilator --cc -Irtl \
		--top-module $(TARGET) \
		--prefix Vtop \
		--Mdir obj_dir \
		-y rtl/ \
		$(SOURCES)

obj_dir/Vtop__ALL.a: obj_dir/Vtop.mk
	make -C obj_dir -j$(nproc) -f Vtop.mk


# Compile TB

SRC = sim/main.cpp sim/generator.cpp sim/field.cpp sim/device.cpp sim/decoder.cpp
OBJ = $(SRC:.cpp=.o)

CXXFLAGS = -I$(VINC) -Isim/include -Iobj_dir -std=c++17

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@


# Link

run: obj_dir/Vtop__ALL.a $(OBJ)
	$(CXX) $(OBJ) obj_dir/Vtop__ALL.a \
	       	$(VINC)/verilated.cpp \
		$(VINC)/verilated_threads.cpp \
	       -lpthread -o $@


.PHONY: clean
clean:
	rm -rf obj_dir $(OBJ) run
