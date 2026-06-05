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
                std::cout << "Read failed" << std::endl;
        } else { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
        }

        // Read hit test
        if (req_read(0x00000004, cpu_data)) {
                std::cout << "Read failed" << std::endl;
        } else { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
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
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);

        dut->mem_ready = 1;
        mem_data = dut->mem_data_o;

        std::cout << "Evicted line:" << std::endl;
        for (int i = 15; i >= 0; i--) {
                std::cout << "\t[" << i << "] " << mem_data.at(i) << std::endl;
        }

        req_read(0x00001100, cpu_data);

        dut->mem_ready = 0;

        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);
        req_read(0x00001100, cpu_data);

        dut->mem_ready = 1;
        mem_data.at(0) = 0xcaac;
        mem_data.at(1) = 0xacca;
        dut->mem_data_i = mem_data;

        if (req_read(0x00001100, cpu_data)) {
                std::cout << "Read failed" << std::endl;
        } else { 
                std::cout << "Got " << std::hex << cpu_data << std::endl;
        }

        dut->mem_ready = 0;

        pulse();
        pulse();

        /*int data;
        int addr;
        int rw;
        int st_op;

        int num_tags = 2;

        // Two memory devices; one representing an actual RAM that will interact
        // with the cache, one that will track each access ideally
        std::vector<unsigned long long> ram;

        for (int i = 0; i < (1024/8) * num_tags; i++) {
                ram.push_back(0);
        }


        std::vector<unsigned long long> tracking_ram = ram;

        // Hugely simplified address generator for easy debugging
        sim::generator addr_gen;
        int idx;
        idx = addr_gen.add_field(5, 0, RAND_MASK); // Only allow word-aligned accesses
        addr_gen.fields.at(idx).set_mask(0b111000);

        idx = addr_gen.add_field(9, 6, 0, 3); // Select from only 4 indices

        idx = addr_gen.add_field(31, 10, 0, num_tags - 1);

        reset(5);

        int miss_ctr;
        int miss_ctr_cmp = 10;

        VlWide<16> read_data;
        VlWide<16> write_data;

        for (int i = 0; i < 16; i++) {
                read_data.at(i) = 0;
        }

        dut->mem_ready = 0;
        dut->mem_data_i = read_data;

        unsigned long long tmp;

        std::cout << "Initial:" << std::endl;
        for (int i = 0; i < ram.size(); i++) {
                std::cout << "\t[" << i << "] = 0x"
                        << ram.at(i) << std::endl;
        }

        // Simulate a bunch of writes
        for (int i = 0; i < cycles; i++) {
                addr = addr_gen.generate();

                data = rand();
                st_op = rand() % 3;

                switch (st_op) {
                        case 0:
                                data &= 0xff;
                                break;
                        case 1:
                                data &= 0xffff;
                                break;
                        default:;
                }

                miss_ctr = 0;

                // Hardware execution
                while (req_write(addr, data, st_op)) {
                        if (dut->mem_valid && dut->mem_we) {
                                write_data = dut->mem_data_o;
                                dut->mem_ready = 1;
                        } else if (dut->mem_valid) {
                                if (miss_ctr > miss_ctr_cmp) {
                                        read_from_mem(ram, dut->mem_addr, read_data);
                                        dut->mem_data_i = read_data;
                                        dut->mem_ready = 1;
                                } else {
                                        dut->mem_ready = 0;
                                }
                                miss_ctr++;
                        }
                        pulse();
                }

                // Software model execution
                tmp = tracking_ram.at(addr>>3);

                switch (st_op) {
                        case 0:
                                tmp &= !(0xff);
                                break;
                        case 1: 
                                tmp &= !(0xffff);
                                break;
                        default:
                                tmp &= !(0xffffffff);
                }

                tmp |= data;
                tracking_ram.at(addr>>3) = tmp;
        }

        int rd;

        std::cout << std::hex << "Final:" << std::endl;
        for (int i = 0; i < ram.size(); i++) {
                while (req_read(i << 3, rd)) {
                        if (dut->mem_valid) {
                                read_from_mem(ram, dut->mem_addr, read_data);
                                dut->mem_data_i = read_data;
                                dut->mem_ready = 1;
                        }
                }
                tmp = (unsigned long long)rd << 32;

                while (req_read((i << 3) + 4, rd)) {
                        if (dut->mem_valid) {
                                read_from_mem(ram, dut->mem_addr, read_data);
                                dut->mem_data_i = read_data;
                                dut->mem_ready = 1;
                        }
                }
                tmp |= rd;

                std::cout << "\t[" << i << "] = 0x"
                        << tmp << std::endl;
        } */

        return 0;
}


} // namespace sim
