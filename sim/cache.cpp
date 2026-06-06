#include "cache.hpp"

namespace sim
{
cache::cache(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

cache::~cache()
{}

int cache::req_read(int addr, int &dest)
{
        dut->cpu_addr = addr;
        dut->cpu_valid = 1;
        dut->cpu_we = 0;
        dut->cpu_data_i = 0;

        pulse();

        dut->cpu_valid = 0; // By default we shouldn't be requesting anything.
                            // If this function is called in a tight loop (no
                            // eval()s between calls) this shouldn't matter

        if (dut->cpu_ready) {
                dest = dut->cpu_data_o;
                return 0;
        } else {
                return 1;
        }
}

int cache::req_write(int addr, int data, int op)
{
        dut->cpu_addr = addr;
        dut->cpu_valid = 1;
        dut->cpu_we = 1;
        dut->cpu_data_i = data;
        dut->st_op = op;

        pulse();

        if (dut->cpu_ready)
                return 0;
        else
                return 1;
}

void read_from_mem(std::vector<unsigned long long>& ram, int addr, VlWide<16>& data)
{
        for (int i = 0; i < 16; i++) {
                data.at(i) = ram.at((addr>>3) + i);
        }
}

int cache::run_tests(int cycles) {
        int cpu_data;
        VlWide<16> mem_data;

        for (int i = 0; i < 16; i++) {
                mem_data.at(i) = 0;
        }

        int status = 0;

        reset(5);

        // Read miss test
        dut->mem_ready = 0;

        // tag 0, index 0
        req_read(0x00000000, cpu_data);
        req_read(0x00000000, cpu_data);
        req_read(0x00000000, cpu_data);
        req_read(0x00000000, cpu_data);

        dut->mem_ready = 1;
        mem_data.at(0) = 0x1f;
        mem_data.at(1) = 0x1337;
        dut->mem_data_i = mem_data;

        if (req_read(0x00000000, cpu_data)) {
                std::cout << "1f Read failed" << std::endl;
                status = 1;
        } else if (cpu_data != 0x1f) {
                std::cout << "Got " << std::hex << cpu_data << std::endl;
                status = 1;
        }

        // Read hit test
        if (req_read(0x00000004, cpu_data)) {
                std::cout << "1337 Read failed" << std::endl;
                status = 1;
        } else if (cpu_data != 0x1337) { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
                status = 1;
        }
        
        // Write miss
        dut->mem_ready = 0;
        cpu_data = 0xdeadbeef;
        // tag 0, index 8
        req_write(0x00000100, cpu_data, 2);
        req_write(0x00000100, cpu_data, 2);
        req_write(0x00000100, cpu_data, 2);
        req_write(0x00000100, cpu_data, 2);

        dut->mem_ready = 1;
        mem_data.at(0) = 0;
        mem_data.at(1) = 0;
        dut->mem_data_i = mem_data;

        req_write(0x00000100, cpu_data, 2);

        dut->mem_ready = 0;

        req_write(0x00000100, cpu_data, 2);
        
        // Write hit
        cpu_data = 0xfeed;
        req_write(0x00000108, cpu_data, 2);

        // Eviction test
        // tag 8, index 8

        // Now set associative; no eviction here
       
/*        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);

        dut->mem_ready = 1;
        mem_data = dut->mem_data_o;

        std::cout << "Evicted line: (should end in 0xfeed_00000000_deadbeef)"
                << std::endl;
        for (int i = 15; i >= 0; i--) {
                std::cout << std::hex << "\t[" << i << "] " << mem_data.at(i)
                        << std::endl;
        }

        req_read(0x00001100, cpu_data);

        dut->mem_ready = 0; */

        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);

        dut->mem_ready = 1;
        mem_data.at(0) = 0xcaac;
        mem_data.at(1) = 0xacca;
        dut->mem_data_i = mem_data;

        if (req_read(0x00001100, cpu_data)) {
                std::cout << "caac Read failed" << std::endl;
                status = 1;
        } else if (cpu_data != 0xcaac) { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
                status = 1;
        }

        dut->mem_ready = 0;

        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);

        dut->mem_ready = 1;
        mem_data = dut->mem_data_o;

        std::cout << "Evicted line: (should end in 0xfeed_00000000_deadbeef)"
                << std::endl;
        for (int i = 15; i >= 0; i--) {
                std::cout << std::hex << "\t[" << i << "] " << mem_data.at(i)
                        << std::endl;
        }

        req_read(0x00002100, cpu_data);

        dut->mem_ready = 0;

        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);
        req_read(0x00002100, cpu_data);

        dut->mem_ready = 1;
        mem_data.at(0) = 0xfedd;
        dut->mem_data_i = mem_data;

        if (req_read(0x00002100, cpu_data)) {
                std::cout << "fedd Read failed" << std::endl;
                status = 1;
        } else if (cpu_data != 0xfedd) { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
                status = 1;
        }

        dut->mem_ready = 0;

        pulse();
        pulse();

        return status;
}


} // namespace sim
