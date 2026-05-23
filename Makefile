TARGET ?= top

VERILATOR_ROOT ?= $(shell verilator --getenv VERILATOR_ROOT)
VINC = $(VERILATOR_ROOT)/include

.PHONY: all
all: run

# Compile RTL

obj_dir/V$(TARGET).mk:
	verilator --cc --threads 1 -Irtl rtl/top.sv --top-module $(TARGET) --Mdir obj_dir

obj_dir/V$(TARGET)__ALL.a: obj_dir/V$(TARGET).mk
	make -C obj_dir -j$(nproc) -f V$(TARGET).mk


# Compile TB

SRC = sim/main.cpp sim/generator.cpp sim/field.cpp
OBJ = $(SRC:.cpp=.o)

CXXFLAGS = -I$(VINC) -Isim/include -Iobj_dir -std=c++17

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@


# Link

run: obj_dir/V$(TARGET)__ALL.a $(OBJ)
	$(CXX) $^ $(VINC)/verilated.cpp $(VINC)/verilated_threads.cpp \
	       -lpthread -o $@


.PHONY: clean
clean:
	rm -rf obj_dir $(OBJ) run
